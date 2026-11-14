extends GutTest
## Hollow Meridian through a save (ADR 0013, ADR 0017). Power Up: an engine running for
## the player, one the Combine runs shut down mid-timer, and one a Fabricator is half-way
## through reactivating all come back as they were; save -> load -> save gives the same
## save, the work goes on to the end and the timer runs out on time. The finale: the
## Core's charge, the Custodian stage that woke and its converging group come back, and
## the Core's charge is announced again.

var _f: SaveFixture
var _maps: Array[LandingMap] = []
var _charges: Array[float] = []


func before_each() -> void:
	_f = SaveFixture.new(self)
	_maps.clear()
	_charges.clear()
	Events.core_charge_changed.connect(_on_charge)


func after_each() -> void:
	Events.core_charge_changed.disconnect(_on_charge)
	for map: LandingMap in _maps:
		_f.dispose(map)


func _on_charge(fraction: float) -> void:
	_charges.append(fraction)


func test_engines_running_shut_down_and_half_woken_round_trip() -> void:
	var def: MissionDef = SaveFixture.mission(&"hollow_power")
	var map: LandingMap = await _land(def)
	var world: SimWorld = map.world
	var machinery: MachinerySystem = world.planet as MachinerySystem
	var ours: Building = _engine_at(machinery, Vector3(-52, 0, 70))
	var theirs: Building = _engine_at(machinery, Vector3(52, 0, -70))
	var waking: Building = _engine_at(machinery, Vector3(-96, 0, 48))
	ours.faction = 0
	ours.machine.set_state(Machine.RUNNING)
	theirs.faction = 1
	theirs.machine.set_state(Machine.RUNNING)
	theirs.health.take(100000.0, null)
	# Clear the guardians by the engine being woken: this test is about the save.
	for unit: Unit in world.units_of(Factions.CUSTODIANS):
		if unit.sim_position().distance_to(waking.position) < 40.0:
			unit.health.take(100000.0, null)
	var fabricator: Unit = SaveFixture.unit_of(world, 0, &"concord_fabricator")
	SaveFixture.teleport(fabricator, waking.position + Vector3(9, 0, 0))
	await _f.run(map, 5)
	map.context.command_queue.push(ReactivateCommand.new(0, [fabricator] as Array[Node3D], waking))
	var working: bool = await _f.run_until(
		map, func() -> bool: return waking.machine.progress > 0.3, 200
	)
	assert_true(working, "half-way through")
	assert_true(theirs.machine.is_shut_down())
	var snapshot: Dictionary = map.snapshot()
	var ids: Array[int] = [ours.entity_id, theirs.entity_id, waking.entity_id]
	var states: Array[Dictionary] = [
		ours.machine.to_dict(), theirs.machine.to_dict(), waking.machine.to_dict()
	]
	var fabricator_id: int = fabricator.entity_id
	var left: float = theirs.machine.shutdown_left
	_f.dispose(map)
	var loaded: LandingMap = await _land(def, snapshot)
	world = loaded.world
	machinery = world.planet as MachinerySystem
	assert_not_null(machinery, "the rule is back")
	assert_eq(machinery.engines().size(), 8)
	for i: int in ids.size():
		var engine: Building = world.entity(ids[i]) as Building
		assert_not_null(engine)
		assert_eq(engine.machine.to_dict(), states[i], "engine %d as it was" % i)
	ours = world.entity(ids[0]) as Building
	theirs = world.entity(ids[1]) as Building
	waking = world.entity(ids[2]) as Building
	assert_eq(ours.faction, 0)
	assert_true(ours.is_operational(), "it powers us again")
	assert_eq(theirs.faction, 1)
	assert_false(theirs.health.is_dead(), "emptied, not dead")
	assert_eq(machinery.held_by(0), [ours] as Array[Building])
	var resaved: Dictionary = loaded.snapshot()
	var differences: Array[String] = SaveFixture.differences(
		SaveFixture.normalised(snapshot), SaveFixture.normalised(resaved)
	)
	assert_eq(differences, [] as Array[String], "save, load, save gives the same save")
	fabricator = world.entity(fabricator_id) as Unit
	var done: bool = await _f.run_until(
		loaded, func() -> bool: return waking.machine.is_running(), 300
	)
	assert_true(done, "the work goes on after the load")
	assert_eq(waking.faction, 0)
	var restarted: bool = await _f.run_until(
		loaded, func() -> bool: return theirs.machine.is_running(), roundi(left * 10.0) + 20
	)
	assert_true(restarted, "the shut-down timer ran out on time")
	assert_eq(theirs.faction, 1)
	await _f.run(loaded, 2)
	assert_eq(
		world.economy.stockpile(0).power_produced,
		7 + 15 + 15,
		"Lander at 0.7 (ADR 0018), two engines"
	)


func test_the_finales_charge_and_custodians_round_trip() -> void:
	var def: MissionDef = SaveFixture.mission(&"hollow_finale")
	var map: LandingMap = await _land(def)
	var world: SimWorld = map.world
	var machinery: MachinerySystem = world.planet as MachinerySystem
	var script: CoreScript = map.runner.script_instance as CoreScript
	assert_not_null(script, "the finale's script")
	assert_not_null(script.core(), "the Beacon Core on the dais")
	for engine: Building in machinery.engines().slice(0, 4):
		engine.faction = 0
		engine.machine.set_state(Machine.RUNNING)
	var surveyor: Unit = SaveFixture.unit_of(world, 0, &"concord_surveyor")
	SaveFixture.teleport(surveyor, script.core().position + Vector3(-10, 0, 0))
	script.charges[0] = 0.19
	var staged: bool = await _f.run_until(map, func() -> bool: return script.stages_woken >= 1, 150)
	assert_true(staged, "the first stage woke")
	assert_false(script.custodian_groups.is_empty(), "and converges on the dais")
	await _f.run(map, 10)
	var charge: float = script.charge_of(0)
	assert_gt(charge, 0.19)
	var members: int = script.custodian_groups[0].members.size()
	var snapshot: Dictionary = map.snapshot()
	_f.dispose(map)
	_charges.clear()
	var loaded: LandingMap = await _land(def, snapshot)
	var restored: CoreScript = loaded.runner.script_instance as CoreScript
	assert_almost_eq(restored.charge_of(0), charge, 0.0001, "the charge")
	assert_eq(restored.stages_woken, 1)
	assert_eq(restored.custodian_groups.size(), 1)
	assert_eq(restored.custodian_groups[0].members.size(), members, "the same guardians")
	assert_false(_charges.is_empty(), "the Core's charge is announced again")
	assert_almost_eq(_charges[0], charge, 0.001)
	var resaved: Dictionary = loaded.snapshot()
	var differences: Array[String] = SaveFixture.differences(
		SaveFixture.normalised(snapshot), SaveFixture.normalised(resaved)
	)
	assert_eq(differences, [] as Array[String], "save, load, save gives the same save")


func _engine_at(machinery: MachinerySystem, at: Vector3) -> Building:
	for engine: Building in machinery.engines():
		if Vector2(engine.position.x - at.x, engine.position.z - at.z).length() < 1.0:
			return engine
	return null


func _land(def: MissionDef, restore: Dictionary = {}) -> LandingMap:
	var map: LandingMap = await _f.land(def, null, restore)
	_maps.append(map)
	return map
