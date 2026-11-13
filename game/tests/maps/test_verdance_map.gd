extends GutTest
## Verdance Understory (ADR 0016) on its real navmesh: both bases connected, every
## grove, deposit, vent and site reachable from the Concord landing, the root ridges and
## trunks closed, the stream wadeable, the crowns from the MapDef matching the terrain
## recipe, and flying units ignoring the navmesh.

const MAP: String = "res://data/maps/verdance_understory_map.tres"
const CONCORD_BASE: Vector3 = Vector3(-80, 0, 85)
## Inside the Combine base's shelf, clear of its buildings.
const COMBINE_BASE: Vector3 = Vector3(96, 0, -72)
## The terrain recipe's groves (art/terrain/verdance_basin.py, Godot x, z).
const GROVES: Array[Vector4] = [
	Vector4(0, 0, 22, 18),
	Vector4(-84, 30, 20, 16),
	Vector4(-70, -40, 18, 22),
	Vector4(-20, 70, 16, 14),
	Vector4(-30, -80, 20, 15),
	Vector4(-36, -10, 13, 12),
	Vector4(-96, -84, 14, 14),
	Vector4(84, -30, 20, 16),
	Vector4(70, 40, 18, 22),
	Vector4(20, -70, 16, 14),
	Vector4(30, 80, 20, 15),
	Vector4(36, 10, 13, 12),
	Vector4(96, 84, 14, 14),
]
## One point under each grove's crown, beside its trunk(s) and clear of nodes and sites.
const INSIDE: PackedVector3Array = [
	Vector3(0, 0, -12),
	Vector3(-84, 0, 22),
	Vector3(-70, 0, -40),
	Vector3(-30, 0, 74),
	Vector3(-30, 0, -88),
	Vector3(-44, 0, -14),
	Vector3(-88, 0, -90),
	Vector3(84, 0, -38),
	Vector3(70, 0, 40),
	Vector3(30, 0, -74),
	Vector3(30, 0, 88),
	Vector3(28, 0, 14),
	Vector3(88, 0, 90),
]
## Points on the root ridges' centre lines (impassable).
const RIDGES: PackedVector3Array = [
	Vector3(-47, 0, 78),
	Vector3(-44, 0, 52),
	Vector3(-92, 0, -14),
	Vector3(47, 0, -78),
	Vector3(44, 0, -52),
	Vector3(92, 0, 14)
]
## Points on the stream (bed at -0.3 m, wadeable).
const STREAM: PackedVector3Array = [
	Vector3(-92, 0, -66), Vector3(-52, 0, -58), Vector3(30, 0, 38), Vector3(92, 0, 66)
]

var _f: SaveFixture
var _maps: Array[LandingMap] = []


func before_each() -> void:
	_f = SaveFixture.new(self)
	_maps.clear()


func after_each() -> void:
	for map: LandingMap in _maps:
		_f.dispose(map)


func test_the_map_data_matches_the_terrain_recipe() -> void:
	var map_def: MapDef = load(MAP)
	assert_eq(map_def.id, &"verdance_understory")
	assert_eq(map_def.navmesh.resource_path, BakeVerdanceNavmesh.OUTPUT, "the bake's output")
	assert_false(map_def.has_flood_stages(), "one stage, no sea")
	assert_lt(BakeVerdanceNavmesh.CLIP, BakeVerdanceNavmesh.STREAM_BED, "the stream stays")
	assert_eq(map_def.canopy_zones.size(), GROVES.size(), "thirteen groves")
	for i: int in GROVES.size():
		assert_eq(map_def.canopy_zones[i], GROVES[i], "grove %d" % i)
	assert_gt(map_def.minimap_high.g, map_def.minimap_low.g, "moss green, light over dark")
	var canopy: CanopySystem = _canopy_for(map_def)
	var covered_nodes: int = 0
	for point: Vector3 in map_def.rich_deposit_positions + map_def.vent_positions:
		covered_nodes += 1 if canopy.is_under_canopy(point) else 0
	assert_gt(covered_nodes, 4, "rich deposits and vents partly under the crowns")
	for point: Vector3 in map_def.discovery_positions:
		assert_true(canopy.is_under_canopy(point), "every site is in a grove: %s" % point)
	assert_false(canopy.is_under_canopy(CONCORD_BASE), "the bases stand in the open")
	assert_false(canopy.is_under_canopy(Vector3(80, 0, -80)))


func test_verdance_holds_its_bases_groves_and_stream() -> void:
	var map: LandingMap = await _land(&"verdance_conquest")
	var world: SimWorld = map.world
	var paths: PathService = world.paths
	assert_true(world.planet is CanopySystem, "Verdance's canopy")
	assert_eq(world.canopy_zones, map.map_def.canopy_zones, "the map hands the crowns over")
	assert_eq(world.resource_nodes.size(), 22, "12 deposits, 4 rich, 6 vents")
	assert_eq(world.discovery.sites.size(), 6)
	assert_eq(world.props.size(), 8, "eight mossy rocks")
	assert_eq(world.units_of(Factions.CUSTODIANS).size(), 2, "two dormant Wardens")
	var path: PackedVector3Array = paths.find_path(
		paths.closest_point(CONCORD_BASE), paths.closest_point(COMBINE_BASE)
	)
	assert_false(path.is_empty(), "base to base")
	if not path.is_empty():
		assert_lt(_flat(path[path.size() - 1], COMBINE_BASE), 4.0, "it gets there")
	var canopy: CanopySystem = world.planet as CanopySystem
	for inside: Vector3 in INSIDE:
		assert_true(canopy.is_under_canopy(inside), "%s is under a crown" % inside)
		_expect_reached(paths, inside, 2.5, "the grove at %s" % inside)
	for node: ResourceNode in world.resource_nodes:
		_expect_reached(paths, node.position, node.def.radius + 4.0, node.name)
	for site: DiscoverySite in world.discovery.sites:
		_expect_reached(paths, site.position, site.def.radius + 4.0, String(site.def.id))
	for point: Vector3 in RIDGES:
		assert_false(paths.is_walkable(point), "nobody walks on the ridge at %s" % point)
	for point: Vector3 in STREAM:
		var bed: float = world.heights.sample(point.x, point.z)
		assert_lt(bed, 0.0, "the stream at %s" % point)
		_expect_reached(paths, point, 2.5, "wading the stream at %s" % point)


func test_flyers_ignore_the_navmesh() -> void:
	var map: LandingMap = await _land(&"verdance_conquest")
	var world: SimWorld = map.world
	var talon_def: UnitDef = load("res://data/units/concord_talon.tres")
	var talon: Unit = world.spawn_unit(talon_def, 0, CONCORD_BASE + Vector3(0, 0, -12))
	assert_eq(talon.locomotion.paths, world.air_paths)
	var ground: float = world.heights.sample(talon.sim_position().x, talon.sim_position().z)
	assert_almost_eq(talon.sim_position().y, ground + 13.0, 0.05, "13 m over the moss")
	# Straight over the root ridge and a grove's trunks to the Combine shelf.
	var goal: Vector3 = Vector3(-30, 0, 100)
	map.context.command_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [talon], goal))
	await _f.run(map, 2)
	assert_eq(talon.locomotion.mover.path.size(), 1, "one straight leg over the ridge")
	var arrived: bool = await _f.run_until(map, func() -> bool: return talon.orders.is_idle(), 200)
	assert_true(arrived)
	assert_lt(_flat(talon.sim_position(), goal), 1.0, "it is there")
	var under: float = world.heights.sample(goal.x, goal.z)
	assert_almost_eq(talon.sim_position().y, under + 13.0, 0.05, "still 13 m up")


func _canopy_for(map_def: MapDef) -> CanopySystem:
	var fixture: EconomyFixture = EconomyFixture.new(self)
	fixture.world.canopy_zones = map_def.canopy_zones
	var rule: CanopyRule = CanopyRule.new()
	rule.system = CanopySystem
	var canopy: CanopySystem = PlanetRuleSystem.start(fixture.world, rule) as CanopySystem
	return canopy


func _land(id: StringName) -> LandingMap:
	var map: LandingMap = await _f.land(SaveFixture.mission(id))
	_maps.append(map)
	return map


func _expect_reached(paths: PathService, target: Vector3, within: float, what: String) -> void:
	var from: Vector3 = paths.closest_point(CONCORD_BASE)
	var path: PackedVector3Array = paths.find_path(from, paths.closest_point(target))
	assert_false(path.is_empty(), "a path to %s" % what)
	if not path.is_empty():
		assert_lt(_flat(path[path.size() - 1], target), within, "%s is reached" % what)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
