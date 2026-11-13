extends GutTest
## Hollow Meridian's missions (ADR 0017). Power Up's `hold_machines` objective: the
## clock runs while the side runs enough engines and pauses (never resets) while it does
## not; the player's completes, the Combine's fails the mission. The finale's CoreScript:
## a side charges the Beacon Core while it runs enough engines and a scanner stands
## linked by it, faster with more engines; both linked is contested; Custodians wake in
## stages and converge; the player's full charge wakes the Core (won), the Combine's
## loses the mission, so does losing the Lander; the Combine sends a linker; the
## script's state saves and loads.

const CORE_AT: Vector3 = Vector3(0, 0, 0)

var _f: MissionFixture
var _rule: MachineryRule
var _engine_def: BuildingDef
var _core_def: PropDef
var _rules: CoreRules
var _charges: Array[float] = []
var _awakened: Array[Node3D] = []
var _ended: Array[bool] = []


func before_each() -> void:
	_f = MissionFixture.new(self)
	_rule = MachineryRule.new()
	_rule.system = MachinerySystem
	_rule.reactivate_seconds = 3.0
	_engine_def = BuildingDef.new()
	_engine_def.id = &"engine"
	_engine_def.footprint = Rect2(-2, -2, 4, 4)
	_engine_def.max_health = 200
	_engine_def.power_output = 15
	_engine_def.machine = true
	_core_def = PropDef.new()
	_core_def.id = &"test_core"
	_core_def.size = Vector3(6, 4, 6)
	_core_def.blocks_sight = false
	_rules = CoreRules.new()
	_rules.core_id = &"test_core"
	_rules.engines_needed = 2
	_rules.link_radius = 10.0
	_rules.charge_seconds = 10.0
	_rules.extra_engine_rate = 1.0
	_rules.stage_charges = PackedFloat32Array([0.3])
	_rules.stage_radii = PackedFloat32Array([40.0])
	_rules.enemy_link_after_seconds = 0.0
	_rules.enemy_escort = 0
	_rules.enemy_strike = 0
	var planet: PlanetDef = PlanetDef.new()
	planet.id = &"test_hollow"
	planet.rule = _rule
	_f.def.planet = planet
	_f.def.player_hq = _f.combat.hq
	_f.def.hostile_start = Vector3(60, 0, 60)
	_f.def.player_start = Vector3(-60, 0, -60)
	_charges.clear()
	_awakened.clear()
	_ended.clear()
	Events.core_charge_changed.connect(_on_charge)
	Events.core_awakened.connect(_on_awakened)
	Events.mission_ended.connect(_on_ended)


func after_each() -> void:
	Events.core_charge_changed.disconnect(_on_charge)
	Events.core_awakened.disconnect(_on_awakened)
	Events.mission_ended.disconnect(_on_ended)
	_f.dispose()


func _on_charge(fraction: float) -> void:
	_charges.append(fraction)


func _on_awakened(core: Node3D) -> void:
	_awakened.append(core)


func _on_ended(won: bool) -> void:
	_ended.append(won)


func _seconds(seconds: float) -> void:
	_f.tick(roundi(seconds * SimClock.TICK_RATE))


## `count` engines running for `faction`, placed in a row.
func _engines(faction: int, count: int, row: float) -> Array[Building]:
	var made: Array[Building] = []
	for i: int in count:
		var engine: Building = _f.world.spawn_building(
			_engine_def, Factions.CUSTODIANS, Vector3(-40 + i * 10, 0, row), true
		)
		engine.faction = faction
		engine.machine.set_state(Machine.RUNNING)
		made.append(engine)
	return made


func _hold(id: StringName, side: StringName, amount: int, seconds: float) -> ObjectiveDef:
	var props: Dictionary = {"side": side, "amount": amount, "seconds": seconds}
	if side == ObjectiveDef.SIDE_ENEMY:
		props["passive"] = true
	return MissionFixture.objective(id, ObjectiveDef.TYPE_HOLD_MACHINES, &"primary", props)


func _start_finale() -> Mission:
	_f.world.spawn_prop(_core_def, CORE_AT)
	_f.def.mission_script = CoreScript
	_f.def.script_rules = _rules
	var wake: ObjectiveDef = MissionFixture.objective(
		&"wake_core", ObjectiveDef.TYPE_CORE_CHARGE, &"primary", {"side": &"player"}
	)
	var rival: ObjectiveDef = MissionFixture.objective(
		&"rival_core",
		ObjectiveDef.TYPE_CORE_CHARGE,
		&"primary",
		{"side": &"enemy", "passive": true}
	)
	var keep: ObjectiveDef = MissionFixture.objective(
		&"keep_lander",
		ObjectiveDef.TYPE_KEEP_ALIVE,
		&"primary",
		{"side": &"player", "passive": true, "defs": [_f.combat.hq] as Array[EntityDef]}
	)
	var hq: Building = _f.world.spawn_building(_f.combat.hq, 0, Vector3(-60, 0, -60), true)
	var mission: Mission = _f.start([wake, rival, keep] as Array[ObjectiveDef])
	mission.player_hq = hq
	return mission


func _script(mission: Mission) -> CoreScript:
	return mission.script_instance as CoreScript


func test_the_missions_are_on_hollow_meridian() -> void:
	var power: MissionDef = load("res://data/missions/hollow_power.tres")
	var finale: MissionDef = load("res://data/missions/hollow_finale.tres")
	for mission: MissionDef in [power, finale]:
		assert_eq(mission.planet.id, &"hollow_meridian", String(mission.id))
		assert_true(mission.planet.rule is MachineryRule)
		assert_eq(mission.commander_profile.resource_path, "res://data/ai/combine_meridian.tres")
		assert_gt(mission.commander_profile.machines_wanted, 3, "the Combine wants engines")
	assert_eq(power.mission_type, MissionDef.TYPE_POWER)
	assert_eq(finale.mission_type, MissionDef.TYPE_FINALE)
	assert_eq(finale.mission_script, CoreScript)
	var rules: CoreRules = finale.script_rules as CoreRules
	assert_not_null(rules)
	assert_eq(rules.core_id, &"antecedent_site_core")
	var types: Array[StringName] = []
	for objective: ObjectiveDef in finale.objectives:
		types.append(objective.type)
	assert_eq(types.count(ObjectiveDef.TYPE_CORE_CHARGE), 2, "ours and the Combine's")
	assert_true(types.has(ObjectiveDef.TYPE_KEEP_ALIVE), "the Lander")
	types.clear()
	for objective: ObjectiveDef in power.objectives:
		types.append(objective.type)
	assert_eq(types.count(ObjectiveDef.TYPE_HOLD_MACHINES), 2, "ours and the Combine's")


func test_holding_engines_runs_the_clock_and_pausing_keeps_it() -> void:
	var mission: Mission = _f.start([_hold(&"hold", &"player", 2, 3.0)] as Array[ObjectiveDef])
	var engines: Array[Building] = _engines(0, 2, 30)
	_seconds(2.0)
	var hold: HoldMachinesObjective = mission.objective(&"hold") as HoldMachinesObjective
	assert_almost_eq(hold.progress_ratio, 0.66, 0.05)
	assert_true(hold.is_active())
	engines[0].faction = 1
	_seconds(5.0)
	assert_almost_eq(hold.progress_ratio, 0.66, 0.05, "paused, not reset")
	assert_string_contains(hold.progress_text, "now 1")
	engines[0].faction = 0
	_seconds(1.5)
	assert_eq(hold.state, Objective.STATE_DONE)
	assert_eq(_ended, [true], "Power Up won")


func test_the_combine_out_holding_the_player_loses_the_mission() -> void:
	var mission: Mission = _f.start(
		(
			[_hold(&"hold", &"player", 3, 30.0), _hold(&"rival", &"enemy", 2, 2.0)]
			as Array[ObjectiveDef]
		)
	)
	_engines(1, 2, -30)
	_seconds(2.5)
	assert_eq(mission.objective(&"rival").state, Objective.STATE_FAILED)
	assert_eq(_ended, [false])


func test_the_core_charges_with_enough_engines_and_a_linked_surveyor() -> void:
	var mission: Mission = _start_finale()
	var script: CoreScript = _script(mission)
	assert_not_null(script.core(), "the Core on the map")
	var surveyor: Unit = _f.spawn(_f.discovery.surveyor, 0, Vector3(6, 0, 0))
	_engines(0, 1, 30)
	_seconds(2.0)
	assert_eq(script.charge_of(0), 0.0, "one engine is not enough")
	assert_string_contains(script.status_line(0), "1 of 2 engines")
	_engines(0, 1, 40)
	_seconds(2.0)
	assert_almost_eq(script.charge_of(0), 0.2, 0.02, "two engines: 10 s to full")
	_engines(0, 1, 50)
	_seconds(1.0)
	assert_almost_eq(script.charge_of(0), 0.4, 0.02, "a third engine doubles it")
	SaveFixture.teleport(surveyor, Vector3(30, 0, 0))
	_seconds(2.0)
	assert_almost_eq(script.charge_of(0), 0.4, 0.02, "unlinked: it holds")
	assert_string_contains(script.status_line(0), "no Surveyor")
	assert_false(_charges.is_empty(), "the charge is announced")
	assert_almost_eq(_charges[_charges.size() - 1], 0.4, 0.05)


func test_a_full_charge_wakes_the_core_and_wins() -> void:
	var mission: Mission = _start_finale()
	_f.spawn(_f.discovery.surveyor, 0, Vector3(6, 0, 0))
	_engines(0, 2, 30)
	_seconds(10.5)
	assert_eq(mission.objective(&"wake_core").state, Objective.STATE_DONE)
	assert_eq(_awakened.size(), 1, "core_awakened")
	assert_eq(_awakened[0], _script(mission).core())
	assert_eq(_ended, [true])
	assert_true(mission.result.won)
	assert_eq(_charges[_charges.size() - 1], 1.0)


func test_the_combine_waking_it_first_loses_the_mission() -> void:
	var mission: Mission = _start_finale()
	_f.spawn(_f.discovery.surveyor, 1, Vector3(-6, 0, 0))
	_engines(1, 2, -30)
	_seconds(10.5)
	assert_eq(mission.objective(&"rival_core").state, Objective.STATE_FAILED)
	assert_eq(_ended, [false])
	assert_true(_awakened.is_empty(), "the Core does not wake for the player")


func test_losing_the_lander_loses_the_finale() -> void:
	var mission: Mission = _start_finale()
	_seconds(0.5)
	mission.player_hq.health.take(100000.0, null)
	_seconds(0.5)
	assert_eq(_ended, [false])


func test_a_contested_dais_charges_nobody() -> void:
	var mission: Mission = _start_finale()
	var script: CoreScript = _script(mission)
	_f.spawn(_f.discovery.surveyor, 0, Vector3(6, 0, 0))
	_f.spawn(_f.discovery.surveyor, 1, Vector3(-6, 0, 0))
	_engines(0, 2, 30)
	_engines(1, 2, -30)
	_seconds(3.0)
	assert_eq(script.charge_of(0), 0.0)
	assert_eq(script.charge_of(1), 0.0)
	assert_string_contains(script.status_line(0), "contested")


func test_custodians_wake_in_stages_and_converge_on_the_dais() -> void:
	var mission: Mission = _start_finale()
	var script: CoreScript = _script(mission)
	var near: Unit = _f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(0, 0, 30))
	var far: Unit = _f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(0, 0, -80))
	_f.spawn(_f.discovery.surveyor, 0, Vector3(6, 0, 0))
	_engines(0, 2, 60)
	_seconds(2.0)
	assert_true(near.is_dormant, "not yet")
	_seconds(1.5)
	assert_eq(script.stages_woken, 1)
	assert_false(near.is_dormant, "the first stage woke")
	assert_true(far.is_dormant, "beyond that stage's radius")
	assert_eq(script.custodian_groups.size(), 1)
	assert_true(script.custodian_groups[0].has_member(near), "converging on the dais")


func test_the_combine_sends_a_linker_once_it_runs_enough_engines() -> void:
	var mission: Mission = _start_finale()
	var script: CoreScript = _script(mission)
	var rigger: Unit = _f.spawn(_f.discovery.surveyor, 1, Vector3(50, 0, 50))
	_seconds(1.0)
	assert_eq(script.enemy_linker, -1, "not without engines")
	_engines(1, 2, -30)
	_seconds(1.0)
	assert_eq(script.enemy_linker, rigger.entity_id)
	_seconds(12.0)
	assert_true(script.is_linked(1), "it reached the dais")
	assert_gt(script.charge_of(1), 0.0)


func test_the_finale_state_saves_and_loads() -> void:
	var mission: Mission = _start_finale()
	var script: CoreScript = _script(mission)
	_f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(0, 0, 30))
	_f.spawn(_f.discovery.surveyor, 0, Vector3(6, 0, 0))
	_engines(0, 2, 60)
	_seconds(4.0)
	var saved: Dictionary = script.to_dict()
	var restored: CoreScript = CoreScript.new()
	restored.setup(mission)
	restored.from_dict(saved)
	assert_almost_eq(restored.charge_of(0), script.charge_of(0), 0.0001)
	assert_eq(restored.stages_woken, 1)
	assert_eq(restored.custodian_groups.size(), 1)
	var resaved: Dictionary = restored.to_dict()
	var charges_again: Dictionary = resaved["charges"]
	var charges: Dictionary = saved["charges"]
	assert_eq(charges_again, charges)
	restored.stop()
