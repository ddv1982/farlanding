extends GutTest
## Hollow Meridian Deck (ADR 0017) on its real navmesh: the data matches the terrain
## recipe and is point-symmetric, the chasms are never walkable and only the bridges
## cross them, the dais is climbed only by its ramps, every engine, deposit, vent and
## site is reachable from the Concord landing, and the landing puts eight dormant
## engines, the guardians and the Beacon Core on the deck.

const MAP: String = "res://data/maps/hollow_meridian_deck_map.tres"
const CONCORD_BASE: Vector3 = Vector3(-80, 0, 85)
## On the Combine deck, clear of its buildings.
const COMBINE_BASE: Vector3 = Vector3(96, 0, -96)
## The terrain recipe's suggested engine spots (art/terrain/hollow_meridian.py, Godot).
const ENGINES: PackedVector3Array = [
	Vector3(-52, 0, 70),
	Vector3(-96, 0, 48),
	Vector3(-30, 0, -20),
	Vector3(-84, 0, -76),
	Vector3(52, 0, -70),
	Vector3(96, 0, -48),
	Vector3(30, 0, 20),
	Vector3(84, 0, 76),
]
## Points in the chasms (x -120..40, z -44..-32; x -40..120, z 32..44), off the bridges.
const CHASMS: PackedVector3Array = [
	Vector3(-40, 0, -38),
	Vector3(-100, 0, -38),
	Vector3(20, 0, -38),
	Vector3(40, 0, 38),
	Vector3(100, 0, 38),
	Vector3(-20, 0, 38),
]
## The middle of each bridge (12 m wide at x -70 and -12, and 70 and 12).
const BRIDGES: PackedVector3Array = [
	Vector3(-70, 0, -38), Vector3(-12, 0, -38), Vector3(70, 0, 38), Vector3(12, 0, 38)
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
	assert_eq(map_def.id, &"hollow_meridian_deck")
	assert_eq(map_def.navmesh.resource_path, BakeHollowNavmesh.OUTPUT, "the bake's output")
	assert_false(map_def.has_flood_stages(), "one stage, no sea")
	assert_between(BakeHollowNavmesh.CLIP, BakeHollowNavmesh.VOID, BakeHollowNavmesh.DECK)
	assert_eq(map_def.machine.resource_path, "res://data/buildings/antecedent_engine.tres")
	assert_eq(map_def.machine_positions, ENGINES, "the recipe's eight engine spots")
	assert_eq(map_def.landing_zone, Vector3(-80, 0.5, 85))
	var dark: Color = map_def.minimap_low
	var pale: Color = map_def.minimap_high
	assert_gt(pale.v, dark.v + 0.4, "pale stone over dark stone")
	assert_lt(absf(pale.r - pale.b), 0.08, "grey, not a hue")
	assert_lt(absf(dark.r - dark.b), 0.08)
	for points: PackedVector3Array in [
		map_def.deposit_positions,
		map_def.rich_deposit_positions,
		map_def.vent_positions,
		map_def.machine_positions,
		map_def.custodian_positions,
	]:
		for point: Vector3 in points:
			assert_true(points.has(Vector3(-point.x, 0, -point.z)), "%s has its mirror" % point)
	var sentinels: int = 0
	for def: UnitDef in map_def.custodian_roster:
		sentinels += 1 if def.id == &"custodian_sentinel" else 0
	assert_gt(sentinels, 3, "Sentinels among the guardians")
	assert_lt(sentinels, map_def.custodian_roster.size(), "and Wardens")
	assert_eq(map_def.discoveries.size(), map_def.discovery_positions.size())
	var core: PropPlacement = map_def.prop_layout.placements[0]
	assert_eq(core.def.id, &"antecedent_site_core")
	assert_eq(core.position, Vector3.ZERO, "the Core on the dais")


func test_the_deck_its_chasms_bridges_and_dais() -> void:
	var map: LandingMap = await _land(&"hollow_power")
	var world: SimWorld = map.world
	var paths: PathService = world.paths
	assert_true(world.planet is MachinerySystem, "Hollow Meridian's machinery")
	var machinery: MachinerySystem = world.planet as MachinerySystem
	assert_eq(machinery.engines().size(), 8, "eight engines")
	for engine: Building in machinery.engines():
		assert_true(engine.machine.is_dormant(), "%s starts dormant" % engine.name)
		assert_eq(engine.faction, Factions.CUSTODIANS)
		_expect_reached(paths, engine.position, 8.0, engine.name)
	assert_eq(world.units_of(Factions.CUSTODIANS).size(), map.map_def.custodian_roster.size())
	for unit: Unit in world.units_of(Factions.CUSTODIANS):
		assert_true(unit.is_dormant, "%s is dormant" % unit.name)
	assert_eq(world.props.size(), 1, "the Beacon Core")
	assert_eq(world.resource_nodes.size(), 22, "12 deposits, 4 rich, 6 vents")
	for node: ResourceNode in world.resource_nodes:
		_expect_reached(paths, node.position, node.def.radius + 4.0, node.name)
	for site: DiscoverySite in world.discovery.sites:
		_expect_reached(paths, site.position, site.def.radius + 4.0, String(site.def.id))
	var path: PackedVector3Array = paths.find_path(
		paths.closest_point(CONCORD_BASE), paths.closest_point(COMBINE_BASE)
	)
	assert_false(path.is_empty(), "base to base")
	if not path.is_empty():
		assert_lt(_flat(path[path.size() - 1], COMBINE_BASE), 4.0, "it gets there")
	for point: Vector3 in CHASMS:
		assert_false(paths.is_walkable(point), "nobody walks in the chasm at %s" % point)
		assert_lt(world.heights.sample(point.x, point.z), -10.0, "no floor to speak of")
	for point: Vector3 in BRIDGES:
		assert_true(paths.is_walkable(point), "the bridge at %s" % point)
	# Straight over a bridge, but between two bridges the way round is long.
	var over: float = _path_length(paths, Vector3(-70, 0, -24), Vector3(-70, 0, -52))
	assert_lt(over, 34.0, "across the bridge at x -70")
	var round_about: float = _path_length(paths, Vector3(-40, 0, -24), Vector3(-40, 0, -52))
	assert_gt(round_about, 50.0, "no crossing between the bridges")


func test_the_dais_is_climbed_by_its_ramps_only() -> void:
	var map: LandingMap = await _land(&"hollow_power")
	var world: SimWorld = map.world
	var paths: PathService = world.paths
	var top: Vector3 = Vector3(-13, 0, 12)
	assert_almost_eq(world.heights.sample(top.x, top.z), 3.0, 0.1, "the dais is 3 m up")
	_expect_reached(paths, top, 2.5, "the dais top beside the Core")
	var below: Vector3 = Vector3(-22, 0, 12)
	assert_almost_eq(world.heights.sample(below.x, below.z), 0.5, 0.2, "the deck below")
	assert_true(paths.is_walkable(below))
	assert_gt(_path_length(paths, below, top), 15.0, "round by a ramp, not up the side")
	for ramp: Vector3 in [
		Vector3(-23, 0, 0), Vector3(23, 0, 0), Vector3(0, 0, -23), Vector3(0, 0, 23)
	]:
		assert_true(paths.is_walkable(ramp), "the ramp at %s" % ramp)
	assert_false(paths.is_walkable(Vector3(0, 0, 0)), "the Core itself blocks")


func test_the_engines_by_each_base_are_lightly_watched() -> void:
	# The briefing's promise, and the balance harness's finding (ADR 0018): with a
	# Sentinel at the second engine by each base, the only engines a young army could
	# take were the single-Warden one by each base, and both sides crossed the deck for
	# the other's. The two by each base have one guard; the contested ones three.
	var map_def: MapDef = load(MAP)
	for engine: Vector3 in map_def.machine_positions:
		var guards: int = 0
		for guard: Vector3 in map_def.custodian_positions:
			if _flat(guard, engine) <= MachineKeeper.GUARD_RADIUS:
				guards += 1
		var by_base: bool = (
			_flat(engine, CONCORD_BASE) < 50.0 or _flat(engine, -CONCORD_BASE) < 50.0
		)
		if by_base:
			assert_eq(guards, 1, "one Warden by the engine at %s" % engine)
		else:
			assert_gte(guards, 3, "the contested engine at %s is well guarded" % engine)


func test_the_deck_holds_more_alloy_than_other_worlds() -> void:
	# Found by the balance harness (ADR 0018): with the standard deposits the Alloy in
	# reach of each base (7,500) was gone by minute 16-19, before either side could hold
	# four engines, and finales timed out with both sides bankrupt.
	var map_def: MapDef = load(MAP)
	var standard: ResourceNodeDef = load("res://data/resources/kessel_alloy_deposit.tres")
	var rich: ResourceNodeDef = load("res://data/resources/kessel_alloy_deposit_rich.tres")
	assert_eq(map_def.deposit.resource, &"alloy")
	assert_gte(map_def.deposit.amount, standard.amount * 5 / 3, "deeper deposits")
	assert_gte(map_def.rich_deposit.amount, rich.amount * 3 / 2, "deeper rich deposits")


func test_every_vent_takes_a_flux_extractor() -> void:
	# Found by the balance harness (ADR 0018): a vent by each base lay outside the build
	# bounds, so that side tapped one vent of its three and starved for Flux.
	var map: LandingMap = await _land(&"hollow_power")
	var world: SimWorld = map.world
	var placement: PlacementRules = world.placement_rules()
	var vents: int = 0
	for def: BuildingDef in [
		load("res://data/buildings/concord_flux_tap.tres") as BuildingDef,
		load("res://data/buildings/combine_flux_siphon.tres") as BuildingDef,
	]:
		for node: ResourceNode in world.resource_nodes:
			if node.resource() != def.requires_resource:
				continue
			vents += 1
			var reason: StringName = placement.check(def, node.position)
			assert_eq(reason, PlacementRules.OK, "%s on the vent at %s" % [def.id, node.position])
	assert_eq(vents, 12, "six vents, each checked for both factions' extractor")


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


static func _path_length(paths: PathService, from: Vector3, to: Vector3) -> float:
	var path: PackedVector3Array = paths.find_path(
		paths.closest_point(from), paths.closest_point(to)
	)
	var length: float = 0.0
	for i: int in range(1, path.size()):
		length += _flat(path[i - 1], path[i])
	return length if not path.is_empty() else INF


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
