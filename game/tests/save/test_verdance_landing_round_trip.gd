extends GutTest
## Canopy Conquest on Verdance through a save (ADR 0013, ADR 0016): a Ranger under a
## crown that just fired (revealed), a Talon in flight, and the Hornet patrols all come
## back as they were; save -> load -> save gives the same save, the reveal runs out on
## time, and the Talon flies on at its altitude.

## Under the grove north of the Concord base.
const GROVE: Vector3 = Vector3(-84, 0, 22)

var _f: SaveFixture
var _maps: Array[LandingMap] = []


func before_each() -> void:
	_f = SaveFixture.new(self)
	_maps.clear()


func after_each() -> void:
	for map: LandingMap in _maps:
		_f.dispose(map)


func test_cover_a_reveal_a_talon_and_the_patrols_round_trip() -> void:
	var def: MissionDef = SaveFixture.mission(&"verdance_conquest")
	var map: LandingMap = await _land(def)
	var world: SimWorld = map.world
	var canopy: CanopySystem = world.planet as CanopySystem
	assert_not_null(canopy)
	var ranger: Unit = SaveFixture.unit_of(world, 0, &"concord_ranger")
	SaveFixture.teleport(ranger, GROVE)
	var talon_def: UnitDef = load("res://data/units/concord_talon.tres")
	var talon: Unit = world.spawn_unit(talon_def, 0, Vector3(-80, 0, 70))
	map.context.command_queue.push(
		MoveCommand.new(MoveCommand.KIND_MOVE, 0, [talon], Vector3(-20, 0, 40))
	)
	await _f.run(map, 10)
	assert_true(canopy.is_covered(ranger), "the Ranger is under the crown")
	assert_false(canopy.is_covered(talon))
	Events.weapon_fired.emit(ranger, ranger.weapon.def, ranger.sim_position(), Vector3.ZERO)
	await _f.run(map, 5)
	assert_true(canopy.is_revealed(ranger), "it fired: revealed")
	var hornets: int = map.runner.guards.guards().size()
	assert_eq(hornets, 3, "three Hornets on watch")
	var snapshot: Dictionary = map.snapshot()
	var saved_planet: Dictionary = canopy.to_dict()
	var ranger_id: int = ranger.entity_id
	var talon_id: int = talon.entity_id
	var talon_at: Vector3 = talon.sim_position()
	_f.dispose(map)
	var loaded: LandingMap = await _land(def, snapshot)
	world = loaded.world
	var restored: CanopySystem = world.planet as CanopySystem
	assert_not_null(restored)
	assert_eq(restored.to_dict(), saved_planet, "the cover and the reveal")
	ranger = world.entity(ranger_id) as Unit
	talon = world.entity(talon_id) as Unit
	assert_true(restored.is_covered(ranger))
	assert_true(restored.is_revealed(ranger))
	assert_eq(talon.locomotion.paths, world.air_paths, "the Talon flies again")
	assert_almost_eq(talon.sim_position().distance_to(talon_at), 0.0, 0.01, "where it was")
	assert_eq(loaded.runner.guards.guards().size(), hornets, "the patrols are back")
	var resaved: Dictionary = loaded.snapshot()
	var differences: Array[String] = SaveFixture.differences(
		SaveFixture.normalised(snapshot), SaveFixture.normalised(resaved)
	)
	assert_eq(differences, [] as Array[String], "save, load, save gives the same save")
	await _f.run(loaded, 45)
	assert_false(restored.is_revealed(ranger), "the reveal ran out")
	var arrived: bool = await _f.run_until(
		loaded, func() -> bool: return talon.orders.is_idle(), 300
	)
	assert_true(arrived, "the Talon reaches where it was sent")
	var ground: float = world.heights.sample(talon.sim_position().x, talon.sim_position().z)
	assert_almost_eq(talon.sim_position().y, ground + 13.0, 0.05, "at its altitude")


func _land(def: MissionDef, restore: Dictionary = {}) -> LandingMap:
	var map: LandingMap = await _f.land(def, null, restore)
	_maps.append(map)
	return map
