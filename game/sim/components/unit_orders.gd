class_name UnitOrders
extends Node
## Holds a unit's current order and its queue of follow-up orders (shift-queued
## waypoints) and drives Locomotion through them. A move travels to its point. An
## attack closes on its target, holds at the engagement distance facing it, and ends
## when the target is gone (there is no combat yet). Other kinds (harvest, build) are
## carried out by the unit's OrderHandler components.

## The unit started working on `order`.
signal order_started(order: Order)
## An attack is holding on a target; `point` is where to aim (every tick while held).
signal aim_changed(point: Vector3)
## The unit stopped aiming at anything.
signal aim_cleared

const SAVE_VERSION: int = 1
## An approaching unit stops this far beyond its engagement distance.
const ENGAGE_SLACK: float = 0.75
## A holding unit closes in again once the target is this far beyond the distance.
const LEASH: float = 3.0
## Sim ticks between new approach paths while chasing a moving target.
const REPATH_TICKS: int = 10
## The target must have moved this far from the planned spot to need a new path.
const REPATH_MOVE: float = 2.0
## Height above the target's origin to aim at, in metres.
const AIM_HEIGHT: float = 1.0

## The order being carried out, or null when idle.
var current: Order = null
## Orders waiting after `current`, oldest first.
var queue: Array[Order] = []

var _locomotion: Locomotion = null
var _handlers: Dictionary[StringName, OrderHandler] = {}
## Attack state: holding at engagement distance, ticks until the next re-path, and
## the target position the current approach path was planned for.
var _engaged: bool = false
var _repath_ticks: int = 0
var _path_target: Vector3 = Vector3.INF


func setup(locomotion: Locomotion) -> void:
	_locomotion = locomotion


## Lets `handler` carry out the order kinds it handles.
func add_handler(handler: OrderHandler) -> void:
	for kind: StringName in handler.handles():
		_handlers[kind] = handler


## True if this unit can carry out orders of `kind` (move and attack always).
func can_do(kind: StringName) -> bool:
	return kind == MoveCommand.KIND_MOVE or kind == AttackCommand.KIND or _handlers.has(kind)


## Replaces all orders with `order`, or appends it when `queued`.
func give(order: Order, queued: bool = false) -> void:
	if queued and current != null:
		queue.append(order)
		return
	queue.clear()
	_start(order)


## Drops every order and brakes to a halt.
func stop() -> void:
	queue.clear()
	_leave_current()
	current = null
	if _locomotion != null:
		_locomotion.stop()


func is_idle() -> bool:
	return current == null


## True while an attack order holds at engagement distance.
func is_engaged() -> bool:
	return _engaged


## Where the unit will be once every order is done; `fallback` when idle.
func last_destination(fallback: Vector3) -> Vector3:
	if not queue.is_empty():
		return queue[queue.size() - 1].target_position
	if current != null:
		return current.target_position
	return fallback


## Advances to the next order once the current one is done.
func tick(dt: float = SimClock.TICK_DELTA) -> void:
	if current == null or _locomotion == null:
		return
	if _handlers.has(current.kind):
		if _handlers[current.kind].step(current, dt):
			_advance()
		return
	if current.kind == AttackCommand.KIND:
		_tick_attack()
		return
	if _locomotion.is_travelling():
		return
	_advance()


func to_dict() -> Dictionary:
	var queued: Array[Dictionary] = []
	for order: Order in queue:
		queued.append(order.to_dict())
	return {
		"version": SAVE_VERSION,
		"current": current.to_dict() if current != null else {},
		"queue": queued,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported UnitOrders save version")
	var current_data: Dictionary = data.get("current", {})
	current = Order.from_dict(current_data) if not current_data.is_empty() else null
	queue.clear()
	var queued: Array = data.get("queue", [])
	for entry: Variant in queued:
		var order_data: Dictionary = entry
		queue.append(Order.from_dict(order_data))


## Reconnects restored orders to their target entities: `lookup` is
## `func(id: int) -> Node3D` (SimWorld.entity).
func resolve_targets(lookup: Callable) -> void:
	var all: Array[Order] = queue.duplicate()
	if current != null:
		all.append(current)
	for order: Order in all:
		if order.target_id >= 0 and order.target_entity == null:
			var target: Node3D = lookup.call(order.target_id)
			order.target_entity = target


## Ends the current order and starts the next queued one.
func _advance() -> void:
	_leave_current()
	current = null
	# An order that cannot start (no path) is skipped, not allowed to strand the rest.
	while current == null and not queue.is_empty():
		var next: Order = queue.pop_front()
		_start(next)


func _start(order: Order) -> void:
	_leave_current()
	current = order
	order_started.emit(order)
	if _locomotion == null:
		return
	if _handlers.has(order.kind):
		if not _handlers[order.kind].begin(order):
			current = null
		return
	if order.kind == AttackCommand.KIND:
		order.path = PackedVector3Array()
		if _attack_target() == null:
			current = null
			return
		# Drop any route left from the previous order: it may lead into the target.
		_locomotion.stop()
		_tick_attack()
		return
	var started: bool = false
	if not order.path.is_empty():
		started = _locomotion.follow_path(order.path)
		order.path = PackedVector3Array()
	else:
		started = _locomotion.move_to(order.target_position)
	if not started:
		current = null


## Cleans up after the current order before another replaces it.
func _leave_current() -> void:
	if current != null and _handlers.has(current.kind):
		_handlers[current.kind].end(current)
		return
	if current == null or current.kind != AttackCommand.KIND:
		return
	if _engaged:
		_engaged = false
		aim_cleared.emit()
	_repath_ticks = 0
	_path_target = Vector3.INF
	if _locomotion != null:
		_locomotion.stop()


func _tick_attack() -> void:
	var target: Node3D = _attack_target()
	if target == null:
		_advance()
		return
	var target_position: Vector3 = AttackCommand.position_of(target)
	var position: Vector3 = _locomotion.mover.position
	var distance: float = (
		Vector2(target_position.x - position.x, target_position.z - position.z).length()
	)
	var engage_range: float = current.engage_offset.length()
	if distance <= engage_range + (LEASH if _engaged else ENGAGE_SLACK):
		if not _engaged and _heading_to_engage_spot(target_position, engage_range):
			# Let it brake onto its spot; a hard stop here would slide fast units in.
			return
		if not _engaged:
			_engaged = true
			_locomotion.stop()
		_locomotion.face(target_position)
		aim_changed.emit(target_position + Vector3.UP * AIM_HEIGHT)
		return
	if _engaged:
		_engaged = false
		aim_cleared.emit()
	_repath_ticks -= 1
	if _repath_ticks > 0:
		return
	if not _locomotion.is_travelling() or _path_target.distance_to(target_position) > REPATH_MOVE:
		_path_target = target_position
		_repath_ticks = REPATH_TICKS
		var goal: Vector3 = _locomotion.paths.closest_point(target_position + current.engage_offset)
		_locomotion.move_to(goal)


## True while travelling to a spot at about `engage_range` from the target.
func _heading_to_engage_spot(target_position: Vector3, engage_range: float) -> bool:
	if not _locomotion.is_travelling():
		return false
	var goal: Vector3 = _locomotion.get_destination()
	var goal_distance: float = (
		Vector2(goal.x - target_position.x, goal.z - target_position.z).length()
	)
	return goal_distance <= engage_range + ENGAGE_SLACK


## The current order's target if it can still be attacked, else null.
func _attack_target() -> Node3D:
	var target: Variant = current.target_entity
	if not is_instance_valid(target):
		return null
	var node: Node3D = target
	return node if node.is_inside_tree() else null
