class_name UnitOrders
extends Node
## Holds a unit's current order and its queue of follow-up orders (shift-queued
## waypoints) and drives Locomotion through them. A move travels to its point. An
## attack closes on its target to the engagement distance (just inside weapon range),
## holds there facing it while the Weapon fires, and ends when the target is dead or
## the unit's faction loses sight of it (a commanded attack then walks on to where it
## was last seen). Attacks a unit gives itself (`engage()`) stay on a leash around
## where it stood and walk back there when done. Other kinds (harvest, build) are
## carried out by the unit's OrderHandler components.

## The unit started working on `order`.
signal order_started(order: Order)

const SAVE_VERSION: int = 1
## An approaching unit stops this far beyond its engagement distance.
const ENGAGE_SLACK: float = 0.75
## A holding unit closes in again once the target is this far beyond the distance.
const LEASH: float = 1.25
## The engagement distance is this much inside weapon range.
const ENGAGE_MARGIN: float = 1.5
## A self-given attack is dropped once its target is this much further from the
## guard spot than the unit may reach (hysteresis against re-engaging at once).
const GIVE_UP_SLACK: float = 2.0
## A unit further than this from its guard spot after a self-given attack walks back.
const GUARD_RADIUS: float = 2.0
## Sim ticks between new approach paths while chasing a moving target.
const REPATH_TICKS: int = 10
## The target must have moved this far from the planned spot to need a new path.
const REPATH_MOVE: float = 2.0
## Height above the target's origin to aim at, in metres.
const AIM_HEIGHT: float = 1.0
## A unit backing out of its minimum range walks this far past it.
const BACK_OFF_SLACK: float = 3.0

## The order being carried out, or null when idle.
var current: Order = null
## Orders waiting after `current`, oldest first.
var queue: Array[Order] = []
## Distance from a target at which this unit stops and fires (weapon range minus a
## margin; set by the unit).
var engage_distance: float = AttackCommand.ENGAGE_RANGE
## Artillery cannot hit closer than this (its minimum range plus a margin): an attack
## whose target is nearer backs away first; 0 = no minimum (set by the unit).
var min_engage_distance: float = 0.0
## `func(target: Variant) -> bool`: may this unit's faction shoot `target` now
## (alive, hostile, seen)? Unset: any live target counts.
var can_target: Callable = Callable()

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
## Does `order` right now, then resumes the current order and the queue.
func interrupt(order: Order) -> void:
	var resume: Order = current
	_leave_current()
	current = null
	if resume != null:
		queue.push_front(resume)
	_start(order)
	if current == null:
		# The interruption could not start (no path): carry on with what was queued.
		_advance()


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


## The target of the current attack order if it can still be attacked, else null.
func attack_target() -> Node3D:
	if current == null or current.kind != AttackCommand.KIND:
		return null
	return _attack_target()


## True while carrying out an attack the unit gave itself.
func is_auto_attacking() -> bool:
	return current != null and current.kind == AttackCommand.KIND and current.leash > 0.0


## Attacks `target` on the unit's own initiative: from `guard`, walking at most
## `leash` metres beyond its engagement distance, then back to `guard`.
func engage(target: Node3D, guard: Vector3, leash: float) -> void:
	var target_position: Vector3 = AttackCommand.position_of(target)
	var away: Vector3 = guard - target_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.BACK
	var order: Order = Order.new(AttackCommand.KIND, target_position)
	order.target_entity = target
	order.engage_offset = (
		away.normalized() * (engage_distance + AttackCommand.body_radius(target))
	)
	order.guard = guard
	order.leash = maxf(leash, 0.01)
	give(order)


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


## Ends the current order and starts the next queued one. A self-given attack with
## nothing queued after it walks back to its guard spot.
func _advance() -> void:
	var back: Order = _guard_return()
	_leave_current()
	current = null
	if back != null:
		_start(back)
		if current != null:
			return
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
	_engaged = false
	_repath_ticks = 0
	_path_target = Vector3.INF
	if _locomotion != null:
		_locomotion.stop()


func _tick_attack() -> void:
	var target: Node3D = _attack_target()
	if target == null:
		_advance()
		return
	if can_target.is_valid() and not can_target.call(target):
		_lose_sight()
		return
	var target_position: Vector3 = AttackCommand.position_of(target)
	current.target_position = target_position
	var position: Vector3 = _locomotion.mover.position
	var distance: float = (
		Vector2(target_position.x - position.x, target_position.z - position.z).length()
	)
	var engage_range: float = minf(
		current.engage_offset.length(), engage_distance + AttackCommand.body_radius(target)
	)
	if min_engage_distance > 0.0:
		var inner: float = min_engage_distance + AttackCommand.body_radius(target)
		if distance < inner:
			_back_away(target_position, position, inner)
			return
	if current.leash > 0.0:
		var from_guard: float = (
			Vector2(target_position.x - current.guard.x, target_position.z - current.guard.z)
			. length()
		)
		if from_guard > engage_range + current.leash + GIVE_UP_SLACK:
			_advance()
			return
	if distance <= engage_range + (LEASH if _engaged else ENGAGE_SLACK):
		_hold(target_position, engage_range)
		return
	_approach(target_position, engage_range)


## In reach: stop on the spot and face the target while the weapon fires.
func _hold(target_position: Vector3, engage_range: float) -> void:
	if not _engaged and _heading_to_engage_spot(target_position, engage_range):
		# Let it brake onto its spot; a hard stop here would slide fast units in.
		return
	if not _engaged:
		_engaged = true
		_locomotion.stop()
	_locomotion.face(target_position)


## Out of reach: (re)plan a path to a spot `engage_range` from the target.
func _approach(target_position: Vector3, engage_range: float) -> void:
	_engaged = false
	_repath_ticks -= 1
	if _repath_ticks > 0:
		return
	if not _locomotion.is_travelling() or _path_target.distance_to(target_position) > REPATH_MOVE:
		_path_target = target_position
		_repath_ticks = REPATH_TICKS
		var offset: Vector3 = current.engage_offset
		if offset.length() > engage_range:
			offset = offset.normalized() * engage_range
		var goal: Vector3 = _locomotion.paths.closest_point(target_position + offset)
		_locomotion.move_to(goal)


## The target is inside the minimum range: walk straight away from it until it can be
## hit (artillery), instead of standing there unable to fire.
func _back_away(target_position: Vector3, position: Vector3, inner: float) -> void:
	_engaged = false
	var away: Vector3 = position - target_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = (
			current.engage_offset if current.engage_offset.length_squared() > 0.01 else Vector3.BACK
		)
	var goal: Vector3 = _locomotion.paths.closest_point(
		target_position + away.normalized() * (inner + BACK_OFF_SLACK)
	)
	_repath_ticks -= 1
	if _locomotion.is_travelling() and _repath_ticks > 0:
		return
	if (
		_locomotion.is_travelling()
		and _locomotion.get_destination().distance_to(goal) < REPATH_MOVE
	):
		return
	_repath_ticks = REPATH_TICKS
	_path_target = Vector3.INF
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
	if not node.is_inside_tree() or node.is_queued_for_deletion():
		return null
	var health: Health = Combat.health_of(node)
	return null if health != null and health.is_dead() else node


## The target slipped out of sight: a self-given attack ends; a commanded one walks
## on to where the target was last seen.
func _lose_sight() -> void:
	if current.leash > 0.0:
		_advance()
		return
	var search: Order = Order.new(MoveCommand.KIND_MOVE, current.target_position)
	_leave_current()
	current = null
	_start(search)
	if current == null:
		_advance()


## The walk back to the guard spot after a self-given attack, or null.
func _guard_return() -> Order:
	if current == null or current.leash <= 0.0 or not queue.is_empty() or _locomotion == null:
		return null
	var at: Vector3 = _locomotion.mover.position
	if Vector2(at.x - current.guard.x, at.z - current.guard.z).length() <= GUARD_RADIUS:
		return null
	return Order.new(MoveCommand.KIND_MOVE, current.guard)
