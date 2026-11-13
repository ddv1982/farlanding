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


func _on_ticked(tick: int) -> void:
	if (tick + _phase) % BEHAVIOUR_TICKS != 0:
		return
	var running: Array[PatrolBehaviour] = []
	for patrol: PatrolBehaviour in patrols:
		patrol.tick(tick)
		if not patrol.finished:
			running.append(patrol)
	patrols = running


func _on_alert_level_changed(
	alerted_faction: int, level: StringName, _previous: StringName
) -> void:
	if alerted_faction != faction or level != StealthSystem.LEVEL_ALERTED:
		return
	calls += 1
	reinforcements_called.emit(port.alert_position())
