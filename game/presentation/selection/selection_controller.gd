class_name SelectionController
extends Node
## Player selection and order input, in one of two mouse schemes
## (`Settings.control_scheme`; the rules live in SelectionRules.resolve()):
##
## - classic (default, Command & Conquer style): left click does everything by
##   context. On an own unit or building it selects; with units selected it moves,
##   attacks an enemy in sight, harvests a deposit (Haulers), scans a site
##   (Surveyors), sabotages an enemy building (Wisps) or helps build an own site
##   (Fabricators); with a producer building
##   selected it sets the rally point. Right click deselects.
## - modern: left click selects (and attacks an enemy in sight), right click
##   commands with the same context rules.
##
## In both: left drag box-selects units (Shift adds), Shift+click toggles a unit,
## double-click selects every visible unit of that type, Shift queues orders. While
## placing a building (BuildPlacement) or aiming a field option, left click confirms
## and right click or Esc cancels. X stops. Ctrl+1..9 stores a control group, 1..9
## recalls it, a quick second press centres the camera on it. The cursor shows what
## a command click would do (CursorIcons). Enemies out of sight cannot be clicked:
## hidden ones are not there for the mouse, remembered buildings count as ground.
## Every order goes through the mission's CommandQueue.

const DRAG_THRESHOLD_PX: float = 6.0
const DOUBLE_TAP_SECONDS: float = 0.35
const MOVE_MARKER_COLOR: Color = Color(0.45, 1.0, 0.55)
const ATTACK_MARKER_COLOR: Color = Color(1.0, 0.4, 0.3)
## Point above a unit's origin used for screen-space picking, in metres.
const PICK_HEIGHT: float = 1.0
## Cursor shown for each click action (SelectionRules.CLICK_*).
const CURSOR_FOR_ACTION: Dictionary[StringName, StringName] = {
	SelectionRules.CLICK_ATTACK: CursorIcons.ATTACK,
	SelectionRules.CLICK_MOVE: CursorIcons.MOVE,
	SelectionRules.CLICK_SCAN: CursorIcons.SCAN,
	SelectionRules.CLICK_HARVEST: CursorIcons.HARVEST,
	SelectionRules.CLICK_ASSIST: CursorIcons.ASSIST,
	SelectionRules.CLICK_RALLY: CursorIcons.RALLY,
	SelectionRules.CLICK_SABOTAGE: CursorIcons.SABOTAGE,
	SelectionRules.CLICK_CARRY: CursorIcons.ASSIST,
}

@export var camera: RtsCamera
@export var world: SimWorld
@export var player_faction: int = 0

var selection: Array[Unit] = []
## The selected building (selected alone, never together with units), or null.
var selected_building: Building = null
var placement: BuildPlacement = null
## The field option being aimed, and the lab that will use it (null when not aiming).
var targeting_option: FieldOptionDef = null
var targeting_lab: Building = null

var _groups: ControlGroups = ControlGroups.new()
var _box: SelectionBox
var _press_position: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _box_dragging: bool = false
var _cursor_shown: StringName = &""
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
	_show_cursor(_hover_cursor(mouse))
	_update_rally_marker()


func _exit_tree() -> void:
	_show_cursor(&"")


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
		if is_targeting():
			_handle_targeting_button(button)
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


## The player's control groups (a saved game stores and restores them).
func control_groups() -> ControlGroups:
	return _groups


## Starts placing `def` with the selected units that can build it.
func begin_placement(def: BuildingDef) -> void:
	var builders: Array[Unit] = SelectionRules.able(selection, Builder.KIND)
	if builders.is_empty() or world == null:
		return
	Events.ui_feedback.emit(&"build_button")
	placement.begin(def, builders, world)


## Starts aiming `option` of the Survey Lab `lab`; the next left click uses it there.
func begin_field_option(lab: Building, option: FieldOptionDef) -> void:
	placement.cancel()
	targeting_lab = lab
	targeting_option = option
	Events.ui_feedback.emit(&"option_button")


## Stops aiming a field option.
func cancel_field_option() -> void:
	targeting_lab = null
	targeting_option = null


func is_targeting() -> bool:
	return targeting_option != null and is_instance_valid(targeting_lab)


## Applies a click of `button` on `target` (unit, building, site, resource node, or
## null for ground at `ground`) under the current scheme. Returns what it did.
func apply_click(button: MouseButton, target: Node3D, ground: Vector3, shift: bool) -> StringName:
	var action: StringName = SelectionRules.resolve(
		Settings.control_scheme, button, selection, selected_building, target, player_faction
	)
	match action:
		SelectionRules.CLICK_SELECT:
			_select_target(target, shift)
		SelectionRules.CLICK_DESELECT:
			if selected_building != null:
				select_building(null)
			elif not selection.is_empty():
				set_selection([])
		SelectionRules.CLICK_ATTACK:
			_issue_attack(target, shift)
		SelectionRules.CLICK_MOVE:
			_move_to_point(ground, shift)
		SelectionRules.CLICK_HARVEST:
			_issue_on_target(HarvestCommand.new(player_faction, [], target, shift), target, shift)
		SelectionRules.CLICK_ASSIST:
			_issue_on_target(BuildCommand.new(player_faction, [], target, shift), target, shift)
		SelectionRules.CLICK_SCAN:
			_issue_on_target(ScanCommand.new(player_faction, [], target, shift), target, shift)
		SelectionRules.CLICK_SABOTAGE:
			_issue_on_target(SabotageCommand.new(player_faction, [], target, shift), target, shift)
		SelectionRules.CLICK_CARRY:
			var carriers: Array[Node3D] = []
			carriers.assign(SelectionRules.able(selection, Carrier.KIND))
			_push(CarryCommand.new(player_faction, carriers, target, shift))
			OrderMarker.spawn(world, target.position, MOVE_MARKER_COLOR)
		SelectionRules.CLICK_RALLY:
			_rally_at(ground)
	return action


## The unit, building, discovery site, carriable prop or resource node under a
## screen position (in that order of priority), or null for ground.
func target_at(screen_position: Vector2) -> Node3D:
	var unit: Unit = unit_at(screen_position)
	if unit != null:
		return unit
	# Buildings before nodes: a Flux Tap stands on its vent, and the click means the Tap.
	var building: Building = building_at(screen_position)
	if building != null:
		return building
	var site: DiscoverySite = site_at(screen_position)
	if site != null:
		return site
	var cargo: Prop = cargo_at(screen_position)
	if cargo != null:
		return cargo
	return resource_node_at(screen_position)


## A carriable prop nobody carries under a screen position (an artefact), or null.
func cargo_at(screen_position: Vector2) -> Prop:
	var origin: Vector3 = camera.camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.camera.project_ray_normal(screen_position)
	for prop: Prop in world.props:
		if not prop.is_carriable() or prop.is_carried():
			continue
		var radius: float = prop.radius() + 0.75
		var box: AABB = AABB(
			prop.position - Vector3(radius, 0.5, radius),
			Vector3(radius * 2.0, prop.height() + 1.0, radius * 2.0)
		)
		if box.intersects_ray(origin, direction) != null:
			return prop
	return null


## Charted discovery site under a screen position, or null.
func site_at(screen_position: Vector2) -> DiscoverySite:
	if world.discovery == null:
		return null
	var origin: Vector3 = camera.camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.camera.project_ray_normal(screen_position)
	for site: DiscoverySite in world.discovery.sites:
		if not site.visible or site.def == null:
			continue
		var radius: float = site.def.radius
		var box: AABB = AABB(
			site.position - Vector3(radius, 0.5, radius),
			Vector3(radius * 2.0, site.def.height + 1.0, radius * 2.0)
		)
		if box.intersects_ray(origin, direction) != null:
			return site
	return null


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
		if not building.visible or building.is_dead:
			continue
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
		if not node.visible:
			continue
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
		if not unit.is_visible_to_player or unit.is_dead:
			continue
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
			if button.pressed:
				_click(MOUSE_BUTTON_RIGHT, button.position, button.shift_pressed)


func _click(button: MouseButton, screen_position: Vector2, shift: bool) -> void:
	apply_click(button, target_at(screen_position), camera.ground_point(screen_position), shift)


func _select_target(target: Node3D, shift: bool) -> void:
	var building: Building = target as Building
	if building != null and building.faction == player_faction:
		select_building(building)
		return
	var unit: Unit = target as Unit
	set_selection(SelectionRules.click(selection, unit, shift, player_faction))


## Gives `command` (harvest, build, scan) to the units able to do it; the rest move next to
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


func _rally_at(target: Vector3) -> void:
	if selected_building == null or selected_building.producer == null:
		return
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


func _handle_targeting_button(button: InputEventMouseButton) -> void:
	if not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			var point: Vector3 = camera.ground_point(button.position)
			if point == Vector3.INF:
				Events.ui_feedback.emit(&"invalid_target")
				return
			_push(FieldOptionCommand.new(player_faction, targeting_lab, targeting_option, point))
			OrderMarker.spawn(world, point, CursorIcons.COLORS[CursorIcons.TARGET])
			cancel_field_option()
		MOUSE_BUTTON_RIGHT:
			cancel_field_option()


func _left_click(screen_position: Vector2, shift: bool) -> void:
	_click(MOUSE_BUTTON_LEFT, screen_position, shift)


func _handle_key(key: InputEventKey) -> void:
	if placement.is_active() and key.keycode == KEY_ESCAPE:
		placement.cancel()
		get_viewport().set_input_as_handled()
		return
	if is_targeting() and key.keycode == KEY_ESCAPE:
		cancel_field_option()
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


## Orders the selected units to move to a ground point (the minimap's right click).
## A selected producer building gets its rally point there instead.
func move_selection_to(target: Vector3, queued: bool) -> void:
	if selected_building != null and selected_building.producer != null:
		_push(RallyCommand.new(player_faction, [selected_building] as Array[Node3D], target))
		return
	_move_to(target, queued)


func _move_to_point(target: Vector3, queued: bool) -> void:
	if selection.is_empty():
		return
	if target == Vector3.INF:
		Events.ui_feedback.emit(&"invalid_target")
		return
	_move_to(target, queued)


func _move_to(target: Vector3, queued: bool) -> void:
	if selection.is_empty():
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


## The cursor for what a command click at `mouse` would do now ("" = the default).
func _hover_cursor(mouse: Vector2) -> StringName:
	if placement.is_active() or get_viewport().gui_get_hovered_control() != null:
		return &""
	if is_targeting():
		return CursorIcons.TARGET
	if selection.is_empty() and selected_building == null:
		return &""
	var scheme: StringName = Settings.control_scheme
	var action: StringName = SelectionRules.resolve(
		scheme,
		SelectionRules.command_button(scheme),
		selection,
		selected_building,
		target_at(mouse),
		player_faction
	)
	return CURSOR_FOR_ACTION.get(action, &"")


func _show_cursor(kind: StringName) -> void:
	if kind == _cursor_shown:
		return
	_cursor_shown = kind
	var texture: Texture2D = CursorIcons.get_cursor(kind) if kind != &"" else null
	if texture == null:
		Input.set_custom_mouse_cursor(null)
		return
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, CursorIcons.hotspot())


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
