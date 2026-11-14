class_name WaveScript
extends MissionScript
## Holdout (PLAN 2.6, ADR 0015): keep a site alive until extraction. Waves of the
## hostile faction arrive at the times and sizes in the mission's WaveRules (its
## `script_rules`), each announced `warning_seconds` ahead (Advisor `wave_incoming`),
## and go for the player's HQ (the site) as a last-stand AttackGroup (the enemy AI's own
## behaviour: it advances, fights whatever it meets on the way through the command
## queue, and never retreats). At `climax_seconds` the planet's climax is scheduled (Emberfall: the
## surge, which the planet rule announces itself). The extraction is the countdown of
## the survive objective `extraction_objective`: the Advisor says `extraction_inbound`
## `inbound_seconds` before it and `extraction_arrived` when it lands (the win).

var rules: WaveRules = null
## Waves sent so far.
var waves_sent: int = 0
## Waves announced so far.
var waves_warned: int = 0
var inbound_warned: bool = false
var climax_scheduled: bool = false
## The waves on the field (enemy AI behaviours, ticked here).
var groups: Array[AttackGroup] = []

var _port: WorldAiPort = null
var _profile: CommanderProfile = CommanderProfile.new()


func setup(p_mission: Mission) -> void:
	super(p_mission)
	rules = mission.def.script_rules as WaveRules
	_port = WorldAiPort.new(mission.context, mission.world, mission.def.hostile_faction)


func on_started() -> void:
	_schedule_climax()


func on_tick(tick: int) -> void:
	if rules == null or mission.result != null:
		return
	var elapsed: int = tick - mission.started_tick
	var warning: int = CommanderDifficulty.ticks(rules.warning_seconds)
	while waves_warned < rules.wave_count():
		var at: int = CommanderDifficulty.ticks(rules.wave_seconds[waves_warned])
		if elapsed < at - warning:
			break
		waves_warned += 1
		Events.advisor_alert.emit(&"wave_incoming")
	while waves_sent < rules.wave_count():
		if elapsed < CommanderDifficulty.ticks(rules.wave_seconds[waves_sent]):
			break
		_send_wave(waves_sent)
		waves_sent += 1
	if tick % _profile.behaviour_interval_ticks == 0:
		_tick_groups(tick)
	var extraction: Objective = mission.objective(rules.extraction_objective)
	if extraction != null and extraction.is_active() and not inbound_warned:
		if extraction.seconds_left(tick) <= rules.inbound_seconds:
			inbound_warned = true
			Events.advisor_alert.emit(&"extraction_inbound")


func on_objective_finished(objective: Objective) -> void:
	if rules == null or objective.id != rules.extraction_objective:
		return
	if objective.state == Objective.STATE_DONE:
		Events.advisor_alert.emit(&"extraction_arrived")


## The units of wave `index`, in roster order continuing from the waves before it.
func wave_roster(index: int) -> Array[UnitDef]:
	var picked: Array[UnitDef] = []
	if rules == null or rules.roster.is_empty():
		return picked
	var level: StringName = mission.commander_level()
	var start: int = 0
	for i: int in index:
		start += rules.wave_size(i, level)
	for i: int in rules.wave_size(index, level):
		picked.append(rules.roster[(start + i) % rules.roster.size()])
	return picked


func to_dict() -> Dictionary:
	var saved_groups: Array[Dictionary] = []
	for group: AttackGroup in groups:
		if not group.finished:
			saved_groups.append(group.to_dict())
	return {
		"version": 1,
		"waves_sent": waves_sent,
		"waves_warned": waves_warned,
		"inbound_warned": inbound_warned,
		"climax_scheduled": climax_scheduled,
		"groups": saved_groups,
	}


func from_dict(data: Dictionary) -> void:
	waves_sent = data.get("waves_sent", 0)
	waves_warned = data.get("waves_warned", waves_sent)
	inbound_warned = data.get("inbound_warned", false)
	climax_scheduled = data.get("climax_scheduled", false)
	groups.clear()
	var saved_groups: Array = data.get("groups", [])
	for entry: Variant in saved_groups:
		var group_data: Dictionary = entry
		var ids: Array = group_data.get("members", [])
		var units: Array[Unit] = AiGroup.units_from_ids(ids, mission.world.entity)
		if units.is_empty():
			continue
		var group: AttackGroup = _make_group(units)
		group.from_dict(group_data)
		groups.append(group)


func stop() -> void:
	# The groups hold callables back to this script: let go of them.
	groups.clear()


func on_resumed() -> void:
	# The planet saved its own climax; schedule it only if that never happened.
	if not climax_scheduled:
		_schedule_climax()


func _schedule_climax() -> void:
	if rules == null or rules.climax_seconds <= 0.0 or mission.world.planet == null:
		return
	climax_scheduled = true
	var at: int = mission.started_tick + CommanderDifficulty.ticks(rules.climax_seconds)
	mission.world.planet.schedule_climax(at)


func _send_wave(index: int) -> void:
	var roster: Array[UnitDef] = wave_roster(index)
	if roster.is_empty() or rules.entry_points.is_empty():
		return
	var entry: Vector3 = rules.entry_points[index % rules.entry_points.size()]
	var site: Building = mission.player_hq
	var facing: Vector3 = Vector3.FORWARD
	if site != null and is_instance_valid(site):
		facing = Vector3(site.position.x - entry.x, 0.0, site.position.z - entry.z).normalized()
	var units: Array[Unit] = mission.spawn_group(roster, mission.def.hostile_faction, entry, facing)
	var group: AttackGroup = _make_group(units)
	group.start()
	groups.append(group)


## A last-stand group going for the site (the player's HQ), and on to it again.
func _make_group(units: Array[Unit]) -> AttackGroup:
	var target: Vector3 = _site_position()
	var group: AttackGroup = AttackGroup.new(
		_port, _profile, units, AttackGroup.MODE_LAST_STAND, target, target, target
	)
	group.next_target = func(_from: Vector3) -> Vector3: return _site_position()
	return group


func _site_position() -> Vector3:
	var site: Building = mission.player_hq
	if site != null and Combat.is_alive(site):
		return site.position
	return mission.def.player_start


func _tick_groups(tick: int) -> void:
	for group: AttackGroup in groups.duplicate():
		group.tick(tick)
		if group.finished:
			groups.erase(group)
