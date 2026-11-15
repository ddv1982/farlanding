extends Node

var _elapsed: float = 0.0
var _frames: Array[float] = []
var _main: Main
var _score: MusicScore = preload("res://data/sounds/music/kessel_reach.tres")


func _ready() -> void:
	_main = get_parent() as Main
	seed(1729)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--web-mission="):
			var mission: MissionDef = load("res://data/missions/" + arg.get_slice("=", 1) + ".tres")
			_main.start_mission(mission, Main.single_modifiers(Difficulty.NORMAL))

	if OS.get_cmdline_user_args().has("--web-encounter"):
		var map: LandingMap = _main.map as LandingMap
		if map != null:
			map.world.spawn_unit(
				load("res://data/units/concord_ranger.tres") as UnitDef, 0, Vector3(-73, 0, 100)
			)
			map.world.spawn_unit(
				load("res://data/units/combine_skitter.tres") as UnitDef, 1, Vector3(-63, 0, 100)
			)


func _process(delta: float) -> void:
	_frames.append(delta * 1000.0)
	if _frames.size() > 1200:
		_frames.pop_front()
	_elapsed += delta
	if _elapsed < 0.2:
		return
	_elapsed = 0.0
	var playback_type: int = ProjectSettings.get_setting_with_override(
		"audio/general/default_playback_type"
	)
	var data: Dictionary = {
		"quality": Settings.quality,
		"render_scale": Settings.render_scale,
		"msaa": Settings.msaa_3d,
		"graphics_upgrade_available": Settings.graphics_upgrade_available,
		"graphics_defaults_version": Settings.graphics_defaults_version,
		"viewport_size":
		[get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"scheme": Settings.control_scheme,
		"music_volume": Settings.music_volume,
		"ui_scale": Settings.ui_scale,
		"display_scale": get_tree().root.content_scale_factor,
		"fullscreen": Settings.fullscreen,
		"audio_playback": "stream" if playback_type == 0 else "sample",
		"music_source_layers": _score.clips[0].layers.size(),
		"music_layers": _score.clips[0].layer_names.size(),
		"music_volumes": _score.states[0].layer_volumes_db.size(),
		"campaign_active": _main.campaign != null,
		"screen": _main.screen,
		"notice": _main.get("_message"),
		"paused": _main.paused,
		"mission": _main.current.id if _main.current != null else &"",
		"buttons": [],
		"popups": [],
		"units": [],
		"buildings": [],
		"deposits": [],
		"selected": [],
		"quicksave":
		(
			FileAccess.get_file_as_string(SaveSlots.path_of(SaveSlots.QUICKSAVE)).sha256_text()
			if SaveSlots.exists(SaveSlots.QUICKSAVE)
			else ""
		),
		"frame_p95_ms": _p95(),
	}
	var buttons: Array = data["buttons"]
	var popups: Array = data["popups"]
	_buttons(_main, buttons, popups)
	var units: Array = data["units"]
	var buildings: Array = data["buildings"]
	var deposits: Array = data["deposits"]
	var selected: Array = data["selected"]
	var map: LandingMap = _main.map as LandingMap
	if map != null:
		var camera: Camera3D = map.camera.camera
		var commands: CommandPanel = map.hud.get("_command_panel")
		var scroller: ScrollContainer = commands.get("_scroll")
		var scroll_bar: HScrollBar = scroller.get_h_scroll_bar()
		var scroll_rect: Rect2 = scroll_bar.get_global_rect()
		data["command_scroll"] = {
			"rect":
			[
				scroll_rect.position.x * _css_scale(),
				scroll_rect.position.y * _css_scale(),
				scroll_rect.size.x * _css_scale(),
				scroll_rect.size.y * _css_scale()
			],
			"value": scroll_bar.value,
			"maximum": scroll_bar.max_value,
			"page": scroll_bar.page,
		}
		data["placing"] = map.selection_controller.placement.is_active()
		data["placement_reason"] = map.selection_controller.placement.reason
		data["tick"] = map.context.sim_clock.get_tick()
		data["stockpile"] = map.world.economy.stockpile(map.world.player_faction).to_dict()
		for unit: Unit in map.world.units:
			var item: Dictionary = _entity(unit, camera)
			item["kind"] = unit.def.id
			item["faction"] = unit.faction
			item["health"] = unit.health.current
			units.append(item)
		for building: Building in map.world.buildings:
			var item: Dictionary = _entity(building, camera)
			item["kind"] = building.def.id
			item["faction"] = building.faction
			item["constructing"] = building.is_under_construction
			buildings.append(item)
		for deposit: ResourceNode in map.world.resource_nodes:
			var item: Dictionary = _entity(deposit, camera)
			item["remaining"] = deposit.remaining
			deposits.append(item)
		for unit: Unit in map.selection_controller.selection:
			selected.append(unit.entity_id)
		var ground: Array = []
		data["ground"] = ground
		for offset: Vector3 in [Vector3(12, 0, 0), Vector3(0, 0, -12), Vector3(15, 0, -15)]:
			var point: Vector3 = map.camera.get_focus() + offset
			point.y = map.heights.sample(point.x, point.z)
			var pixel: Vector2 = camera.unproject_position(point) * _css_scale()
			ground.append([pixel.x, pixel.y])
	JavaScriptBridge.eval("window.farlanding.diagnostics = " + JSON.stringify(data))


func _entity(entity: Node3D, camera: Camera3D) -> Dictionary:
	var point: Vector3 = entity.global_position
	var pixel: Vector2 = camera.unproject_position(point + Vector3.UP) * _css_scale()
	return {
		"id": entity.get("entity_id"),
		"position": [point.x, point.y, point.z],
		"pixel": [pixel.x, pixel.y],
	}


func _buttons(node: Node, result: Array, popups: Array) -> void:
	if node is Button:
		var button: Button = node as Button
		if button.is_visible_in_tree() and not button.disabled:
			var rect: Rect2 = button.get_global_rect()
			var point: Vector2 = rect.get_center() * _css_scale()
			result.append({"name": button.name, "text": button.text, "pixel": [point.x, point.y]})
	if node is PopupMenu:
		var popup: PopupMenu = node as PopupMenu
		if popup.visible:
			var items: Array[String] = []
			for index: int in popup.item_count:
				items.append(popup.get_item_text(index))
			(
				popups
				. append(
					{
						"items": items,
						"position":
						[popup.position.x * _css_scale(), popup.position.y * _css_scale()],
						"size": [popup.size.x * _css_scale(), popup.size.y * _css_scale()],
					}
				)
			)
	for child: Node in node.get_children(true):
		_buttons(child, result, popups)


func _css_scale() -> float:
	return get_tree().root.content_scale_factor / DisplayServer.screen_get_scale()


func _p95() -> float:
	var sorted: Array[float] = _frames.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)]
