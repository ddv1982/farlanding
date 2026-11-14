extends GutTest
## Each reusable objective class, run by a real Mission over the fixture world.

var _f: MissionFixture


func before_each() -> void:
	_f = MissionFixture.new(self)


func after_each() -> void:
	_f.dispose()


func _start(objective_def: ObjectiveDef, alert_meter: bool = false) -> Objective:
	var mission: Mission = _f.start([objective_def] as Array[ObjectiveDef], alert_meter)
	return mission.objective(objective_def.id)


func test_destroy_all_counts_every_enemy_but_custodians() -> void:
	var soldier: Unit = _f.spawn(_f.combat.soldier, 1, Vector3(0, 0, 0))
	var hq: Building = _f.world.spawn_building(_f.combat.hq, 1, Vector3(30, 0, 0), true)
	_f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(-30, 0, 0))
	var objective: Objective = _start(
		MissionFixture.objective(&"kill", ObjectiveDef.TYPE_DESTROY_ALL)
	)
	_f.tick(2)
	assert_true(objective.is_active())
	hq.health.take(10000.0, null)
	_f.tick(2)
	assert_true(objective.is_active(), "a unit is left")
	soldier.health.take(10000.0, null)
	_f.tick(2)
	assert_eq(objective.state, Objective.STATE_DONE, "the Warden does not count")


func test_destroy_all_leaves_out_unarmed_stragglers_once_the_base_is_gone() -> void:
	var hauler_def: UnitDef = _f.combat.soldier.duplicate() as UnitDef
	hauler_def.weapon = null
	_f.spawn(hauler_def, 1, Vector3(0, 0, 0))
	var hq: Building = _f.world.spawn_building(_f.combat.hq, 1, Vector3(30, 0, 0), true)
	var objective: Objective = _start(
		MissionFixture.objective(&"kill", ObjectiveDef.TYPE_DESTROY_ALL)
	)
	_f.tick(2)
	assert_true(objective.is_active(), "the base stands")
	hq.health.take(10000.0, null)
	_f.tick(2)
	assert_eq(objective.state, Objective.STATE_DONE, "an unarmed straggler does not count")


func test_destroy_all_with_types_only_counts_those() -> void:
	_f.spawn(_f.combat.soldier, 1, Vector3(0, 0, 0))
	var tank: Unit = _f.spawn(_f.combat.tank, 1, Vector3(10, 0, 0))
	var props: Dictionary = {"defs": [_f.combat.tank] as Array[EntityDef]}
	var objective: Objective = _start(
		MissionFixture.objective(&"tanks", ObjectiveDef.TYPE_DESTROY_ALL, &"primary", props)
	)
	_f.tick(1)
	assert_eq(objective.progress_text, "1 left")
	tank.health.take(10000.0, null)
	_f.tick(2)
	assert_eq(objective.state, Objective.STATE_DONE)


func test_keep_alive_fails_with_the_last_guarded_thing() -> void:
	var lander: Building = _f.world.spawn_building(_f.combat.hq, 0, Vector3.ZERO, true)
	var props: Dictionary = {
		"side": ObjectiveDef.SIDE_PLAYER, "defs": [_f.combat.hq] as Array[EntityDef]
	}
	var objective: Objective = _start(
		MissionFixture.objective(&"keep", ObjectiveDef.TYPE_KEEP_ALIVE, &"primary", props)
	)
	assert_true(objective.passive)
	_f.tick(3)
	assert_true(objective.is_active())
	lander.health.take(10000.0, null)
	_f.tick(1)
	assert_eq(objective.state, Objective.STATE_FAILED)


func test_keep_alive_require_all_fails_on_any_loss() -> void:
	var a: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 0))
	_f.spawn(_f.combat.soldier, 0, Vector3(5, 0, 0))
	var props: Dictionary = {"side": ObjectiveDef.SIDE_PLAYER, "require_all": true}
	var objective: Objective = _start(
		MissionFixture.objective(&"all", ObjectiveDef.TYPE_KEEP_ALIVE, &"secondary", props)
	)
	_f.tick(1)
	assert_eq(objective.progress_text, "2 / 2 intact")
	a.health.take(10000.0, null)
	_f.tick(1)
	assert_eq(objective.state, Objective.STATE_FAILED)


func test_reach_area_needs_the_amount_inside() -> void:
	var unit: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 0))
	var props: Dictionary = {
		"side": ObjectiveDef.SIDE_PLAYER, "area_center": Vector3(0, 0, -20), "area_radius": 5.0
	}
	var objective: Objective = _start(
		MissionFixture.objective(&"go", ObjectiveDef.TYPE_REACH_AREA, &"primary", props)
	)
	assert_true(objective.has_area)
	_f.tick(1)
	assert_eq(objective.progress_text, "0 / 1 in the area")
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit] as Array[Node3D], Vector3(0, 0, -20)))
	_f.tick(60)
	assert_eq(objective.state, Objective.STATE_DONE)


func test_reach_area_require_all_and_failing_when_nobody_is_left() -> void:
	var a: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, -20))
	var b: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(20, 0, 0))
	var props: Dictionary = {
		"side": ObjectiveDef.SIDE_PLAYER,
		"require_all": true,
		"area_center": Vector3(0, 0, -20),
		"area_radius": 5.0
	}
	var objective: Objective = _start(
		MissionFixture.objective(&"out", ObjectiveDef.TYPE_REACH_AREA, &"primary", props)
	)
	_f.tick(1)
	assert_true(objective.is_active(), "one of two is in")
	b.health.take(10000.0, null)
	_f.tick(1)
	assert_eq(objective.state, Objective.STATE_DONE, "every survivor is in")
	# And a fresh one with nobody left fails.
	a.health.take(10000.0, null)
	var later: Objective = _f.mission.add_objective_def(
		MissionFixture.objective(&"out2", ObjectiveDef.TYPE_REACH_AREA, &"primary", props)
	)
	assert_eq(later.state, Objective.STATE_FAILED)


func test_gather_intel_counts_the_bank() -> void:
	var props: Dictionary = {"amount": 100}
	var objective: Objective = _start(
		MissionFixture.objective(&"intel", ObjectiveDef.TYPE_GATHER_INTEL, &"primary", props)
	)
	_f.world.economy.add_intel(0, 60)
	_f.tick(1)
	assert_eq(objective.progress_text, "60 / 100 Intel banked")
	_f.world.economy.spend_intel(0, 30)
	_f.world.economy.add_intel(0, 60)
	_f.tick(1)
	assert_true(objective.is_active(), "spent Intel is not banked")
	_f.world.economy.add_intel(0, 20)
	_f.tick(1)
	assert_eq(objective.state, Objective.STATE_DONE)


func test_a_deadline_fails_an_open_objective() -> void:
	var props: Dictionary = {"amount": 100, "deadline_seconds": 3.0}
	var objective: Objective = _start(
		MissionFixture.objective(&"intel", ObjectiveDef.TYPE_GATHER_INTEL, &"primary", props)
	)
	assert_almost_eq(objective.seconds_left(_f.mission.now()), 3.0, 0.01)
	_f.tick(29)
	assert_true(objective.is_active())
	_f.tick(2)
	assert_eq(objective.state, Objective.STATE_FAILED)


func test_survive_is_done_when_the_time_is_up() -> void:
	var props: Dictionary = {"seconds": 2.0}
	var objective: Objective = _start(
		MissionFixture.objective(&"hold", ObjectiveDef.TYPE_SURVIVE, &"primary", props)
	)
	assert_false(objective.countdown_fails)
	_f.tick(19)
	assert_true(objective.is_active())
	_f.tick(2)
	assert_eq(objective.state, Objective.STATE_DONE)


func test_stay_undetected_fails_when_the_enemy_is_alerted() -> void:
	var objective: Objective = _start(
		MissionFixture.objective(&"quiet", ObjectiveDef.TYPE_STAY_UNDETECTED, &"secondary"), true
	)
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	var shooter: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 40))
	_f.tick(5)
	assert_true(objective.is_active())
	_f.world.combat.damage(guard, 1.0, &"light", shooter)
	_f.tick(1)
	assert_eq(objective.state, Objective.STATE_FAILED)


func test_scan_sites_needs_every_listed_site() -> void:
	var a: DiscoveryDef = _f.discovery.discovery(&"a")
	var b: DiscoveryDef = _f.discovery.discovery(&"b")
	var site_a: DiscoverySite = _f.discovery.site(a, Vector3(10, 0, 0))
	var site_b: DiscoverySite = _f.discovery.site(b, Vector3(-10, 0, 0))
	var props: Dictionary = {"site_ids": [&"a", &"b"] as Array[StringName]}
	var objective: Objective = _start(
		MissionFixture.objective(&"scan", ObjectiveDef.TYPE_SCAN_SITES, &"secondary", props)
	)
	_f.world.discovery.resolve(site_a, 0)
	_f.tick(1)
	assert_eq(objective.progress_text, "1 / 2 scanned")
	_f.world.discovery.resolve(site_b, 1)
	_f.tick(1)
	assert_true(objective.is_active(), "another faction's scan does not count")


func test_sabotage_is_done_when_the_target_is_sabotaged() -> void:
	var uplink: Building = _f.world.spawn_building(_f.target, 1, Vector3(0, 0, -20), true)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, -12))
	var props: Dictionary = {"defs": [_f.target] as Array[EntityDef]}
	var objective: Objective = _start(
		MissionFixture.objective(&"sab", ObjectiveDef.TYPE_SABOTAGE, &"primary", props)
	)
	_f.tick(2)
	_f.push(SabotageCommand.new(0, [wisp] as Array[Node3D], uplink))
	_f.tick(30)
	assert_true(wisp.is_sabotaging, "working at the uplink")
	assert_true(objective.is_active())
	_f.tick(40)
	assert_true(uplink.is_sabotaged)
	assert_false(uplink.is_operational())
	assert_eq(objective.state, Objective.STATE_DONE)


func test_sabotage_fails_without_saboteurs() -> void:
	_f.world.spawn_building(_f.target, 1, Vector3(0, 0, -20), true)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, 0))
	var props: Dictionary = {"defs": [_f.target] as Array[EntityDef]}
	var objective: Objective = _start(
		MissionFixture.objective(&"sab", ObjectiveDef.TYPE_SABOTAGE, &"primary", props)
	)
	wisp.health.take(10000.0, null)
	_f.tick(1)
	assert_eq(objective.state, Objective.STATE_FAILED)


func test_destroy_count_counts_deaths() -> void:
	var warden_a: Unit = _f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(0, 0, 0))
	var props: Dictionary = {
		"side": ObjectiveDef.SIDE_CUSTODIAN, "defs": [_f.discovery.warden] as Array[EntityDef]
	}
	var objective: Objective = _start(
		MissionFixture.objective(&"warden", ObjectiveDef.TYPE_DESTROY_COUNT, &"secondary", props)
	)
	_f.spawn(_f.combat.soldier, 1, Vector3(10, 0, 0)).health.take(10000.0, null)
	assert_true(objective.is_active())
	warden_a.health.take(10000.0, null)
	assert_eq(objective.state, Objective.STATE_DONE)


func test_destroy_count_keeps_its_count_through_a_save() -> void:
	var saved: DestroyCountObjective = DestroyCountObjective.new()
	saved.destroyed = 2
	var copy: DestroyCountObjective = DestroyCountObjective.new()
	copy.from_dict(saved.to_dict())
	assert_eq(copy.destroyed, 2)


func test_factory_makes_every_type() -> void:
	for type: StringName in [
		ObjectiveDef.TYPE_DESTROY_ALL,
		ObjectiveDef.TYPE_DESTROY_COUNT,
		ObjectiveDef.TYPE_KEEP_ALIVE,
		ObjectiveDef.TYPE_REACH_AREA,
		ObjectiveDef.TYPE_GATHER_INTEL,
		ObjectiveDef.TYPE_SURVIVE,
		ObjectiveDef.TYPE_STAY_UNDETECTED,
		ObjectiveDef.TYPE_SCAN_SITES,
		ObjectiveDef.TYPE_SABOTAGE,
	]:
		var made: Objective = ObjectiveFactory.create(MissionFixture.objective(&"x", type))
		assert_not_null(made, String(type))


func test_objective_state_saves_and_loads() -> void:
	var objective: Objective = _start(
		MissionFixture.objective(&"hold", ObjectiveDef.TYPE_SURVIVE, &"primary", {"seconds": 5.0})
	)
	objective.set_progress("half way")
	var copy: Objective = SurviveObjective.new()
	copy.from_dict(objective.to_dict())
	assert_eq(copy.progress_text, "half way")
	assert_eq(copy.countdown_tick, objective.countdown_tick)
	assert_eq(copy.state, Objective.STATE_ACTIVE)
