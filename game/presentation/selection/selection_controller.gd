class_name SelectionController
extends Node
## Player selection and order input.
##
## Left click selects (Shift toggles), left drag box-selects units (Shift adds),
## double-click selects every visible unit of that type. Left click on an own building
## selects it alone. With units selected, left or right click on an enemy (unit or
## building) attacks it, right click on a deposit sends Haulers to harvest it, right
## click on an own construction site sends Fabricators to help, and right click on the
## ground moves there (Shift queues). With a producer building selected, right click
## on the ground sets its rally point. While placing a building (BuildPlacement), left
## click places it and right click or Esc cancels. X stops. Ctrl+1..9 stores a control
## group, 1..9 recalls it, a quick second press centres the camera on it. The cursor
## turns into a red reticle over an enemy while units are selected. Every order goes
## through the mission's CommandQueue.

const DRAG_THRESHOLD_PX: float = 6.0
const DOUBLE_TAP_SECONDS: float = 0.35
const MOVE_MARKER_COLOR: Color = Color(0.45, 1.0, 0.55)
const ATTACK_MARKER_COLOR: Color = Color(1.0, 0.4, 0.3)
## Point above a unit's origin used for screen-space picking, in metres.
const PICK_HEIGHT: float = 1.0
## Attack cursor: size and hotspot (its centre) in pixels.
const ATTACK_CURSOR_SIZE: int = 32

@export var camera: RtsCamera
@export var world: SimWorld
@export var player_faction: int = 0

var selection: Array[Unit] = []
## The selected building (selected alone, never together with units), or null.
var selected_building: Building = null
var placement: BuildPlacement = null

var _groups: ControlGroups = ControlGroups.new()
var _box: SelectionBox
var _press_position: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _box_dragging: bool = false
var _attack_cursor: Texture2D = null
var _attack_cursor_shown: bool = false
var _last_group_key: int = 0
var _last_group_time: float = -10.0
var _rally_marker: RallyMarker = null
## Last pointer position seen in any mouse event (also over the HUD).
var _pointer: Vector2 = Vector2.ZERO


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = &"SelectionOverlay"
	add_child(layer)
	_box = SelectionBox.new()
	layer.add_child(_box)
	placement = BuildPlacement.new()
	placement.name = &"BuildPlacement"
	add_child(placement)
	Events.entity_spawned.connect(_on_entity_spawned)
	Events.entity_died.connect(_on_entity_died)


func _process(_delta: float) -> void:
	if camera == null or world == null:
		return
	var mouse: Vector2 = _pointer
	if placement.is_active():
		placement.update(camera.ground_point(mouse))
	var hovering_enemy: bool = false
	if not selection.is_empty() and not placement.is_active():
		var hovered: Unit = unit_at(mouse)
		hovering_enemy = (
			SelectionRules.right_click(selection, hovered, player_faction)
			== SelectionRules.CLICK_ATTACK
		)
		if hovered == null:
			hovering_enemy = (
				SelectionRules.right_click_target(selection, building_at(mouse), player_faction)
				== SelectionRules.CLICK_ATTACK
			)
	_show_attack_cursor(hovering_enemy)
	_update_rally_marker()


func _exit_tree() -> void:
	_show_attack_cursor(false)


func _input(event: InputEvent) -> void:
	var mouse_event: InputEventMouse = event as InputEventMouse
	if mouse_event != null:
		_pointer = mouse_event.position


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if placement.is_active():
			_handle_placement_button(button)
			return
		_handle_mouse_button(button)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _pressing and motion.position.distance_to(_press_position) > DRAG_THRESHOLD_PX:
			_box_dragging = true
		if _box_dragging:
			_box.show_rect(Rect2(_press_position, motion.position - _press_position))
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_handle_key(key)


## Starts placing `def` with the selected units that can build it.
func begin_placement(def: BuildingDef) -> void:
	var builders: Array[Unit] = SelectionRules.able(selection, Builder.KIND)
	if builders.is_empty() or world == null:
		return
	Events.ui_feedback.emit(&"build_button")
	placement.begin(def, builders, world)


## Selects one own building alone (null clears it), dropping any unit selection.
func select_building(building: Building) -> void:
	if building != null and (not is_instance_valid(building) or building.faction != player_faction):
		building = null
	if building == selected_building and selection.is_empty():
		return
	_set_building_ring(selected_building, false)
	for unit: Unit in selection:
		if is_instance_valid(unit):
			_set_ring(unit, false)
	selection = []
	selected_building = building
	_set_building_ring(building, true)
	var entities: Array[Node3D] = []
	if building != null:
		entities.append(building)
	Events.selection_changed.emit(entities)


## Own building under a screen position, or any faction's: the nearest hit, or null.
func building_at(screen_position: Vector2) -> Building:
	var origin: Vector3 = camera.camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.camera.project_ray_normal(screen_position)
	var best: Building = null
	var best_distance: float = INF
	for building: Building in world.buildings:
		var area: Rect2 = building.footprint()
		var box: AABB = AABB(
			Vector3(area.position.x, building.position.y - 0.5, area.position.y),
			Vector3(area.size.x, building.def.height + 0.5, area.size.y)
		)
		var hit: Variant = box.intersects_ray(origin, direction)
		if hit == null:
			continue
		var point: Vector3 = hit
		var distance: float = origin.distance_to(point)
		if distance < best_distance:
			best = building
			best_distance = distance
	return best


## Resource node under a screen position, or null.
func resource_node_at(screen_position: Vector2) -> ResourceNode:
	var origin: Vector3 = camera.camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.camera.project_ray_normal(screen_position)
	for node: ResourceNode in world.resource_nodes:
		var radius: float = node.def.radius
		var box: AABB = AABB(
			node.position - Vector3(radius, 0.5, radius),
			Vector3(radius * 2.0, node.def.height + 1.0, radius * 2.0)
		)
		if box.intersects_ray(origin, direction) != null:
			return node
	return null


## Replaces the selection, updates rings and announces the change.
func set_selection(units: Array[Unit]) -> void:
	if selected_building != null:
		_set_building_ring(selected_building, false)
		selected_building = null
	var next: Array[Unit] = SelectionRules.selectable(units, player_faction)
	for unit: Variant in selection:
		if is_instance_valid(unit):
			var old: Unit = unit
			if not next.has(old):
				_set_ring(old, false)
	for unit: Unit in next:
		_set_ring(unit, true)
	selection = next
	var entities: Array[Node3D] = []
	entities.assign(selection)
	Events.selection_changed.emit(entities)


## Unit under a screen position (player's or not), or null.
func unit_at(screen_position: Vector2) -> Unit:
	var origin: Vector3 = camera.camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.camera.project_ray_normal(screen_position)
	var best: Unit = null
	var best_distance: float = INF
	for unit: Unit in world.units:
		var centre: Vector3 = unit.global_position + Vector3.UP * PICK_HEIGHT
		var along: float = (centre - origin).dot(direction)
		if along <= 0.0:
			continue
		var miss: float = (origin + direction * along).distance_to(centre)
		var reach: float = (unit.def.radius if unit.def != null else 0.5) + 0.5
		if miss <= reach and along < best_distance:
			best = unit
			best_distance = along
	return best


## Player units whose pick point is inside `rect` (screen space).
func units_in_rect(rect: Rect2) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in world.units_of(player_faction):
		var point: Vector3 = unit.global_position + Vector3.UP * PICK_HEIGHT
		if camera.camera.is_position_behind(point):
			continue
		if rect.has_point(camera.camera.unproject_position(point)):
			result.append(unit)
	return result


func _handle_mouse_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			if button.pressed:
				if button.double_click:
					_select_same_type(button.position)
					_pressing = false
					return
				_pressing = true
				_box_dragging = false
				_press_position = button.position
			elif _pressing:
				_pressing = false
				if _box_dragging:
					_box_dragging = false
					_box.hide_rect()
					var rect: Rect2 = Rect2(_press_position, button.position - _press_position)
					set_selection(
						SelectionRules.box(
							selection,
							units_in_rect(rect.abs()),
							button.shift_pressed,
							player_faction
						)
					)
				else:
					_left_click(button.position, button.shift_pressed)
		MOUSE_BUTTON_RIGHT:
			if not button.pressed:
				return
			if selected_building != null:
				_issue_rally(button.position)
				return
			var clicked: Unit = unit_at(button.position)
			if clicked != null:
				match SelectionRules.right_click(selection, clicked, player_faction):
					SelectionRules.CLICK_ATTACK:
						_issue_attack(clicked, button.shift_pressed)
					SelectionRules.CLICK_MOVE:
						_issue_move(button.position, button.shift_pressed)
				return
			_right_click_world(button.position, button.shift_pressed)


func _right_click_world(screen_position: Vector2, queued: bool) -> void:
	# Buildings first: a Flux Tap stands on its vent, and the click means the Tap.
	var target: Node3D = building_at(screen_position)
	if target == null:
		target = resource_node_at(screen_position)
	match SelectionRules.right_click_target(selection, target, player_faction):
		SelectionRules.CLICK_ATTACK:
			_issue_attack(target, queued)
		SelectionRules.CLICK_HARVEST:
			_issue_on_target(HarvestCommand.new(player_faction, [], target, queued), target, queued)
		SelectionRules.CLICK_ASSIST:
			_issue_on_target(BuildCommand.new(player_faction, [], target, queued), target, queued)
		SelectionRules.CLICK_MOVE:
			_issue_move(screen_position, queued)


## Gives `command` (harvest, build) to the units able to do it; the rest move next to
## the target.
func _issue_on_target(command: Command, target: Node3D, queued: bool) -> void:
	var able: Array[Unit] = SelectionRules.able(selection, command.kind)
	var others: Array[Node3D] = []
	for unit: Unit in selection:
		if not able.has(unit):
			others.append(unit)
	command.entities.assign(able)
	_push(command)
	if not others.is_empty():
		_push(
			MoveCommand.new(MoveCommand.KIND_MOVE, player_faction, others, target.position, queued)
		)
	OrderMarker.spawn(world, target.position, MOVE_MARKER_COLOR)


func _issue_rally(screen_position: Vector2) -> void:
	if selected_building.producer == null:
		return
	var target: Vector3 = camera.ground_point(screen_position)
	if target == Vector3.INF:
		Events.ui_feedback.emit(&"invalid_target")
		return
	_push(RallyCommand.new(player_faction, [selected_building] as Array[Node3D], target))


func _handle_placement_button(button: InputEventMouseButton) -> void:
	if not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			var command: PlaceBuildingCommand = placement.confirm(
				player_faction, button.shift_pressed
			)
			if command != null:
				_push(command)
				OrderMarker.spawn(world, command.target_position, MOVE_MARKER_COLOR)
		MOUSE_BUTTON_RIGHT:
			placement.cancel()


func _left_click(screen_position: Vector2, shift: bool) -> void:
	var clicked: Unit = unit_at(screen_position)
	if clicked == null:
		var building: Building = building_at(screen_position)
		if building != null:
			if building.faction == player_faction:
				select_building(building)
			elif not selection.is_empty():
				_issue_attack(building, shift)
			return
	match SelectionRules.left_click(selection, clicked, player_faction):
		SelectionRules.CLICK_ATTACK:
			_issue_attack(clicked, shift)
		SelectionRules.CLICK_SELECT:
			set_selection(SelectionRules.click(selection, clicked, shift, player_faction))


func _handle_key(key: InputEventKey) -> void:
	if placement.is_active() and key.keycode == KEY_ESCAPE:
		placement.cancel()
		get_viewport().set_input_as_handled()
		return
	var group: int = _group_index(key)
	if group > 0:
		if key.ctrl_pressed or key.meta_pressed:
			_groups.assign(group, selection)
			Events.ui_feedback.emit(&"group_assign")
		else:
			_recall_group(group)
		get_viewport().set_input_as_handled()
		return
	if selection.is_empty():
		return
	if key.is_action_pressed(&"order_stop"):
		_push(StopCommand.new(player_faction, _selected_entities()))
		get_viewport().set_input_as_handled()


func _recall_group(group: int) -> void:
	var units: Array[Unit] = _groups.recall(group)
	var now: float = Time.get_ticks_msec() / 1000.0
	var double_tap: bool = group == _last_group_key and now - _last_group_time < DOUBLE_TAP_SECONDS
	_last_group_key = group
	_last_group_time = now
	if units.is_empty():
		return
	Events.ui_feedback.emit(&"group_recall")
	set_selection(units)
	if double_tap:
		var centre: Vector3 = Vector3.ZERO
		for unit: Unit in units:
			centre += unit.global_position
		camera.center_on(centre / float(units.size()))


func _select_same_type(screen_position: Vector2) -> void:
	var clicked: Unit = unit_at(screen_position)
	if clicked == null:
		return
	var visible_units: Array[Unit] = units_in_rect(get_viewport().get_visible_rect())
	var same: Array[Unit] = SelectionRules.same_type(visible_units, clicked, player_faction)
	if same.is_empty():
		return
	set_selection(same)


func _issue_move(screen_position: Vector2, queued: bool) -> void:
	if selection.is_empty():
		return
	var target: Vector3 = camera.ground_point(screen_position)
	if target == Vector3.INF:
		Events.ui_feedback.emit(&"invalid_target")
		return
	_push(
		MoveCommand.new(MoveCommand.KIND_MOVE, player_faction, _selected_entities(), target, queued)
	)
	OrderMarker.spawn(world, target, MOVE_MARKER_COLOR)


func _issue_attack(target: Node3D, queued: bool) -> void:
	if selection.is_empty():
		return
	_push(AttackCommand.new(player_faction, _selected_entities(), target, queued))
	OrderMarker.spawn(world, target.global_position, ATTACK_MARKER_COLOR)


func _push(command: Command) -> void:
	world.context.command_queue.push(command)


func _selected_entities() -> Array[Node3D]:
	var entities: Array[Node3D] = []
	entities.assign(selection)
	return entities


func _show_attack_cursor(show: bool) -> void:
	if show == _attack_cursor_shown:
		return
	_attack_cursor_shown = show
	if not show:
		Input.set_custom_mouse_cursor(null)
		return
	if _attack_cursor == null:
		_attack_cursor = _build_attack_cursor()
	var centre: float = ATTACK_CURSOR_SIZE * 0.5
	Input.set_custom_mouse_cursor(_attack_cursor, Input.CURSOR_ARROW, Vector2(centre, centre))


## A red reticle: a ring with four ticks pointing in and a centre dot, outlined dark.
static func _build_attack_cursor() -> Texture2D:
	var size: int = ATTACK_CURSOR_SIZE
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var red: Color = Color(1.0, 0.22, 0.15)
	var dark: Color = Color(0.08, 0.02, 0.02, 0.9)
	var centre: Vector2 = Vector2(size, size) * 0.5 - Vector2(0.5, 0.5)
	for pass_index: int in 2:
		var color: Color = dark if pass_index == 0 else red
		var grow: float = 1.0 if pass_index == 0 else 0.0
		for y: int in size:
			for x: int in size:
				var offset: Vector2 = Vector2(x, y) - centre
				var r: float = offset.length()
				var ring: bool = absf(r - 10.0) <= 1.0 + grow
				var on_axis: bool = absf(offset.x) <= 0.5 + grow or absf(offset.y) <= 0.5 + grow
				var tick: bool = on_axis and r >= 5.0 - grow and r <= 15.0 + grow
				var dot: bool = r <= 1.5 + grow
				if ring or tick or dot:
					image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _update_rally_marker() -> void:
	var producer: Producer = null
	if selected_building != null and is_instance_valid(selected_building):
		producer = selected_building.producer
	var show: bool = producer != null and producer.has_rally_point
	if not show:
		if _rally_marker != null:
			_rally_marker.visible = false
		return
	if _rally_marker == null:
		_rally_marker = RallyMarker.create(TeamColors.for_faction(player_faction))
		world.add_child(_rally_marker)
	_rally_marker.visible = true
	_rally_marker.position = producer.rally_point


func _set_building_ring(building: Building, selected: bool) -> void:
	if building == null or not is_instance_valid(building):
		return
	for child: Node in building.get_children():
		if child is BuildingVisual:
			var visual: BuildingVisual = child
			visual.set_selected(selected)


func _set_ring(unit: Unit, selected: bool) -> void:
	var visual: UnitVisual = _visual_of(unit)
	if visual != null:
		visual.set_selected(selected)


func _on_entity_spawned(entity: Node3D) -> void:
	var building: Building = entity as Building
	if building != null:
		for child: Node in building.get_children():
			if child is BuildingVisual:
				var building_visual: BuildingVisual = child
				building_visual.set_team_color(TeamColors.for_faction(building.faction))
		return
	var unit: Unit = entity as Unit
	if unit == null:
		return
	var visual: UnitVisual = _visual_of(unit)
	if visual != null:
		visual.set_team_color(TeamColors.for_faction(unit.faction))


func _on_entity_died(entity: Node3D) -> void:
	if entity == selected_building:
		select_building(null)
		return
	var unit: Unit = entity as Unit
	if unit != null and selection.has(unit):
		var remaining: Array[Unit] = selection.duplicate()
		remaining.erase(unit)
		set_selection(remaining)


static func _visual_of(unit: Unit) -> UnitVisual:
	for child: Node in unit.get_children():
		if child is UnitVisual:
			return child
	return null


static func _group_index(key: InputEventKey) -> int:
	var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_1 + 1
	return 0
