class_name GuardCommander
extends Node
## Runs a faction's guards (PLAN 2.6, ADR 0010): one PatrolBehaviour per patrol
## route, plus groups of hunters (reinforcements). It ticks them on the SimClock and,
## when its faction becomes alerted, calls for reinforcements once per alert
## (`reinforcements_called`, answered by the mission). Like the commander it acts
## only through the CommandQueue and knows only what its faction knows.

## The faction went Alerted: help is wanted near `position` (where the intruder was
## last noticed).
signal reinforcements_called(position: Vector3)

const SAVE_VERSION: int = 1
## Sim ticks between behaviour steps.
const BEHAVIOUR_TICKS: int = 5

var context: MissionContext
var world: SimWorld
var faction: int = 1
var port: WorldAiPort
var patrols: Array[PatrolBehaviour] = []
## Times it called for reinforcements.
var calls: int = 0

var _phase: int = 0


func setup(p_context: MissionContext, p_world: SimWorld, p_faction: int) -> void:
	context = p_context
	world = p_world
	faction = p_faction
	port = WorldAiPort.new(context, world, faction)
	_phase = (faction * 3 + 1) % BEHAVIOUR_TICKS
	context.sim_clock.ticked.connect(_on_ticked)
	Events.alert_level_changed.connect(_on_alert_level_changed)


## Puts `units` on `route` (null: they hold where they stand) and starts them.
func add_patrol(route: PatrolRoute, units: Array[Unit]) -> PatrolBehaviour:
	var patrol: PatrolBehaviour = PatrolBehaviour.new(port, route, units)
	patrol.start()
	patrols.append(patrol)
	return patrol


## Adds a group that holds at `units`' position and hunts when the faction is alerted.
func add_hunters(units: Array[Unit]) -> PatrolBehaviour:
	return add_patrol(null, units)


## Every unit the guards command.
func guards() -> Array[Unit]:
	var result: Array[Unit] = []
	for patrol: PatrolBehaviour in patrols:
		patrol.prune()
		result.append_array(patrol.members)
	return result


## The guards' state for a saved game; `routes` is the mission's patrol list (a
## patrol is saved as its index there, -1 for hunters without a route).
func to_dict(routes: Array[PatrolRoute] = []) -> Dictionary:
	var saved: Array[Dictionary] = []
	for patrol: PatrolBehaviour in patrols:
		if patrol.finished:
			continue
		var data: Dictionary = patrol.to_dict()
		data["route"] = routes.find(patrol.route) if patrol.route != null else -1
		saved.append(data)
	return {"version": SAVE_VERSION, "calls": calls, "patrols": saved}


## Brings back the patrols `to_dict()` saved, on the same `routes`, with their units.
func from_dict(data: Dictionary, routes: Array[PatrolRoute]) -> void:
	calls = data.get("calls", 0)
	var saved: Array = data.get("patrols", [])
	for entry: Variant in saved:
		var patrol_data: Dictionary = entry
		var index: int = patrol_data.get("route", -1)
		var route: PatrolRoute = routes[index] if index >= 0 and index < routes.size() else null
		var ids: Array = patrol_data.get("members", [])
		var units: Array[Unit] = AiGroup.units_from_ids(ids, world.entity)
		if units.is_empty():
			continue
		var patrol: PatrolBehaviour = PatrolBehaviour.new(port, route, units)
		patrol.from_dict(patrol_data)
		patrols.append(patrol)


func _on_ticked(tick: int) -> void:
	if (tick + _phase) % BEHAVIOUR_TICKS != 0:
		return
	var running: Array[PatrolBehaviour] = []
	for patrol: PatrolBehaviour in patrols:
		patrol.tick(tick)
		if not patrol.finished:
			running.append(patrol)
	patrols = running


func _on_alert_level_changed(alerted_faction: int, level: StringName, previous: StringName) -> void:
	# `previous == level` is a re-announcement (a start or a load), not a new alert.
	if alerted_faction != faction or level != StealthSystem.LEVEL_ALERTED or previous == level:
		return
	calls += 1
	reinforcements_called.emit(port.alert_position())
