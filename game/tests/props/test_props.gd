extends GutTest
## Props are honest cover (ADR 0011): they block movement like a building, block the
## vision grid and watchers' line of sight when tall enough, are never selectable or
## auto-targeted, can be blown apart when destructible (and then stop blocking), and
## save their damage.

var _f: MissionFixture
var _wall: PropDef
var _crates: PropDef
var _kerb: PropDef


func before_each() -> void:
	_f = MissionFixture.new(self)
	_wall = PropDef.new()
	_wall.id = &"wall"
	_wall.size = Vector3(2.0, 3.0, 8.0)
	_crates = PropDef.new()
	_crates.id = &"crates"
	_crates.size = Vector3(3.0, 2.0, 3.0)
	_crates.max_health = 100
	_crates.armour_type = &"light"
	_kerb = PropDef.new()
	_kerb.id = &"kerb"
	_kerb.size = Vector3(2.0, 0.5, 8.0)


func after_each() -> void:
	_f.dispose()


func test_a_prop_blocks_movement_where_it_stands() -> void:
	var prop: Prop = _f.world.spawn_prop(_wall, Vector3(10, 0, 0))
	assert_false(_f.world.paths.is_walkable(Vector3(10, 0, 0)), "cut out like a building")
	assert_false(_f.world.paths.is_walkable(Vector3(10, 0, 3.5)))
	assert_true(_f.world.paths.is_walkable(Vector3(10, 0, 6)), "only its footprint")
	assert_eq(prop.footprint(), Rect2(9, -4, 2, 8))
	var turned: Prop = _f.world.spawn_prop(_wall, Vector3(-20, 0, 0), 1)
	assert_eq(turned.footprint(), Rect2(-24, -1, 8, 2), "a quarter turn swaps width and depth")


func test_a_tall_prop_casts_a_shadow_on_the_vision_grid() -> void:
	_f.discovery.combat.scout.vision_range = 24.0
	_f.spawn(_f.discovery.combat.scout, 0, Vector3.ZERO)
	_f.world.spawn_prop(_wall, Vector3(6, 0, 0))
	_f.tick(2)
	var grid: VisionGrid = _f.world.vision.grid
	assert_false(grid.is_visible(0, Vector3(14, 0, 0)), "behind the wall is hidden")
	assert_true(grid.is_visible(0, Vector3(0, 0, 14)), "the open side is seen")
	assert_true(grid.is_visible(0, Vector3(4, 0, 0)), "in front of it is seen")
	assert_gt(grid.shadowed_discs, 0)


func test_a_low_prop_hides_nothing() -> void:
	_f.discovery.combat.scout.vision_range = 24.0
	_f.spawn(_f.discovery.combat.scout, 0, Vector3.ZERO)
	var kerb: Prop = _f.world.spawn_prop(_kerb, Vector3(6, 0, 0))
	assert_false(kerb.blocks_sight)
	_f.tick(2)
	assert_true(_f.world.vision.grid.is_visible(0, Vector3(14, 0, 0)))


func test_a_guard_cannot_notice_a_wisp_behind_a_prop() -> void:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3(0, 0, 0))
	guard.locomotion.mover.yaw = Mover.yaw_for(Vector3.RIGHT)
	var wisp_def: UnitDef = _f.wisp
	var wisp: Unit = _f.spawn(wisp_def, 0, Vector3(8, 0, 0))
	_f.world.stealth.add_guard_faction(1)
	_f.tick(2)
	var open_rate: float = _f.world.stealth.suspicion_rate(guard, wisp, true)
	assert_gt(open_rate, 0.0, "in the open the guard grows suspicious")
	_f.world.spawn_prop(_wall, Vector3(4, 0, 0))
	_f.tick(2)
	assert_eq(_f.world.stealth.suspicion_rate(guard, wisp, true), 0.0, "the wall hides it")
	assert_false(
		_f.world.stealth.has_line_of_sight(guard.sim_position(), wisp.sim_position()),
		"no line of sight through the prop"
	)


func test_props_are_not_selectable_or_targets() -> void:
	var prop: Prop = _f.world.spawn_prop(_crates, Vector3(5, 0, 0))
	assert_false(prop.is_in_group(Unit.GROUP))
	assert_false(prop.is_in_group(Building.GROUP))
	assert_true(prop.is_in_group(Prop.GROUP), "audio finds props by their group")
	assert_eq(Combat.faction_of(prop), -1)
	assert_false(AttackCommand.is_valid_target(prop, 0))
	_f.spawn(_f.discovery.combat.soldier, 0, Vector3.ZERO)
	_f.tick(30)
	assert_eq(prop.health.current, prop.health.max_health, "nobody shoots it by choice")


func test_splash_blows_a_destructible_prop_apart_and_it_stops_blocking() -> void:
	var prop: Prop = _f.world.spawn_prop(_crates, Vector3(10, 0, 0))
	assert_not_null(prop.health)
	var died: Array[Node3D] = []
	var listen: Callable = func(entity: Node3D) -> void: died.append(entity)
	Events.entity_died.connect(listen)
	assert_eq(_f.world.vision.grid.occluder_count(), 1)
	for shell: int in 4:
		_f.world.combat._impact(_f.discovery.combat.cannon, null, 1, Vector3(10, 0, 0), null)
	Events.entity_died.disconnect(listen)
	assert_true(prop.is_dead, "four shells")
	assert_true(died.has(prop), "announced, so audio can play its death sound")
	assert_true(_f.world.paths.is_walkable(Vector3(10, 0, 0)), "the way is open")
	assert_eq(_f.world.vision.grid.occluder_count(), 0, "and the view")
	var wall: Prop = _f.world.spawn_prop(_wall, Vector3(-10, 0, 0))
	_f.world.combat._impact(_f.discovery.combat.cannon, null, 1, Vector3(-10, 0, 0), null)
	assert_null(wall.health, "an indestructible prop shrugs it off")


func test_prop_damage_is_saved() -> void:
	var prop: Prop = _f.world.spawn_prop(_crates, Vector3(10, 0, 0))
	prop.health.take(40.0, null)
	var saved: Dictionary = _f.world.to_dict()
	prop.health.current = prop.health.max_health
	var saved_props: Dictionary = saved["props"]
	_f.world._props_from_dict(saved_props)
	assert_almost_eq(prop.health.current, 60.0, 0.01)


func test_vision_cells_behind_occluders() -> void:
	var grid: VisionGrid = VisionGrid.new(Rect2(-20, -20, 40, 40), 2.0)
	grid.set_occluders([Rect2(3, -2, 4, 4)] as Array[Rect2])
	var source: Vector2i = grid.cell_of(Vector3(0, 0, 0))
	assert_false(grid.cell_sees(source, grid.cell_of(Vector3(10, 0, 0))))
	assert_true(grid.cell_sees(source, grid.cell_of(Vector3(0, 0, 10))))
	assert_true(grid.cell_sees(source, grid.cell_of(Vector3(4, 0, 0))), "the prop itself")


func test_row_shadows_match_the_exact_cell_test() -> void:
	var grid: VisionGrid = VisionGrid.new(Rect2(-60, -60, 120, 120), 2.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var boxes: Array[Rect2] = []
	for i: int in 4:
		var at: Vector2 = Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		boxes.append(Rect2(at, Vector2(rng.randf_range(1, 6), rng.randf_range(1, 6))))
	grid.set_occluders(boxes)
	var cells: int = 0
	var mismatches: int = 0
	for trial: int in 12:
		var cell: Vector2i = grid.cell_of(
			Vector3(rng.randf_range(-24, 24), 0, rng.randf_range(-24, 24))
		)
		var quarters: int = 88
		var key: int = (cell.y * grid.columns + cell.x) * 4096 + quarters
		var seen: Dictionary[Vector2i, bool] = {}
		for entry: Variant in grid._spans_at(key, cell, quarters):
			var span: Rect2i = entry
			for dx: int in span.size.x:
				seen[cell + span.position + Vector2i(dx, 0)] = true
		var reach: int = quarters / 4
		for dz: int in range(-reach, reach + 1):
			var half: int = floori(sqrt(maxf(reach * reach - dz * dz, 0.0)))
			for dx: int in range(-half, half + 1):
				var other: Vector2i = cell + Vector2i(dx, dz)
				cells += 1
				if seen.has(other) != grid.cell_sees(cell, other):
					mismatches += 1

	assert_gt(cells, 1000)
	assert_lt(float(mismatches) / cells, 0.01, "%d of %d cells differ" % [mismatches, cells])
