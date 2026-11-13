class_name InfiltrationScript
extends MissionScript
## Infiltration rules (PLAN 2.6): no base, a small squad, a guarded outpost. Being
## seen does not end the mission, it changes it: the first time the outpost goes
## Alerted, reinforcements arrive and hunt, the extraction point moves to the far
## edge and a countdown to get out starts. The extraction objective appears once the
## target (the uplink) is sabotaged.

var rules: InfiltrationRules = null
## True once the outpost has been alerted.
var compromised: bool = false
var waves_sent: int = 0

var _deadline_tick: int = -1


func on_started() -> void:
	rules = mission.def.script_rules as InfiltrationRules
	if rules == null:
		push_error("InfiltrationScript: the mission has no InfiltrationRules")
		return
	if mission.guards != null:
		mission.guards.reinforcements_called.connect(_on_reinforcements_called)


func on_objective_finished(objective: Objective) -> void:
	if rules == null or objective.state != Objective.STATE_DONE:
		return
	if objective.id != rules.target_objective or rules.extraction == null:
		return
	if mission.objective(rules.extraction.id) != null:
		return
	var extraction: Objective = ObjectiveFactory.create(rules.extraction)
	if extraction == null:
		return
	if compromised:
		extraction.area_center = rules.alerted_extraction
	mission.add_objective(extraction)
	if compromised:
		extraction.countdown_tick = _deadline_tick
		extraction.countdown_fails = true


func on_alert_changed(faction: int, level: StringName, _previous: StringName) -> void:
	if rules == null or compromised:
		return
	if faction != mission.def.hostile_faction or level != StealthSystem.LEVEL_ALERTED:
		return
	compromised = true
	_deadline_tick = mission.now() + CommanderDifficulty.ticks(rules.alerted_deadline_seconds)
	Events.advisor_alert.emit(&"extraction_moved")
	if rules.extraction == null:
		return
	var extraction: Objective = mission.objective(rules.extraction.id)
	if extraction != null and extraction.is_active():
		extraction.countdown_tick = _deadline_tick
		extraction.countdown_fails = true
		extraction.move_area(rules.alerted_extraction)


func stop() -> void:
	if mission != null and mission.guards != null:
		if mission.guards.reinforcements_called.is_connected(_on_reinforcements_called):
			mission.guards.reinforcements_called.disconnect(_on_reinforcements_called)


func _on_reinforcements_called(_position: Vector3) -> void:
	if rules == null or waves_sent >= rules.max_reinforcement_waves:
		return
	if rules.reinforcements.is_empty() or mission.result != null:
		return
	waves_sent += 1
	var units: Array[Unit] = mission.spawn_group(
		rules.reinforcements, mission.def.hostile_faction, rules.reinforcement_entry, Vector3.BACK
	)
	mission.guards.add_hunters(units)
