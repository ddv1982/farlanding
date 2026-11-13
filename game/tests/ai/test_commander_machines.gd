extends GutTest
## The enemy commander plays Hollow Meridian's engines by the player's rule (ADR 0017)
## through its MachineKeeper: an idle builder goes to reactivate the nearest engine it
## has explored with an escort, larger when it has seen Custodians by it; it skips
## engines guarded beyond what its free army can take; it takes over the player's
## engines; and it sends defenders to an engine of its own under attack. It knows only
## what its faction has seen and acts only through Commands.

const HOME: Vector3 = Vector3(-60, 0, -60)

var _f: MissionFixture
var _rule: MachineryRule
var _engine_def: BuildingDef
var _profile: CommanderProfile
var _port: WorldAiPort
var _keeper: MachineKeeper


func before_each() -> void:
	_f = MissionFixture.new(self)
	_rule = MachineryRule.new()
	_rule.system = MachinerySystem
	_rule.reactivate_seconds = 3.0
	_rule.takeover_seconds = 6.0
	_rule.disturb_radius = 20.0
	_engine_def = BuildingDef.new()
	_engine_def.id = &"engine"
	_engine_def.footprint = Rect2(-3, -3, 6, 6)
	_engine_def.max_health = 200
	_engine_def.power_output = 15
	_engine_def.vision_range = 10.0
	_engine_def.machine = true
	_profile = CommanderProfile.new()
	_profile.machines_wanted = 2
	_profile.machine_escort = 2
	_profile.machine_defenders = 2
	_profile.machine_takeover = true
	_port = WorldAiPort.new(_f.base.context, _f.world, 1)
	_keeper = MachineKeeper.new(_port, _f.world, _profile)
	_f.world.spawn_building(_f.combat.hq, 1, HOME, true)


func after_each() -> void:
	_f.dispose()


func _seconds(seconds: float) -> void:
	_f.tick(roundi(seconds * SimClock.TICK_RATE))


func _engine(at: Vector3) -> Building:
	return _f.world.spawn_building(_engine_def, Factions.CUSTODIANS, at, true)


func _start() -> MachinerySystem:
	return PlanetRuleSystem.start(_f.world, _rule) as MachinerySystem


## Lets faction 1 see (and so explore) around `at`.
func _explore(at: Vector3) -> void:
	_f.world.vision.reveal_area(1, at, 30.0, 30)
	_f.tick(4)


func _builder(at: Vector3) -> Unit:
	return _f.spawn(_f.base.fabricator, 1, at)


func test_nothing_happens_without_the_rule_or_when_it_wants_no_engines() -> void:
	_engine(Vector3(-40, 0, -40))
	var builder: Unit = _builder(HOME + Vector3(8, 0, 0))
	assert_eq(_keeper.decide(HOME, [builder], []), [] as Array[Unit])
	_start()
	_profile.machines_wanted = 0
	_explore(Vector3(-40, 0, -40))
	assert_eq(_keeper.decide(HOME, [builder], []), [] as Array[Unit])
	assert_eq(_port.commands_pushed, 0)


func test_it_reactivates_the_nearest_engine_it_has_explored() -> void:
	var near: Building = _engine(Vector3(-40, 0, -40))
	var unexplored: Building = _engine(Vector3(-10, 0, -85))
	var machinery: MachinerySystem = _start()
	var builder: Unit = _builder(HOME + Vector3(8, 0, 8))
	_explore(Vector3(-40, 0, -40))
	assert_false(_f.world.vision.grid.is_explored(1, unexplored.position), "never seen")
	var used: Array[Unit] = _keeper.decide(HOME, [builder], [])
	assert_eq(used, [builder] as Array[Unit])
	_f.tick()
	assert_eq(builder.reactivator.target, near, "the one it knows of")
	_seconds(8.0)
	assert_eq(machinery.held_by(1), [near] as Array[Building], "it runs for the Combine")
	assert_eq(_f.world.economy.stockpile(1).power_produced, 20, "the hub's 10 halved, and 15")


func test_one_claim_at_a_time() -> void:
	_engine(Vector3(-40, 0, -40))
	_engine(Vector3(-40, 0, -70))
	_start()
	var first: Unit = _builder(HOME + Vector3(8, 0, 8))
	var second: Unit = _builder(HOME + Vector3(-8, 0, 8))
	_explore(Vector3(-40, 0, -55))
	assert_eq(_keeper.decide(HOME, [first, second], []).size(), 1)
	_f.tick(2)
	assert_eq(_keeper.decide(HOME, [second], []).size(), 0, "the first claim runs")


func test_it_escorts_a_builder_to_a_guarded_engine_and_skips_a_fortress() -> void:
	var guarded: Building = _engine(Vector3(-40, 0, -40))
	var fortress: Building = _engine(Vector3(-70, 0, -20))
	_start()
	# Strength is what a unit is worth: give the fixture's types their price.
	_f.discovery.warden.cost_alloy = 400
	_f.combat.tank.cost_alloy = 250
	_f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(-40, 0, -48))
	for i: int in 6:
		_f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(-76 + i * 2, 0, -12))
	var builder: Unit = _builder(HOME + Vector3(8, 0, 8))
	var escort: Array[Unit] = [
		_f.spawn(_f.combat.tank, 1, HOME + Vector3(0, 0, 12)),
		_f.spawn(_f.combat.tank, 1, HOME + Vector3(4, 0, 12)),
	]
	_explore(Vector3(-55, 0, -30))
	_keeper.decide(HOME, [], [])
	var seen: float = _keeper.guards_seen.get(fortress.entity_id, 0.0)
	assert_gt(seen, 0.0, "it saw the guards")
	var used: Array[Unit] = _keeper.decide(HOME, [builder], escort.duplicate())
	_f.tick()
	assert_eq(builder.reactivator.target, guarded, "not the heavily guarded one")
	assert_true(used.has(escort[0]) and used.has(escort[1]), "an escort goes along")
	assert_false(escort[0].orders.is_idle(), "on its way")


func test_it_takes_over_the_players_engine() -> void:
	var engine: Building = _engine(Vector3(-40, 0, -40))
	var machinery: MachinerySystem = _start()
	engine.faction = 0
	engine.machine.set_state(Machine.RUNNING)
	var builder: Unit = _builder(HOME + Vector3(8, 0, 8))
	_explore(Vector3(-40, 0, -40))
	_keeper.decide(HOME, [builder], [])
	_f.tick()
	assert_eq(builder.reactivator.target, engine)
	_seconds(14.0)
	assert_eq(engine.faction, 1, "taken over")
	assert_eq(machinery.held_by(0).size(), 0)
	_profile.machine_takeover = false
	var other: Building = _engine(Vector3(-30, 0, -60))
	other.faction = 0
	other.machine.set_state(Machine.RUNNING)
	_explore(Vector3(-30, 0, -60))
	var spare: Unit = _builder(HOME + Vector3(-8, 0, 8))
	assert_eq(_keeper.decide(HOME, [spare], []), [] as Array[Unit], "not when told not to")


func test_it_defends_an_engine_of_its_own_under_attack() -> void:
	var engine: Building = _engine(Vector3(-30, 0, -30))
	_start()
	engine.faction = 1
	engine.machine.set_state(Machine.RUNNING)
	var guards: Array[Unit] = [
		_f.spawn(_f.combat.soldier, 1, HOME + Vector3(0, 0, 10)),
		_f.spawn(_f.combat.soldier, 1, HOME + Vector3(3, 0, 10)),
		_f.spawn(_f.combat.soldier, 1, HOME + Vector3(6, 0, 10)),
	]
	_f.tick()
	assert_eq(_keeper.decide(HOME, [], guards.duplicate()).size(), 0, "nothing to defend")
	engine.health.take(60.0, null)
	var sent: Array[Unit] = _keeper.decide(HOME, [], guards.duplicate())
	assert_eq(sent.size(), 2, "machine_defenders of them")
	_f.tick()
	assert_false(sent[0].orders.is_idle())
	assert_eq(_keeper.decide(HOME, [], guards.duplicate()).size(), 0, "not again at once")


func test_its_claim_saves_and_loads() -> void:
	var engine: Building = _engine(Vector3(-40, 0, -40))
	_start()
	var builder: Unit = _builder(HOME + Vector3(8, 0, 8))
	_explore(Vector3(-40, 0, -40))
	_keeper.decide(HOME, [builder], [])
	var saved: Dictionary = _keeper.to_dict()
	var restored: MachineKeeper = MachineKeeper.new(_port, _f.world, _profile)
	restored.from_dict(saved)
	assert_eq(restored.claim_engine, engine.entity_id)
	assert_eq(restored.claim_worker, builder.entity_id)
	assert_eq(restored.to_dict(), saved)
