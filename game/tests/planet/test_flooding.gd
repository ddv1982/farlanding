extends GutTest
## What the sea does (ADR 0014), on a small test heightfield: dry flats at +1 m with a
## shallow band (a ford, -0.6 m) running north-south through x = -5..5. The sea is
## set by hand in the WorldConditions (the tide rule's only way of acting); the
## world's FloodSystem turns it into closed ground, wading units and flooded deposits.
## The base PathService judges the sea point by point and walks straight lines.

const LOW: float = -1.0
const HIGH: float = 0.2
const BAND_HALF_WIDTH: float = 5.0

var _f: EconomyFixture
var _field: HeightField
var _alerts: Array[StringName] = []


func before_each() -> void:
	_f = EconomyFixture.new(self)
	_field = _band_field()
	_f.world.heights = _field
	_f.world.paths.water_heights = _field
	_sea(LOW)
	_alerts.clear()
	Events.advisor_alert.connect(_on_alert)


func after_each() -> void:
	Events.advisor_alert.disconnect(_on_alert)
	_f.dispose()


func _on_alert(kind: StringName) -> void:
	_alerts.append(kind)


## 81 x 41 samples, 1 m apart, over x -40..40, z -20..20.
static func _band_field() -> HeightField:
	var columns: int = 81
	var rows: int = 41
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(columns * rows)
	for row: int in rows:
		for column: int in columns:
			var x: float = -40.0 + column
			heights[row * columns + column] = -0.6 if absf(x) <= BAND_HALF_WIDTH else 1.0
	return HeightField.new(Vector2(-40.0, -20.0), 1.0, columns, rows, heights)


## Puts the sea at `level` (low water -1, high water +0.2, wading depth 0.25).
func _sea(level: float) -> void:
	var conditions: WorldConditions = _f.world.conditions
	conditions.sea_level = level
	conditions.low_water = LOW
	conditions.high_water = HIGH
	conditions.wading_depth = 0.25
	conditions.wading_speed_factor = 0.35
	conditions.wading_damage_per_second = 2.0


func _seconds(seconds: float) -> void:
	_f.tick(roundi(seconds * SimClock.TICK_RATE))


func _move(unit: Unit, to: Vector3) -> void:
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit] as Array[Node3D], to))
	_f.tick()


func _hover_def() -> UnitDef:
	var def: UnitDef = _f.ranger.duplicate() as UnitDef
	def.id = &"skimmer"
	def.hovers = true
	return def


func test_ground_under_deep_water_closes_and_reopens() -> void:
	var paths: PathService = _f.world.paths
	_f.tick()
	assert_true(paths.is_walkable(Vector3(0, 0, 0)), "the ford is open at low water")
	var across: PackedVector3Array = paths.find_path(Vector3(-20, 0, 0), Vector3(20, 0, 0))
	assert_almost_eq(across[across.size() - 1].x, 20.0, 0.01, "straight across")
	_sea(HIGH)
	_f.tick()
	assert_false(paths.is_walkable(Vector3(0, 0, 0)), "deeper than a unit wades: closed")
	assert_true(paths.is_walkable(Vector3(-20, 0, 0)), "the flats stay dry")
	across = paths.find_path(Vector3(-20, 0, 0), Vector3(20, 0, 0))
	assert_lt(across[across.size() - 1].x, -BAND_HALF_WIDTH + 0.01, "the way ends at the shore")
	assert_true(paths.for_hover().is_walkable(Vector3(0, 0, 0)), "open to hovering units")
	_sea(-0.4)
	_f.tick()
	assert_true(paths.is_walkable(Vector3(0, 0, 0)), "shallow enough to wade again")


func test_a_unit_on_its_way_waits_on_the_shore_and_goes_on_when_the_sea_falls() -> void:
	var unit: Unit = _f.world.spawn_unit(_f.ranger, 0, Vector3(-30, 0, 0))
	_move(unit, Vector3(20, 0, 0))
	_seconds(0.5)
	_sea(HIGH)
	_seconds(4.0)
	assert_true(unit.locomotion.is_waiting_for_tide(), "the sea closed its way: it waits")
	assert_false(unit.orders.is_idle(), "the order stays open")
	var at: Vector3 = unit.sim_position()
	assert_lt(at.x, -BAND_HALF_WIDTH, "on the dry shore")
	assert_gt(at.x, -BAND_HALF_WIDTH - 3.0, "at the water's edge")
	assert_eq(_f.world.flood.wading_count, 0, "nobody in the water")
	_seconds(5.0)
	assert_almost_eq(unit.sim_position().x, at.x, 0.5, "still waiting")
	_sea(LOW)
	_seconds(8.0)
	assert_almost_eq(unit.sim_position().x, 20.0, 1.0, "across once the sea fell")
	assert_true(unit.orders.is_idle())


func test_hovering_units_cross_flooded_shallows() -> void:
	_sea(HIGH)
	_f.tick()
	var skimmer: Unit = _f.world.spawn_unit(_hover_def(), 0, Vector3(-20, 0, 0))
	assert_eq(skimmer.locomotion.paths, _f.world.paths.for_hover(), "it paths over the sea")
	_move(skimmer, Vector3(20, 0, 0))
	_seconds(10.0)
	assert_almost_eq(skimmer.sim_position().x, 20.0, 1.0)
	assert_eq(_f.world.flood.wading_count, 0, "a hovering unit never wades")


func test_units_caught_wade_out_slowly_take_light_damage_and_are_reported() -> void:
	var caught: Unit = _f.world.spawn_unit(_f.ranger, 0, Vector3(1, 0, 0))
	var health: float = caught.health.current
	_sea(HIGH)
	_seconds(0.6)
	assert_eq(_f.world.flood.wading_count, 1)
	assert_almost_eq(
		caught.locomotion.mover.max_speed, _f.ranger.move_speed * 0.35, 0.01, "it wades"
	)
	assert_false(caught.orders.is_idle(), "an idle unit heads for dry ground by itself")
	assert_eq(_alerts.count(&"units_in_water"), 1, "the player is told")
	_seconds(6.0)
	assert_false(caught.is_dead, "not killed outright")
	assert_gt(absf(caught.sim_position().x), BAND_HALF_WIDTH, "out of the water")
	assert_lt(caught.health.current, health, "it took some damage")
	assert_gt(caught.health.current, health * 0.6, "light damage")
	assert_almost_eq(caught.locomotion.mover.max_speed, _f.ranger.move_speed, 0.01, "full speed")
	_f.world.spawn_unit(_f.ranger, 0, Vector3(-1, 0, 4))
	_seconds(1.0)
	assert_eq(_alerts.count(&"units_in_water"), 1, "not again within the throttle")
	_f.world.spawn_unit(_f.ranger, 1, Vector3(0, 0, -4))
	_seconds(0.6)
	assert_eq(_alerts.count(&"units_in_water"), 1, "enemies in water are no news")


func test_a_unit_with_an_order_caught_in_the_water_gets_out_and_keeps_the_order() -> void:
	var unit: Unit = _f.world.spawn_unit(_f.ranger, 0, Vector3(0, 0, 0))
	# Its goal is further along the channel bed: fine at low water.
	_move(unit, Vector3(0, 0, 30))
	_sea(HIGH)
	_seconds(8.0)
	assert_false(unit.is_dead)
	assert_gt(absf(unit.sim_position().x), BAND_HALF_WIDTH, "it left the water")
	assert_false(unit.orders.is_idle(), "and still means to go there")
	assert_lte(unit.orders.queue.size(), 1, "one way out, not a pile of them")
	var health: float = unit.health.current
	_seconds(5.0)
	assert_almost_eq(unit.health.current, health, 0.01, "no more damage while it waits")
	_sea(LOW)
	_seconds(12.0)
	assert_almost_eq(unit.sim_position().z, 30.0, 1.5, "it goes on once the sea fell")


func test_a_new_world_checks_its_routes_against_the_sea_once() -> void:
	_sea(HIGH)
	_seconds(1.0)
	var unit: Unit = _f.world.spawn_unit(_f.ranger, 0, Vector3(-30, 0, 0))
	_move(unit, Vector3(20, 0, 0))
	# As after a load: the stage already matches, so no switch announces itself.
	_f.world.flood._started = false
	_f.world.flood._replan_at = -1
	_f.world.flood._replan_until = -1
	_f.tick(1)
	assert_gt(_f.world.flood._replan_until, 0, "the routes are checked anyway")


func test_building_on_ground_that_floods_is_refused() -> void:
	var placement: PlacementRules = _f.world.placement_rules()
	assert_eq(
		placement.check(_f.reactor, Vector3(0, 0, 0)), PlacementRules.FLOODS, "even at low water"
	)
	assert_eq(placement.check(_f.reactor, Vector3(-4, 0, 0)), PlacementRules.FLOODS, "touching it")
	assert_eq(placement.check(_f.reactor, Vector3(-20, 0, 0)), PlacementRules.OK)
	assert_eq(PlacementRules.describe(PlacementRules.FLOODS), "The tide floods this ground")
	_f.world.spawn_building(_f.lander, 0, Vector3(-30, 0, 10), true)
	var fabricator: Unit = _f.world.spawn_unit(_f.fabricator, 0, Vector3(-12, 0, 0))
	var place: PlaceBuildingCommand = PlaceBuildingCommand.new(
		0, [fabricator] as Array[Node3D], _f.reactor, Vector3(0, 0, 0)
	)
	_f.push(place)
	_f.tick()
	assert_eq(place.refused, PlacementRules.FLOODS, "the command says why")


func test_haulers_stop_mining_a_flooded_deposit_and_resume_when_it_dries() -> void:
	_f.world.spawn_building(_f.lander, 0, Vector3(-25, 0, 0), true)
	var deposit: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(0, 0, 10))
	var hauler: Unit = _f.world.spawn_unit(_f.hauler, 0, Vector3(-12, 0, 10))
	_f.push(HarvestCommand.new(0, [hauler] as Array[Node3D], deposit))
	for i: int in 100:
		if hauler.harvester.state == Harvester.STATE_MINING:
			break
		_f.tick()
	assert_eq(hauler.harvester.state, Harvester.STATE_MINING)
	_sea(HIGH)
	_seconds(1.0)
	assert_true(deposit.is_flooded, "the sea covers it")
	_seconds(8.0)
	assert_true(
		(
			hauler.harvester.state
			in [Harvester.STATE_TIDE, Harvester.STATE_TO_DOCK, Harvester.STATE_UNLOADING]
		),
		"it stopped mining (%s)" % hauler.harvester.state
	)
	_seconds(10.0)
	assert_eq(hauler.harvester.state, Harvester.STATE_TIDE, "it waits for the sea")
	var at: Vector3 = hauler.sim_position()
	assert_gte(_field.sample(at.x, at.z), HIGH, "on ground the sea never reaches")
	assert_false(hauler.orders.is_idle(), "the harvest order holds")
	var left: int = deposit.remaining
	_seconds(5.0)
	assert_eq(deposit.remaining, left, "nobody mines under water")
	_sea(LOW)
	_seconds(2.0)
	assert_false(deposit.is_flooded)
	_seconds(10.0)
	assert_lt(deposit.remaining, left, "mining again once it is dry")


func test_haulers_move_on_to_a_dry_deposit_when_there_is_one() -> void:
	_f.world.spawn_building(_f.lander, 0, Vector3(-25, 0, 0), true)
	var wet: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(0, 0, 10))
	var dry: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(-15, 0, -12))
	var hauler: Unit = _f.world.spawn_unit(_f.hauler, 0, Vector3(-12, 0, 10))
	_f.push(HarvestCommand.new(0, [hauler] as Array[Node3D], wet))
	_seconds(3.0)
	_sea(HIGH)
	_seconds(20.0)
	assert_eq(hauler.harvester.deposit, dry, "it went elsewhere")
	assert_lt(dry.remaining, dry.def.amount, "and mines there")
	assert_eq(
		_f.world.nearest_deposit(Vector3(0, 0, 10), 5.0), null, "flooded deposits are passed over"
	)
