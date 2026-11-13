class_name ScoutBehaviour
extends AiGroup
## One cheap unit exploring for the commander (PLAN 3.5):
##
##   travel -> (waypoint reached, or no way there) -> travel to the next waypoint
##   travel -> (enemies in sight) -> evade -> travel elsewhere
##
## What it sees is recorded by the commander's knowledge as it goes; when it meets
## enemies it moves on rather than fight. It ends when it dies or nothing is left to
## look at.

const TRAVEL: StringName = &"travel"
const EVADE: StringName = &"evade"
const DONE: StringName = &"done"
## A waypoint counts as reached within this distance.
const REACH: float = 10.0
## Enemies within this distance make the scout move on.
const DANGER_RADIUS: float = 20.0
## Longest leg before it picks another waypoint, in sim ticks.
const LEG_TIMEOUT: int = 900

## `func(from: Vector3) -> Vector3`: where to look next (Vector3.INF: nowhere).
var next_point: Callable = Callable()
## `func(point: Vector3) -> void`: the scout could not get to `point`.
var on_unreachable: Callable = Callable()
var waypoint: Vector3 = Vector3.INF
## Waypoints visited and times it met enemies (for logs and tests).
var legs: int = 0
var encounters: int = 0


func _init(p_port: AiPort, p_profile: CommanderProfile, p_scout: Unit) -> void:
	super(p_port, p_profile, [p_scout])
	var me: WeakRef = weakref(self)
	machine.add_state(TRAVEL, TravelState.new(me))
	machine.add_state(EVADE, EvadeState.new(me))
	machine.add_state(DONE, DoneState.new(me))


func start() -> void:
	machine.start(TRAVEL)


func scout() -> Unit:
	return members[0] if not members.is_empty() else null


## Picks the next waypoint from where the scout stands and sends it there. Returns
## false when there is nowhere left to go.
func head_on() -> bool:
	var unit: Unit = scout()
	if unit == null or not next_point.is_valid():
		return false
	waypoint = next_point.call(unit.sim_position())
	if waypoint == Vector3.INF:
		return false
	legs += 1
	order_move(waypoint)
	return true


## True if armed enemies are close to the scout.
func in_danger() -> bool:
	var unit: Unit = scout()
	if unit == null:
		return false
	for enemy: Node3D in port.seen_enemies(unit.sim_position(), DANGER_RADIUS):
		if Combat.is_armed(enemy):
			return true
	return false


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	data["waypoint"] = var_to_str(waypoint)
	data["legs"] = legs
	data["encounters"] = encounters
	return data


func from_dict(data: Dictionary) -> void:
	var text: String = data.get("waypoint", var_to_str(Vector3.INF))
	waypoint = str_to_var(text)
	super(data)
	legs = data.get("legs", legs)
	encounters = data.get("encounters", encounters)


## Travelling on: keep the saved waypoint (entered as after evading, which picks
## none) and walk on to it.
func _resume_state(state_name: StringName) -> void:
	if state_name == TRAVEL and waypoint != Vector3.INF:
		machine.resume(state_name, EVADE)
		order_move(waypoint)
		return
	machine.resume(state_name)


class ScoutState:
	extends State

	var _scout: WeakRef

	func _init(scout: WeakRef) -> void:
		_scout = scout

	func behaviour() -> ScoutBehaviour:
		var value: Variant = _scout.get_ref()
		if value == null:
			return null
		var found: ScoutBehaviour = value
		return found


class TravelState:
	extends ScoutState

	var _started: int = 0

	func enter(previous: StringName) -> void:
		var b: ScoutBehaviour = behaviour()
		_started = b.port.now()
		if previous == EVADE:
			return
		if not b.head_on():
			b.waypoint = Vector3.INF

	func tick(_sim_tick: int) -> StringName:
		var b: ScoutBehaviour = behaviour()
		if b.waypoint == Vector3.INF:
			return DONE
		if b.in_danger():
			b.encounters += 1
			return EVADE
		var unit: Unit = b.scout()
		var at: Vector3 = unit.sim_position()
		var arrived: bool = AiGroup.flat_distance(at, b.waypoint) <= REACH
		var stalled: bool = unit.orders.is_idle() and not arrived
		if stalled and b.on_unreachable.is_valid():
			b.on_unreachable.call(b.waypoint)
		if arrived or stalled or b.port.now() - _started > LEG_TIMEOUT:
			_started = b.port.now()
			if not b.head_on():
				return DONE
		return &""


## Met enemies: carry on to somewhere else at once (its look was already recorded),
## and keep going until clear of them (or a few seconds passed) before looking again.
class EvadeState:
	extends ScoutState

	const STEPS: int = 6

	var _steps: int = 0

	func enter(_previous: StringName) -> void:
		_steps = 0
		var b: ScoutBehaviour = behaviour()
		if not b.head_on():
			b.waypoint = Vector3.INF

	func tick(_sim_tick: int) -> StringName:
		var b: ScoutBehaviour = behaviour()
		if b.waypoint == Vector3.INF:
			return DONE
		_steps += 1
		if _steps >= STEPS or not b.in_danger():
			return TRAVEL
		return &""


class DoneState:
	extends ScoutState

	func enter(_previous: StringName) -> void:
		behaviour().finish()
