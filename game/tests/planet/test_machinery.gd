extends GutTest
## Hollow Meridian's planet rule (ADR 0017): power from old machinery. Engines stand
## dormant; a unit that can build or scan reactivates one by working beside it (the work
## stops with the order and fades), it then powers that faction; another faction takes a
## running engine over the same way; an engine whose health runs out shuts down for a
## while (no power, nothing targets it, the enemy may claim it) and restarts at full
## health, never destroyed. Starting work wakes the dormant Custodians around it and
## they go for the worker, but never shoot an engine. Reactors are locked and other
## buildings give part of their power. Perks speed the work, sturdy the engines and quiet
## the approach. The engines' state saves and loads.

const HOLLOW: String = "res://data/planets/hollow_meridian.tres"
const ENGINE_AT: Vector3 = Vector3(0, 0, 0)

var _f: MissionFixture
var _rule: MachineryRule
var _engine_def: BuildingDef
var _reactivated: Array[Array] = []
var _lost: Array[Array] = []
var _alerts: Array[StringName] = []


func before_each() -> void:
	_f = MissionFixture.new(self)
	_rule = MachineryRule.new()
	_rule.id = &"test_machinery"
	_rule.system = MachinerySystem
	_rule.reactivate_seconds = 4.0
	_rule.takeover_seconds = 8.0
	_rule.progress_decay = 0.1
	_rule.work_range = 3.0
	_rule.shutdown_seconds = 5.0
	_rule.disturb_radius = 20.0
	_rule.chase_distance = 30.0
	_rule.alert_seconds = 0.0
	_engine_def = BuildingDef.new()
	_engine_def.id = &"engine"
	_engine_def.display_name = "Engine"
	_engine_def.footprint = Rect2(-3, -3, 6, 6)
	_engine_def.max_health = 200
	_engine_def.power_output = 15
	_engine_def.vision_range = 10.0
	_engine_def.placeable = false
	_engine_def.machine = true
	_reactivated.clear()
	_lost.clear()
	_alerts.clear()
	Events.machine_reactivated.connect(_on_reactivated)
	Events.machine_lost.connect(_on_lost)
	Events.advisor_alert.connect(_on_alert)


func after_each() -> void:
	Events.machine_reactivated.disconnect(_on_reactivated)
	Events.machine_lost.disconnect(_on_lost)
	Events.advisor_alert.disconnect(_on_alert)
	_f.dispose()


func _on_reactivated(machine: Node3D, faction: int) -> void:
	_reactivated.append([machine, faction])


func _on_lost(machine: Node3D, faction: int) -> void:
	_lost.append([machine, faction])


func _on_alert(kind: StringName) -> void:
	_alerts.append(kind)


func _start() -> MachinerySystem:
	return PlanetRuleSystem.start(_f.world, _rule) as MachinerySystem


func _seconds(seconds: float) -> void:
	_f.tick(roundi(seconds * SimClock.TICK_RATE))


func _engine(at: Vector3 = ENGINE_AT) -> Building:
	return _f.world.spawn_building(_engine_def, Factions.CUSTODIANS, at, true)


func _worker(faction: int, at: Vector3) -> Unit:
	return _f.spawn(_f.discovery.surveyor, faction, at)


func _reactivate(worker: Unit, engine: Building) -> void:
	_f.push(ReactivateCommand.new(worker.faction, [worker] as Array[Node3D], engine))


## `engine` runs for `faction` at once (as if reactivated earlier).
func _run_for(engine: Building, faction: int) -> void:
	engine.faction = faction
	engine.machine.set_state(Machine.RUNNING)


func test_hollow_meridian_plays_the_machinery_rule() -> void:
	var planet: PlanetDef = load(HOLLOW)
	var rule: MachineryRule = planet.rule as MachineryRule
	assert_eq(planet.id, &"hollow_meridian")
	assert_not_null(rule, "Hollow Meridian plays a MachineryRule")
	assert_eq(rule.system, MachinerySystem)
	assert_true(rule.locked_buildings.has(&"concord_reactor"), "no Reactors")
	assert_gt(rule.takeover_seconds, rule.reactivate_seconds, "a takeover is the slower job")
	assert_gt(rule.disturb_radius, 0.0, "waking an engine stirs the guardians")
	var engine: BuildingDef = load("res://data/buildings/antecedent_engine.tres")
	assert_true(engine.machine)
	assert_false(engine.placeable)
	assert_gt(engine.power_output, 0)
	assert_eq(engine.faction, Factions.CUSTODIANS)


func test_reactors_are_locked_and_headquarters_give_half() -> void:
	_rule.headquarters_power_scale = 0.5
	_f.world.spawn_building(_f.combat.hq, 0, Vector3(-40, 0, -40), true)
	var machinery: MachinerySystem = _start()
	assert_not_null(machinery)
	assert_true(FactionPerks.of(_f.world.perks, 0).is_locked(&"concord_reactor"))
	_f.tick()
	assert_eq(_f.world.economy.stockpile(0).power_produced, 5, "the HQ's 10 halved")
	var engine: Building = _engine()
	_run_for(engine, 0)
	_f.tick()
	assert_eq(_f.world.economy.stockpile(0).power_produced, 20, "an engine gives all of it")


func test_a_dormant_engine_gives_nothing_and_cannot_be_shot() -> void:
	var engine: Building = _engine()
	_start()
	_f.spawn(_f.combat.soldier, 0, Vector3(6, 0, 0))
	_f.tick(5)
	assert_true(engine.is_inert)
	assert_false(engine.is_operational())
	assert_false(_f.world.combat.can_target(0, engine), "nothing to shoot")
	assert_true(Combat.is_dormant(engine))
	assert_null(_f.world.combat.find_target(0, Vector3(6, 0, 0), 20.0))
	assert_eq(_f.world.economy.stockpile(Factions.CUSTODIANS).power_produced, 0)


func test_a_surveyor_reactivates_an_engine_and_it_powers_its_faction() -> void:
	var engine: Building = _engine()
	var machinery: MachinerySystem = _start()
	var worker: Unit = _worker(0, Vector3(12, 0, 0))
	_f.tick(4)
	assert_true(Reactivator.can_reactivate(engine, 0))
	_reactivate(worker, engine)
	_seconds(2.0)
	assert_true(worker.is_reactivating, "at work beside it")
	assert_gt(engine.machine.progress, 0.0)
	assert_eq(engine.machine.claimant, 0)
	_seconds(4.0)
	assert_eq(engine.faction, 0, "it runs for us")
	assert_true(engine.machine.is_running())
	assert_true(engine.is_operational())
	assert_eq(machinery.held_by(0), [engine] as Array[Building])
	assert_eq(_reactivated, [[engine, 0]])
	assert_true(_alerts.has(&"engine_online"))
	_f.tick()
	assert_eq(_f.world.economy.stockpile(0).power_produced, 15)
	assert_true(worker.orders.is_idle(), "the job is done")
	assert_false(Reactivator.can_reactivate(engine, 0), "nothing more to do on it")
	assert_eq(machinery.indicator_title(), "ENGINES")
	assert_eq(machinery.indicator_text(0), "1 / 1 HELD")


func test_the_work_stops_with_the_order_and_fades() -> void:
	var engine: Building = _engine()
	_start()
	var worker: Unit = _worker(0, Vector3(8, 0, 0))
	_f.tick(4)
	_reactivate(worker, engine)
	_seconds(2.5)
	var made: float = engine.machine.progress
	assert_gt(made, 0.2)
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [worker] as Array[Node3D], Vector3(30, 0, 0)))
	_seconds(1.0)
	assert_false(worker.is_reactivating, "interrupted")
	assert_lt(engine.machine.progress, made, "the progress fades")
	_seconds(10.0)
	assert_eq(engine.machine.progress, 0.0)
	assert_eq(engine.machine.claimant, -1)
	assert_true(engine.machine.is_dormant(), "still dormant")


func test_an_enemy_takes_a_running_engine_over() -> void:
	var engine: Building = _engine()
	var machinery: MachinerySystem = _start()
	_run_for(engine, 0)
	var rival: Unit = _f.spawn(_f.base.fabricator, 1, Vector3(8, 0, 0))
	_f.tick(4)
	assert_true(Reactivator.can_reactivate(engine, 1), "the Combine may take it")
	assert_true(machinery.can_claim(engine, 1))
	_reactivate(rival, engine)
	_seconds(5.0)
	assert_eq(engine.faction, 0, "a takeover is slower than a reactivation")
	assert_eq(engine.machine.claimant, 1)
	assert_true(machinery.indicator_alarm(), "the player sees it contested")
	_seconds(5.0)
	assert_eq(engine.faction, 1, "it runs for them now")
	assert_true(engine.machine.is_running())
	assert_eq(_lost, [[engine, 0]])
	assert_eq(_reactivated, [[engine, 1]])
	assert_true(_alerts.has(&"engine_lost"))
	assert_eq(machinery.held_by(0).size(), 0)


func test_our_work_drains_their_progress_first() -> void:
	var engine: Building = _engine()
	_start()
	var rival: Unit = _f.spawn(_f.base.fabricator, 1, Vector3(8, 0, 0))
	var worker: Unit = _worker(0, Vector3(-8, 0, 0))
	_f.tick(4)
	_reactivate(rival, engine)
	_seconds(2.5)
	assert_eq(engine.machine.claimant, 1)
	_f.push(StopCommand.new(1, [rival] as Array[Node3D]))
	_reactivate(worker, engine)
	_seconds(1.5)
	assert_eq(engine.machine.claimant, 1, "draining theirs")
	_seconds(3.0)
	assert_eq(engine.machine.claimant, 0, "then building ours")


func test_an_emptied_engine_shuts_down_and_restarts_for_its_owner() -> void:
	var engine: Building = _engine()
	var machinery: MachinerySystem = _start()
	_run_for(engine, 0)
	_f.tick()
	engine.health.take(1000.0, null)
	assert_false(engine.health.is_dead(), "never destroyed")
	assert_true(Combat.is_alive(engine))
	_f.tick()
	assert_true(engine.machine.is_shut_down())
	assert_true(engine.is_inert)
	assert_eq(_lost, [[engine, 0]])
	assert_false(_f.world.combat.can_target(1, engine), "nothing to shoot any more")
	assert_eq(_f.world.combat.damage(engine, 50.0, &"light", null), 0.0)
	assert_eq(machinery.held_by(0).size(), 0, "no power while shut down")
	assert_false(machinery.can_claim(engine, 0), "its owner waits for the restart")
	_f.tick()
	assert_eq(_f.world.economy.stockpile(0).power_produced, 0)
	_seconds(5.5)
	assert_true(engine.machine.is_running(), "restarted")
	assert_eq(engine.faction, 0)
	assert_eq(engine.health.fraction(), 1.0, "at full health")
	assert_eq(_reactivated, [[engine, 0]])
	_f.tick()
	assert_eq(_f.world.economy.stockpile(0).power_produced, 15)


func test_the_enemy_may_claim_an_engine_it_shut_down() -> void:
	var engine: Building = _engine()
	var machinery: MachinerySystem = _start()
	_run_for(engine, 0)
	engine.health.take(1000.0, null)
	_f.tick()
	assert_true(engine.machine.is_shut_down())
	assert_true(machinery.can_claim(engine, 1))
	var rival: Unit = _f.spawn(_f.base.fabricator, 1, Vector3(8, 0, 0))
	_f.tick(4)
	_reactivate(rival, engine)
	_seconds(4.6)
	assert_eq(engine.faction, 1, "claimed at the reactivation pace before it restarted")
	assert_true(engine.machine.is_running())
	assert_eq(_lost, [[engine, 0]], "lost once, when it shut down")


func test_waking_an_engine_wakes_its_guardians_and_they_go_for_the_worker() -> void:
	var engine: Building = _engine()
	_start()
	var near: Unit = _f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(-15, 0, 0))
	var far: Unit = _f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(-60, 0, 0))
	var worker: Unit = _worker(0, Vector3(8, 0, 0))
	_f.tick(4)
	assert_true(near.is_dormant)
	_reactivate(worker, engine)
	_seconds(1.5)
	assert_false(near.is_dormant, "the guardian within the radius woke")
	assert_true(far.is_dormant, "the one far off did not")
	assert_eq(near.orders.attack_target(), worker, "and it goes for whoever woke it")
	assert_true(_alerts.has(&"custodians_awake"))


func test_custodians_never_shoot_an_engine() -> void:
	var engine: Building = _engine()
	_start()
	_run_for(engine, 0)
	var warden: Unit = _f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(6, 0, 0))
	warden.dormancy.wake()
	_f.tick(5)
	assert_true(_f.world.combat.can_target(Factions.CUSTODIANS, engine), "it could")
	var picked: Node3D = _f.world.combat.find_target(
		Factions.CUSTODIANS, warden.sim_position(), 20.0
	)
	assert_null(picked, "but it guards the machines")


func test_perks_speed_the_work_sturdy_the_engine_and_quiet_the_approach() -> void:
	var perks: FactionPerks = FactionPerks.new()
	perks.add_scale(&"", FactionPerks.REACTIVATION_RATE, 2.0)
	perks.add_scale(&"engine", FactionPerks.MAX_HEALTH, 1.5)
	perks.add_scale(&"", FactionPerks.CUSTODIAN_DISTURB, 0.5)
	_f.world.perks[0] = perks
	var engine: Building = _engine()
	_start()
	var guard: Unit = _f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(-15, 0, 0))
	var worker: Unit = _worker(0, Vector3(8, 0, 0))
	_f.tick(4)
	_reactivate(worker, engine)
	_seconds(3.0)
	assert_eq(engine.faction, 0, "done in half the time")
	assert_true(guard.is_dormant, "15 m is beyond the halved 20 m radius")
	assert_eq(engine.health.max_health, 300.0, "half as much again before it shuts down")
	var walker: Unit = _worker(0, Vector3(-60, 0, 0))
	_f.push(
		MoveCommand.new(MoveCommand.KIND_MOVE, 0, [walker] as Array[Node3D], Vector3(-19, 0, 0))
	)
	_seconds(10.0)
	assert_true(guard.is_dormant, "a quiet tread: 4 m off a 6 m wake radius halved")


func test_the_engines_state_saves_and_loads() -> void:
	var engine: Building = _engine()
	var machinery: MachinerySystem = _start()
	_run_for(engine, 0)
	engine.health.take(1000.0, null)
	_f.tick()
	_seconds(2.0)
	var rival: Unit = _f.spawn(_f.base.fabricator, 1, Vector3(8, 0, 0))
	_f.tick(4)
	_reactivate(rival, engine)
	_seconds(1.0)
	var saved: Dictionary = engine.to_dict()
	var machine_data: Dictionary = saved["machine"]
	var state: String = machine_data["state"]
	var claimant: int = machine_data["claimant"]
	var progress: float = machine_data["progress"]
	var shutdown_left: float = machine_data["shutdown_left"]
	var owner: int = saved["faction"]
	assert_eq(state, "shut_down")
	assert_eq(claimant, 1)
	assert_gt(progress, 0.0)
	assert_almost_eq(shutdown_left, 1.6, 0.15)
	var system_data: Dictionary = machinery.to_dict()
	var copy: Building = _f.world.spawn_building(_engine_def, owner, Vector3(40, 0, 40), false)
	copy.from_dict(saved)
	assert_true(copy.machine.is_shut_down())
	assert_eq(copy.machine.claimant, 1)
	assert_almost_eq(copy.machine.progress, engine.machine.progress, 0.0001)
	assert_almost_eq(copy.machine.shutdown_left, engine.machine.shutdown_left, 0.0001)
	assert_eq(copy.faction, 0)
	assert_eq(copy.health.current, 0.0)
	assert_false(copy.health.is_dead(), "an emptied engine is not dead after a load")
	var restored: MachinerySystem = MachinerySystem.new()
	restored.setup(_f.world, _rule)
	restored.from_dict(system_data)
	assert_eq(restored.to_dict(), system_data)


func test_draining_their_progress_does_not_hand_it_to_us() -> void:
	var engine: Building = _engine()
	_start()
	var worker: Unit = _worker(0, Vector3(-8, 0, 0))
	_f.tick(4)
	engine.machine.set_progress(0.6, 1)
	_reactivate(worker, engine)
	var ticks: int = 0
	while engine.machine.claimant != 0 and ticks < 600:
		_f.tick(1)
		ticks += 1
	assert_eq(engine.machine.claimant, 0, "their work is used up")
	assert_lt(engine.machine.progress, 0.1, "and ours starts from nothing")


func test_an_engine_cannot_be_sabotaged() -> void:
	var engine: Building = _engine()
	_start()
	_run_for(engine, 1)
	_f.tick(2)
	assert_false(Saboteur.can_sabotage(engine, 0), "it would stay dead for whoever took it")
