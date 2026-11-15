extends GutTest
## The control groups bar on a real landing at 1152x648, at 100 % and 130 % interface
## size: with all nine groups shown it stays on screen and clear of the command
## panel, the selection panel, the objectives, the resource bar, the minimap corner
## and the subtitle band, with units selected and with nothing selected.

const VIEW: Vector2i = Vector2i(1152, 648)
const CATALOG: String = "res://data/missions/catalog.tres"

var _saved_size: Vector2i
var _saved_scale: float = 1.0


func before_each() -> void:
	_saved_size = get_tree().root.size
	_saved_scale = get_tree().root.content_scale_factor


func after_each() -> void:
	get_tree().root.size = _saved_size
	get_tree().root.content_scale_factor = _saved_scale


func test_the_bar_keeps_clear_at_both_interface_sizes() -> void:
	var catalog: MissionCatalog = load(CATALOG)
	var mission: MissionDef = catalog.missions[0]
	get_tree().root.size = VIEW
	for scale: float in [1.0, 1.3]:
		get_tree().root.content_scale_factor = scale
		var map: LandingMap = mission.map_scene.instantiate() as LandingMap
		map.mission = mission
		add_child(map)
		await wait_physics_frames(30)
		var controller: SelectionController = map.selection_controller
		var units: Array[Unit] = map.world.units_of(map.world.player_faction)
		assert_gt(units.size(), 0, "the landing has player units")
		controller.set_selection(units)
		for group: int in range(1, ControlGroups.COUNT + 1):
			controller.store_group(group)
		await wait_process_frames(4)
		_assert_clear(map.hud, "%d %% selected" % roundi(scale * 100.0))
		controller.set_selection([])
		await wait_process_frames(4)
		_assert_clear(map.hud, "%d %% nothing selected" % roundi(scale * 100.0))
		var builder: Unit = null
		for unit: Unit in units:
			if not unit.def.builds.is_empty():
				builder = unit
				break
		assert_not_null(builder)
		controller.set_selection([builder] as Array[Unit])
		await wait_process_frames(4)
		_assert_clear(map.hud, "%d %% builder selected" % roundi(scale * 100.0))
		var commands: Control = map.hud.get("_command_panel")
		var corner: Control = map.hud.get("_corner")
		assert_false(
			commands.get_global_rect().intersects(corner.get_global_rect()),
			"the full build menu stays clear of the minimap"
		)
		remove_child(map)
		map.free()
		await wait_process_frames(2)


func _assert_clear(hud: Hud, label: String) -> void:
	var bar: GroupBar = hud.group_bar()
	assert_true(bar.visible, label + ": the bar shows")
	var rect: Rect2 = bar.get_global_rect()
	var view: Rect2 = hud.get_viewport().get_visible_rect()
	assert_true(view.encloses(rect), "%s: on screen %s in %s" % [label, rect, view])
	var subtitle_bottom: float = view.size.y - SubtitleLine.BOTTOM_GAP
	assert_gt(rect.position.y, subtitle_bottom, label + ": under the subtitle band")
	for field: String in ["_command_panel", "_selection_panel", "_objectives", "_corner"]:
		var value: Variant = hud.get(field)
		if not value is Control:
			continue
		var other: Control = value
		if not other.is_visible_in_tree():
			continue
		var other_rect: Rect2 = other.get_global_rect()
		assert_false(
			rect.intersects(other_rect), "%s: clear of %s %s %s" % [label, field, rect, other_rect]
		)
	for child: Node in hud.get_children():
		var resources: ResourceBar = child as ResourceBar
		if resources != null:
			assert_false(rect.intersects(resources.get_global_rect()), label + ": resource bar")
