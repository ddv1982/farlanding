class_name SelectionController
extends Node
## Player selection and order input.
##
## Left click selects (Shift toggles), left drag box-selects (Shift adds), double-click
## selects every visible unit of that type. Ctrl+1..9 stores a control group, 1..9
## recalls it, a quick second press centres the camera on it. Right click moves (Shift
## queues a waypoint), S stops, A then left click attack-moves. Every order goes
## through the mission's CommandQueue.

const DRAG_THRESHOLD_PX: float = 6.0
const DOUBLE_TAP_SECONDS: float = 0.35
const MOVE_MARKER_COLOR: Color = Color(0.45, 1.0, 0.55)
const ATTACK_MARKER_COLOR: Color = Color(1.0, 0.4, 0.3)
## Point above a unit's origin used for screen-space picking, in metres.
const PICK_HEIGHT: float = 1.0

@export var camera: RtsCamera
@export var world: SimWorld
@export var player_faction: int = 0

var selection: Array[Unit] = []

var _groups: ControlGroups = ControlGroups.new()
var _box: SelectionBox
var _press_position: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _box_dragging: bool = false
var _attack_move_armed: bool = false
var _last_group_key: int = 0
var _last_group_time: float = -10.0


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = &"SelectionOverlay"
	add_child(layer)
	_box = SelectionBox.new()
	layer.add_child(_box)
	Events.entity_spawned.connect(_on_entity_spawned)
	Events.entity_died.connect(_on_entity_died)


func _process(_delta: float) -> void:
	if camera != null:
		camera.wasd_enabled = selection.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
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


## Replaces the selection, updates rings and announces the change.
func set_selection(units: Array[Unit]) -> void:
	var next: Array[Unit] = SelectionRules.selectable(units, player_faction)
	for unit: Variant in selection:
		if is_instance_valid(unit):
			var old: Unit = unit
			if not next.has(old):
				_set_ring(old, false)
	for unit: Unit in next:
		_set_ring(unit, true)
	selection = next
	if selection.is_empty():
		_disarm()
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
				if _attack_move_armed:
					_issue_move(MoveCommand.KIND_ATTACK_MOVE, button.position, button.shift_pressed)
					_disarm()
					return
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
					set_selection(
						SelectionRules.click(
							selection,
							unit_at(button.position),
							button.shift_pressed,
							player_faction
						)
					)
		MOUSE_BUTTON_RIGHT:
			if not button.pressed:
				return
			if _attack_move_armed:
				_disarm()
				return
			_issue_move(MoveCommand.KIND_MOVE, button.position, button.shift_pressed)


func _handle_key(key: InputEventKey) -> void:
	var group: int = _group_index(key)
	if group > 0:
		if key.ctrl_pressed or key.meta_pressed:
			_groups.assign(group, selection)
			Events.ui_feedback.emit(&"group_assign")
		else:
			_recall_group(group)
		get_viewport().set_input_as_handled()
		return
	if key.is_action_pressed(&"ui_cancel"):
		_disarm()
		return
	if selection.is_empty():
		return
	if key.is_action_pressed(&"order_stop"):
		_push(StopCommand.new(player_faction, _selected_entities()))
		get_viewport().set_input_as_handled()
	elif key.is_action_pressed(&"order_attack_move"):
		_attack_move_armed = true
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
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


func _issue_move(kind: StringName, screen_position: Vector2, queued: bool) -> void:
	if selection.is_empty():
		return
	var target: Vector3 = camera.ground_point(screen_position)
	if target == Vector3.INF:
		Events.ui_feedback.emit(&"invalid_target")
		return
	_push(MoveCommand.new(kind, player_faction, _selected_entities(), target, queued))
	var color: Color = (
		ATTACK_MARKER_COLOR if kind == MoveCommand.KIND_ATTACK_MOVE else MOVE_MARKER_COLOR
	)
	OrderMarker.spawn(world, target, color)


func _push(command: Command) -> void:
	world.context.command_queue.push(command)


func _selected_entities() -> Array[Node3D]:
	var entities: Array[Node3D] = []
	entities.assign(selection)
	return entities


func _disarm() -> void:
	if _attack_move_armed:
		_attack_move_armed = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _set_ring(unit: Unit, selected: bool) -> void:
	var visual: UnitVisual = _visual_of(unit)
	if visual != null:
		visual.set_selected(selected)


func _on_entity_spawned(entity: Node3D) -> void:
	var unit: Unit = entity as Unit
	if unit == null:
		return
	var visual: UnitVisual = _visual_of(unit)
	if visual != null:
		visual.set_team_color(TeamColors.for_faction(unit.faction))


func _on_entity_died(entity: Node3D) -> void:
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
