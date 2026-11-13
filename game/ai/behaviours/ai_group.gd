class_name AiGroup
extends RefCounted
## Base of the AI's unit behaviours: a set of own units driven by a small typed
## StateMachine (core/state_machine.gd). The commander ticks it every few sim ticks;
## states read the group through helpers here and give orders only through the port.

## Fewest sim ticks between two orders to idle members (anti-spam).
const REORDER_TICKS: int = 30
## A group this close to a dry crossing goes straight on.
const CROSSING_REACHED: float = 12.0

var port: AiPort
var profile: CommanderProfile
var members: Array[Unit] = []
var machine: StateMachine = StateMachine.new()
## True once the behaviour is over; its surviving units are free again.
var finished: bool = false
## Sim tick of the last order this group gave.
var last_order_tick: int = -1000000
## Strength when the group formed.
var initial_strength: float = 0.0


func _init(p_port: AiPort, p_profile: CommanderProfile, p_members: Array[Unit]) -> void:
	port = p_port
	profile = p_profile
	members = p_members.duplicate()
	initial_strength = strength()


## Name of the active state.
func state() -> StringName:
	return machine.get_current_state()


## One behaviour step: forgets dead members, ends when none are left, runs the state.
func tick(sim_tick: int) -> void:
	if finished:
		return
	prune()
	if members.is_empty():
		finish()
		return
	machine.tick(sim_tick)


func finish() -> void:
	finished = true


## Drops members that died or left the world.
func prune() -> void:
	var alive: Array[Unit] = []
	for unit: Unit in members:
		if Combat.is_alive(unit):
			alive.append(unit)
	members = alive


func has_member(unit: Unit) -> bool:
	return members.has(unit)


## The helpers below first drop members that died since the last step: a unit can be
## freed between two behaviour ticks while others still read the group.
func centroid() -> Vector3:
	prune()
	if members.is_empty():
		return Vector3.ZERO
	var sum: Vector3 = Vector3.ZERO
	for unit: Unit in members:
		sum += unit.sim_position()
	return sum / members.size()


## Radius a group of this size takes up when packed in formation, in metres.
func body_radius() -> float:
	return sqrt(float(members.size())) * 1.6


## True when at least `share` of the members are within `radius` (plus the group's own
## packed size) of `point`.
func gathered_at(point: Vector3, radius: float, share: float = 0.75) -> bool:
	return share_within(point, radius + body_radius()) >= share


## True when the column has strung out: fewer than 70 % of the members are within
## `radius` (plus the group's packed size) of its centre.
func strung_out(radius: float) -> bool:
	return not gathered_at(centroid(), radius, 0.7)


## Lets go of members further than `radius` (plus the group's packed size) from
## `point`, as long as at least half the group stays; they are free units again.
## Returns how many were dropped.
func drop_stragglers(point: Vector3, radius: float) -> int:
	var reach: float = radius + body_radius()
	var kept: Array[Unit] = []
	for unit: Unit in members:
		if flat_distance(unit.sim_position(), point) <= reach:
			kept.append(unit)
	if kept.size() * 2 < members.size():
		return 0
	var dropped: int = members.size() - kept.size()
	members = kept
	return dropped


## Distance of the furthest member from the centre.
func spread() -> float:
	prune()
	var centre: Vector3 = centroid()
	var widest: float = 0.0
	for unit: Unit in members:
		widest = maxf(widest, flat_distance(unit.sim_position(), centre))
	return widest


func strength() -> float:
	prune()
	var total: float = 0.0
	for unit: Unit in members:
		total += AiKnowledge.strength_of(unit)
	return total


## Share of members within `radius` of `point`.
func share_within(point: Vector3, radius: float) -> float:
	prune()
	if members.is_empty():
		return 0.0
	var near: int = 0
	for unit: Unit in members:
		if flat_distance(unit.sim_position(), point) <= radius:
			near += 1
	return float(near) / members.size()


func idle_share() -> float:
	prune()
	if members.is_empty():
		return 0.0
	var idle: int = 0
	for unit: Unit in members:
		if unit.orders == null or unit.orders.is_idle():
			idle += 1
	return float(idle) / members.size()


## Enemies the faction sees around the group.
func seen_enemies() -> Array[Node3D]:
	var reach: float = profile.contact_radius + minf(spread(), 20.0)
	return port.seen_enemies(centroid(), reach)


## Orders every member to `point` as one group move. While the tide makes the
## shallows unsafe and the way crosses the deep channel, the group walks through the
## map's dry crossing first (ADR 0014).
func order_move(point: Vector3) -> void:
	var nodes: Array[Node3D] = _as_nodes(members)
	var via: Vector3 = _tide_waypoint(point)
	if via != Vector3.INF:
		port.push(MoveCommand.new(MoveCommand.KIND_MOVE, port.faction, nodes, via))
		port.push(MoveCommand.new(MoveCommand.KIND_MOVE, port.faction, nodes, point, true))
	else:
		port.push(MoveCommand.new(MoveCommand.KIND_MOVE, port.faction, nodes, point))
	last_order_tick = port.now()


## The dry crossing to walk through on the way to `point`, or Vector3.INF: only while
## the shallows would flood before the group is across (the next rise is less than
## `tide_safe_seconds` away, or the sea is not at low water) and the straight way
## crosses the deep channel.
func _tide_waypoint(point: Vector3) -> Vector3:
	if port.shallows_close_seconds() == INF:
		return Vector3.INF
	var safe: bool = (
		port.tide_level() <= 0.0 and port.shallows_close_seconds() >= profile.tide_safe_seconds
	)
	if safe or members.is_empty():
		return Vector3.INF
	var from: Vector3 = centroid()
	var via: Vector3 = port.dry_crossing(from, point)
	if via == Vector3.INF or flat_distance(from, via) < CROSSING_REACHED:
		return Vector3.INF
	return via


## Orders every member to attack `target`.
func order_attack(target: Node3D) -> void:
	port.push(AttackCommand.new(port.faction, _as_nodes(members), target))
	last_order_tick = port.now()


## True if enough time passed since the last order to give another one.
func may_reorder() -> bool:
	return port.now() - last_order_tick >= REORDER_TICKS


## The group's state for a saved game: members by save id, the active state and
## the shared fields. Subclasses add their own.
func to_dict() -> Dictionary:
	prune()
	var ids: Array[int] = []
	for unit: Unit in members:
		ids.append(unit.entity_id)
	return {
		"members": ids,
		"state": String(state()),
		"last_order": last_order_tick,
		"strength": initial_strength,
	}


## Restores what `to_dict()` saved. Subclasses set their own fields first, then call
## this: it re-enters the saved state (which re-issues its order, as entering it
## always does) and puts back the shared fields.
func from_dict(data: Dictionary) -> void:
	var saved_state: String = data.get("state", "")
	if saved_state != "" and machine.has_state(StringName(saved_state)):
		_resume_state(StringName(saved_state))
	last_order_tick = data.get("last_order", last_order_tick)
	initial_strength = data.get("strength", initial_strength)


## The live units of `ids` (saved members). `lookup` is `func(id: int) -> Node3D`.
static func units_from_ids(ids: Array, lookup: Callable) -> Array[Unit]:
	var found: Array[Unit] = []
	for entry: Variant in ids:
		var id: int = entry
		var unit_node: Node3D = lookup.call(id)
		var unit: Unit = unit_node as Unit
		if Combat.is_alive(unit):
			found.append(unit)
	return found


## Enters a saved state after a load; override to choose how it is entered.
func _resume_state(state_name: StringName) -> void:
	machine.resume(state_name)


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _as_nodes(units: Array[Unit]) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for unit: Unit in units:
		nodes.append(unit)
	return nodes
