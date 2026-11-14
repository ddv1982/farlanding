extends GutTest
## Low-Water Recovery on Thalassa Tidewater through a save (ADR 0013, ADR 0014): the
## tide part-way up, a unit carrying the artefact, and a unit waiting at a ford the sea
## has closed all come back as they were, save -> load -> save gives the same save,
## and play carries on: the sea falls, the waiting unit crosses, the carrier walks on
## with the artefact.

const ARTEFACT_AT: Vector3 = Vector3(50, 0, -42)
## The south bank of the west ford, and a point on the ford's bar.
const FORD_BANK: Vector3 = Vector3(-66, 0, -7)
const ON_THE_FORD: Vector3 = Vector3(-59, 0, -24)
## Where the carrier is sent with the artefact (north flats, dry at any tide).
const CARRY_TO: Vector3 = Vector3(-40, 0, -92)

var _f: SaveFixture
var _maps: Array[LandingMap] = []


func before_each() -> void:
	_f = SaveFixture.new(self)
	_maps.clear()


func after_each() -> void:
	for map: LandingMap in _maps:
		_f.dispose(map)


func test_tide_carrier_and_a_closed_ford_round_trip() -> void:
	var def: MissionDef = SaveFixture.mission(&"thalassa_recovery")
	var map: LandingMap = await _land(def)
	var world: SimWorld = map.world
	var rangers: Array[Unit] = []
	for unit: Unit in world.units_of(0):
		if unit.def.id == &"concord_ranger":
			rangers.append(unit)
	var carrier: Unit = rangers[0]
	var waiter: Unit = rangers[1]
	SaveFixture.toughen(carrier, 5000.0)
	SaveFixture.toughen(waiter, 5000.0)
	SaveFixture.teleport(carrier, _ground(world, ARTEFACT_AT + Vector3(3, 0, 2)))
	SaveFixture.teleport(waiter, _ground(world, FORD_BANK))
	var artefact: Prop = _artefact(world)
	var queue: CommandQueue = map.context.command_queue
	queue.push(CarryCommand.new(0, [carrier] as Array[Node3D], artefact))
	assert_true(await _f.run_until(map, func() -> bool: return carrier.is_carrying, 100), "lifted")
	# The sea three quarters up, rising slowly (100 s left): the fords and pans closed.
	var tide: TideSystem = world.planet as TideSystem
	var now: int = map.context.sim_clock.get_tick()
	(
		tide
		. from_dict(
			{
				"version": TideSystem.SAVE_VERSION,
				"state": String(TideSystem.STATE_RISING),
				"level": 0.75,
				"tick": now,
				"phase_start": now - 3000,
				"phase_end": now + 1000,
				"turn_at": now - 3000,
				"emitted": 0.75,
			}
		)
	)
	await _f.run(map, 20)
	var paths: NavmeshPathService = world.paths as NavmeshPathService
	assert_gte(paths.flood_stage, 2, "the ford is closed")
	queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [waiter] as Array[Node3D], ON_THE_FORD))
	assert_true(
		await _f.run_until(
			map,
			func() -> bool:
				return waiter.locomotion.is_waiting_for_tide() and not waiter.is_moving(),
			200
		),
		"the waiter stops at the water"
	)
	assert_eq(tide.state, TideSystem.STATE_RISING, "still part-way up")
	queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [carrier] as Array[Node3D], CARRY_TO))
	await _f.run(map, 5)
	var snapshot: Dictionary = map.snapshot()
	var before: Dictionary = _situation(map, carrier, waiter)
	var carrier_id: int = carrier.entity_id
	var waiter_id: int = waiter.entity_id
	_f.dispose(map)
	var loaded: LandingMap = await _land(def, snapshot)
	world = loaded.world
	carrier = world.entity(carrier_id) as Unit
	waiter = world.entity(waiter_id) as Unit
	var after: Dictionary = _situation(loaded, carrier, waiter)
	for key: String in before:
		assert_eq(var_to_str(after[key]), var_to_str(before[key]), "same %s after the load" % key)
	var resaved: Dictionary = loaded.snapshot()
	var differences: Array[String] = SaveFixture.differences(
		SaveFixture.normalised(snapshot), SaveFixture.normalised(resaved)
	)
	assert_eq(differences, [] as Array[String], "save, load, save gives the same save")
	artefact = _artefact(world)
	assert_eq(artefact.carrier, carrier, "the artefact is in the same hands")
	assert_true(artefact.is_in_group(Prop.ARTEFACTS_GROUP))
	assert_eq(
		(world.paths as NavmeshPathService).flood_stage, paths.flood_stage, "the same ground closed"
	)
	# Play on: the carrier walks on, the sea rises, holds, falls; the waiter crosses.
	var start: Vector3 = carrier.sim_position()
	await _f.run(loaded, 60)
	assert_gt(_flat(carrier.sim_position(), start), 3.0, "the carrier walks on")
	assert_true(carrier.is_carrying)
	var restored_tide: TideSystem = world.planet as TideSystem
	assert_true(
		await _f.run_until(
			loaded, func() -> bool: return restored_tide.state == TideSystem.STATE_HIGH, 1200
		),
		"the sea reaches high water"
	)
	var turn: int = restored_tide.turn_tick() - loaded.context.sim_clock.get_tick()
	await _f.run(loaded, maxi(turn, 0) + 30)
	assert_eq(restored_tide.state, TideSystem.STATE_FALLING)
	assert_true(
		await _f.run_until(
			loaded, func() -> bool: return _flat(waiter.sim_position(), ON_THE_FORD) < 3.0, 2400
		),
		"the waiter reaches the ford once the sea is down"
	)
	assert_true(carrier.is_carrying, "the artefact still in hand")


func _land(def: MissionDef, restore: Dictionary = {}) -> LandingMap:
	var map: LandingMap = await _f.land(def, null, restore)
	_maps.append(map)
	return map


func _situation(map: LandingMap, carrier: Unit, waiter: Unit) -> Dictionary:
	var world: SimWorld = map.world
	var tide: TideSystem = world.planet as TideSystem
	var artefact: Prop = _artefact(world)
	return {
		"tide": [tide.state, snappedf(tide.level, 0.0001), tide.turn_tick()],
		"sea": snappedf(world.conditions.sea_level, 0.0001),
		"stage": (world.paths as NavmeshPathService).flood_stage,
		"carrier": [carrier.is_carrying, carrier.sim_position().snappedf(0.01)],
		"speed": snappedf(carrier.locomotion.mover.max_speed, 0.001),
		"artefact": [artefact.entity_id, artefact.lifted, artefact.last_faction],
		"waiter":
		[
			waiter.locomotion.is_waiting_for_tide(),
			waiter.orders.is_idle(),
			waiter.sim_position().snappedf(0.01),
		],
		"objective": map.runner.objective(&"recover_artefact").progress_text,
	}


func _artefact(world: SimWorld) -> Prop:
	for prop: Prop in world.props:
		if prop.is_carriable():
			return prop
	return null


static func _ground(world: SimWorld, at: Vector3) -> Vector3:
	return Vector3(at.x, world.heights.sample(at.x, at.z), at.z)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
