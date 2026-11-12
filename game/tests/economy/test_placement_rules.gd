extends GutTest
## Placement validity: overlap with buildings and nodes, terrain, slope, bounds and
## the Flux vent rule.

var _rules: PlacementRules
var _reactor: BuildingDef
var _tap: BuildingDef
var _deposit_def: ResourceNodeDef
var _vent_def: ResourceNodeDef


func before_each() -> void:
	_rules = PlacementRules.new()
	_rules.rules = EconomyRules.new()
	_rules.rules.building_gap = 1.0
	_rules.rules.max_slope = 12.0
	_rules.rules.vent_snap_distance = 6.0
	_rules.bounds = Rect2(-100, -100, 200, 200)
	_reactor = BuildingDef.new()
	_reactor.footprint = Rect2(-3, -3, 6, 6)
	_tap = BuildingDef.new()
	_tap.footprint = Rect2(-2.5, -2.5, 5, 5)
	_tap.requires_resource = &"flux"
	_deposit_def = ResourceNodeDef.new()
	_deposit_def.resource = &"alloy"
	_deposit_def.radius = 3.0
	_vent_def = ResourceNodeDef.new()
	_vent_def.resource = &"flux"
	_vent_def.amount = 0
	_vent_def.radius = 2.5


func _node(def: ResourceNodeDef, at: Vector3) -> ResourceNode:
	var node: ResourceNode = ResourceNode.new()
	node.setup(def)
	node.position = at
	autofree(node)
	_rules.nodes.append(node)
	return node


func test_open_flat_ground_is_valid() -> void:
	assert_eq(_rules.check(_reactor, Vector3.ZERO), PlacementRules.OK)


func test_overlapping_or_too_close_to_a_building_is_blocked() -> void:
	_rules.footprints.append(Rect2(3.5, -3, 6, 6))
	assert_eq(_rules.check(_reactor, Vector3(3, 0, 0)), PlacementRules.BLOCKED, "overlap")
	assert_eq(_rules.check(_reactor, Vector3.ZERO), PlacementRules.BLOCKED, "0.5 m gap < 1 m")
	assert_eq(_rules.check(_reactor, Vector3(-0.5, 0, 0)), PlacementRules.OK, "1 m gap")


func test_standing_on_a_deposit_is_refused() -> void:
	_node(_deposit_def, Vector3(5, 0, 0))
	assert_eq(_rules.check(_reactor, Vector3.ZERO), PlacementRules.ON_RESOURCE)
	assert_eq(_rules.check(_reactor, Vector3(-3, 0, 0)), PlacementRules.OK)


func test_unwalkable_ground_is_refused() -> void:
	_rules.is_walkable = func(point: Vector3) -> bool: return point.x < 2.0
	assert_eq(_rules.check(_reactor, Vector3.ZERO), PlacementRules.UNWALKABLE)
	assert_eq(_rules.check(_reactor, Vector3(-5, 0, 0)), PlacementRules.OK)


func test_steep_ground_is_refused() -> void:
	_rules.height_at = func(x: float, _z: float) -> float: return x * 0.5  # about 27°
	assert_eq(_rules.check(_reactor, Vector3.ZERO), PlacementRules.TOO_STEEP)
	_rules.height_at = func(x: float, _z: float) -> float: return x * 0.1  # about 6°
	assert_eq(_rules.check(_reactor, Vector3.ZERO), PlacementRules.OK)


func test_outside_the_bounds_is_refused() -> void:
	assert_eq(_rules.check(_reactor, Vector3(98, 0, 0)), PlacementRules.OUT_OF_BOUNDS)


func test_a_tap_needs_a_free_vent_and_snaps_onto_it() -> void:
	assert_eq(_rules.check(_tap, Vector3.ZERO), PlacementRules.NEEDS_VENT)
	var vent: ResourceNode = _node(_vent_def, Vector3(10, 0, 10))
	var snapped: Vector3 = _rules.snap(_tap, Vector3(12, 0, 8))
	assert_eq(snapped, vent.position, "snaps to the vent within 6 m")
	assert_eq(_rules.check(_tap, snapped), PlacementRules.OK, "the vent itself is not in the way")
	var taken: Building = Building.new()
	autofree(taken)
	vent.tap = taken
	assert_eq(_rules.check(_tap, snapped), PlacementRules.VENT_TAKEN)
	assert_ne(_rules.snap(_tap, Vector3(12, 0, 8)), vent.position, "no snap to a tapped vent")


func test_other_buildings_snap_to_a_half_metre_grid() -> void:
	assert_eq(_rules.snap(_reactor, Vector3(1.26, 3.0, -2.7)), Vector3(1.5, 3.0, -2.5))


func test_every_refusal_has_a_player_facing_reason() -> void:
	for reason: StringName in [
		PlacementRules.OUT_OF_BOUNDS,
		PlacementRules.BLOCKED,
		PlacementRules.ON_RESOURCE,
		PlacementRules.NEEDS_VENT,
		PlacementRules.VENT_TAKEN,
		PlacementRules.UNWALKABLE,
		PlacementRules.TOO_STEEP,
	]:
		assert_ne(PlacementRules.describe(reason), "", String(reason))
