extends GutTest
## The landing-map base and its maps (ADR 0014). Kessel plays through the general
## LandingMap exactly as before; Thalassa Tidewater's real navmeshes hold at low and at
## high water: both bases, every deposit, every discovery site and every crossing are
## checked from the Concord landing, for ground units and hovering units.

const THALASSA_MAP: String = "res://data/maps/thalassa_tidewater_map.tres"
const KESSEL_MAP: String = "res://data/maps/kessel_proving_map.tres"
const TIDE: String = "res://data/planets/thalassa_low.tres"
## Where the channel runs (west-north-west to east-south-east) and across it.
const ACROSS: Vector3 = Vector3(-0.396, 0.0, 0.918)
const FORDS: PackedVector3Array = [Vector3(-58, 0, -25), Vector3(74, 0, 32)]
const CAUSEWAY: Vector3 = Vector3(12, 0, 0)
## Half the length of a crossing checked: bank to bank.
const BANK: float = 22.0
## A way around is at least this much longer than the straight crossing.
const DETOUR: float = 1.5
## Deposits and sites in the tidal pans: under water at high tide.
const PAN_RADIUS: float = 16.0
const PANS: PackedVector3Array = [
	Vector3(-30, 0, 62), Vector3(36, 0, -58), Vector3(-88, 0, 8), Vector3(92, 0, -12)
]
const CONCORD_BASE: Vector3 = Vector3(-80, 0, 72)
const COMBINE_BASE: Vector3 = Vector3(80, 0, -68)

var _f: SaveFixture
var _maps: Array[LandingMap] = []


func before_each() -> void:
	_f = SaveFixture.new(self)
	_maps.clear()


func after_each() -> void:
	for map: LandingMap in _maps:
		_f.dispose(map)


func test_the_bake_and_the_tide_agree_with_the_map() -> void:
	var map_def: MapDef = load(THALASSA_MAP)
	var tide: TideRule = (load(TIDE) as PlanetDef).rule as TideRule
	assert_true(map_def.has_flood_stages())
	var stages: Array[NavigationMesh] = map_def.stage_navmeshes()
	assert_eq(stages.size(), BakeThalassaNavmesh.OUTPUTS.size())
	for k: int in stages.size():
		assert_eq(stages[k].resource_path, BakeThalassaNavmesh.OUTPUTS[k], "stage %d" % k)
		assert_almost_eq(map_def.flood_levels[k], BakeThalassaNavmesh.LEVELS[k], 0.001)
		assert_almost_eq(map_def.flood_clips[k], BakeThalassaNavmesh.CLIPS[k], 0.001)
		var top: float = map_def.flood_levels[k + 1] if k + 1 < stages.size() else tide.high_water
		assert_almost_eq(
			map_def.flood_clips[k], top - tide.wading_depth, 0.001, "a stage closes in time"
		)
	assert_almost_eq(map_def.flood_levels[0], tide.low_water, 0.001, "stage 0 is low water")
	assert_eq(map_def.dry_crossings, PackedVector3Array([CAUSEWAY]))


func test_kessel_plays_through_the_landing_map_as_before() -> void:
	var map: LandingMap = await _land(&"conquest")
	var map_def: MapDef = map.map_def
	assert_eq(map_def.resource_path, KESSEL_MAP)
	assert_eq(map_def.navmesh.resource_path, "res://maps/kessel_proving/kessel_proving_navmesh.res")
	assert_eq(map.navigation_region.navigation_mesh.resource_path, "", "the cut copy")
	assert_false(map_def.has_flood_stages())
	var world: SimWorld = map.world
	assert_false(world.conditions.has_sea(), "no sea on Kessel")
	assert_eq(world.paths.for_hover(), world.paths, "hovering units share the ground's paths")
	assert_eq(world.resource_nodes.size(), 18)
	assert_eq(world.props.size(), 8, "eight boulders")
	assert_eq(world.units_of(Factions.CUSTODIANS).size(), 2, "two dormant Wardens")
	assert_true(world.planet is DustStormSystem, "Kessel's storms")
	assert_eq(map.runner.player_hq.position.x, -80.0)


func test_thalassa_holds_at_low_and_at_high_water() -> void:
	var map: LandingMap = await _land(&"thalassa_recovery")
	var world: SimWorld = map.world
	var paths: NavmeshPathService = world.paths as NavmeshPathService
	var hover: PathService = paths.for_hover()
	assert_ne(hover, paths, "hovering units have their own paths")
	assert_true(world.planet is TideSystem)
	assert_eq(paths.flood_stage, 0, "the landing starts at low water")
	assert_eq(world.units_of(Factions.CUSTODIANS).size(), 2, "the Wardens on their shoal")
	assert_eq(world.props.size(), 12, "eleven reefs and the artefact")
	# Low water: everything reachable, the fords open.
	_expect_bases(paths, "low water")
	for node: ResourceNode in world.resource_nodes:
		_expect_reached(paths, node.position, node.def.radius + 4.0, "%s at low water" % node.name)
	for site: DiscoverySite in world.discovery.sites:
		_expect_reached(paths, site.position, 7.0, "%s at low water" % site.def.id)
	_expect_reached(paths, _artefact(world).position, 3.0, "the artefact")
	for ford: Vector3 in FORDS:
		assert_lt(_crossing(paths, ford), BANK * 2.0 * DETOUR, "the ford at %s is open" % ford)
	assert_lt(_crossing(paths, CAUSEWAY), BANK * 2.0 * DETOUR, "the causeway")
	_expect_channel_closed(world, paths, hover, "low water")
	# High water: the fords and pans closed to ground units, never to hovering ones.
	await _high_water(map)
	assert_eq(paths.flood_stage, paths._stage_levels.size() - 1, "the top stage")
	_expect_bases(paths, "high water")
	for node: ResourceNode in world.resource_nodes:
		if _in_pan(node.position):
			assert_true(node.is_flooded, "%s is under water" % node.name)
			continue
		assert_false(node.is_flooded, "%s stays dry" % node.name)
		_expect_reached(paths, node.position, node.def.radius + 4.0, "%s at high water" % node.name)
	for site: DiscoverySite in world.discovery.sites:
		if not _in_pan(site.position):
			_expect_reached(paths, site.position, 7.0, "%s at high water" % site.def.id)
	_expect_reached(paths, _artefact(world).position, 3.0, "the artefact's shoal")
	for ford: Vector3 in FORDS:
		assert_gt(_crossing(paths, ford), BANK * 2.0 * DETOUR, "the ford at %s is closed" % ford)
		assert_lt(_crossing(hover, ford), BANK * 2.0 * DETOUR, "hovering units cross it")
	assert_lt(_crossing(paths, CAUSEWAY), BANK * 2.0 * DETOUR, "the causeway stays dry")
	_expect_channel_closed(world, paths, hover, "high water")


func _land(id: StringName) -> LandingMap:
	var map: LandingMap = await _f.land(SaveFixture.mission(id))
	_maps.append(map)
	return map


## Puts the sea at high water and waits for the navigation map to take the stage.
func _high_water(map: LandingMap) -> void:
	var tide: TideSystem = map.world.planet as TideSystem
	var now: int = map.context.sim_clock.get_tick()
	(
		tide
		. from_dict(
			{
				"version": TideSystem.SAVE_VERSION,
				"state": String(TideSystem.STATE_HIGH),
				"level": 1.0,
				"tick": now,
				"turn_at": now + 100000,
			}
		)
	)
	await _f.run(map, 10)
	var navigation: RID = map.get_world_3d().navigation_map
	var iteration: int = NavigationServer3D.map_get_iteration_id(navigation)
	for i: int in 60:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(navigation) != iteration and i > 4:
			break


func _artefact(world: SimWorld) -> Prop:
	for prop: Prop in world.props:
		if prop.is_carriable():
			return prop
	return null


func _in_pan(point: Vector3) -> bool:
	for pan: Vector3 in PANS:
		if Vector2(point.x - pan.x, point.z - pan.z).length() <= PAN_RADIUS:
			return true
	return false


func _expect_bases(paths: PathService, when: String) -> void:
	var path: PackedVector3Array = paths.find_path(
		paths.closest_point(CONCORD_BASE), paths.closest_point(COMBINE_BASE)
	)
	assert_false(path.is_empty(), "base to base at %s" % when)
	if not path.is_empty():
		assert_lt(_flat(path[path.size() - 1], COMBINE_BASE), 4.0, "it gets there at %s" % when)


func _expect_reached(paths: PathService, target: Vector3, within: float, what: String) -> void:
	var from: Vector3 = paths.closest_point(CONCORD_BASE)
	var path: PackedVector3Array = paths.find_path(from, target)
	assert_false(path.is_empty(), "a path to %s" % what)
	if not path.is_empty():
		assert_lt(_flat(path[path.size() - 1], target), within, "%s is reached" % what)


## The length of the way from one bank to the other across `at` (INF without one).
func _crossing(paths: PathService, at: Vector3) -> float:
	var from: Vector3 = paths.closest_point(at - ACROSS * BANK)
	var to: Vector3 = paths.closest_point(at + ACROSS * BANK)
	var path: PackedVector3Array = paths.find_path(from, to)
	if path.is_empty() or _flat(path[path.size() - 1], to) > 3.0:
		return INF
	var length: float = 0.0
	var previous: Vector3 = from
	for point: Vector3 in path:
		length += _flat(previous, point)
		previous = point
	return length


## Nobody walks or hovers on the channel floor (the sea never leaves it).
func _expect_channel_closed(
	world: SimWorld, paths: NavmeshPathService, hover: PathService, when: String
) -> void:
	var deep: int = 0
	for x: int in range(-110, 111, 4):
		for z: int in range(-60, 61, 4):
			var point: Vector3 = Vector3(x, 0, z)
			if world.heights.sample(point.x, point.z) > world.conditions.low_water - 0.5:
				continue
			deep += 1
			assert_false(paths.is_walkable(point), "ground units off the channel %s" % point)
			assert_false(hover.is_walkable(point), "hover units off the channel %s" % point)
	assert_gt(deep, 50, "the channel was sampled at %s" % when)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
