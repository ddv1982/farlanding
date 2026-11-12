extends GutTest
## The vision grid (charted / explored / visible), its staggered updates, and what
## the player is shown: enemies only in sight, enemy buildings once seen, resource
## nodes once explored.


func test_grid_starts_charted_and_reveal_marks_a_disc() -> void:
	var grid: VisionGrid = VisionGrid.new(Rect2(-50, -50, 100, 100), 2.0)
	assert_eq(grid.columns, 50)
	assert_eq(grid.state_at(0, Vector3.ZERO), VisionGrid.CHARTED)
	grid.begin_update(0)
	grid.reveal(0, Vector3.ZERO, 10.0)
	grid.end_update(0)
	assert_eq(grid.state_at(0, Vector3(0, 0, 0)), VisionGrid.VISIBLE)
	assert_eq(grid.state_at(0, Vector3(9, 0, 0)), VisionGrid.VISIBLE, "inside the radius")
	assert_eq(grid.state_at(0, Vector3(8, 0, 8)), VisionGrid.CHARTED, "outside (11.3 m)")
	assert_eq(grid.state_at(0, Vector3(500, 0, 0)), VisionGrid.CHARTED, "off the map")
	assert_eq(grid.state_at(1, Vector3.ZERO), VisionGrid.CHARTED, "other factions know nothing")
	var lit: int = 0
	var data: PackedByteArray = grid.visible_image(0).get_data()
	for value: int in data:
		lit += 1 if value > 0 else 0
	assert_between(lit, 70, 90, "about pi * 5^2 cells")


func test_seen_cells_stay_explored() -> void:
	var grid: VisionGrid = VisionGrid.new(Rect2(-50, -50, 100, 100), 2.0)
	grid.begin_update(0)
	grid.reveal(0, Vector3(-20, 0, 0), 6.0)
	grid.end_update(0)
	grid.begin_update(0)
	grid.reveal(0, Vector3(20, 0, 0), 6.0)
	grid.end_update(0)
	assert_eq(grid.state_at(0, Vector3(-20, 0, 0)), VisionGrid.EXPLORED)
	assert_eq(grid.state_at(0, Vector3(20, 0, 0)), VisionGrid.VISIBLE)
	assert_true(grid.is_area_explored(0, Rect2(-24, -2, 8, 4)))
	assert_false(grid.is_area_visible(0, Rect2(-24, -2, 8, 4)))


func test_explored_layer_round_trips() -> void:
	var grid: VisionGrid = VisionGrid.new(Rect2(-50, -50, 100, 100), 2.0)
	grid.begin_update(1)
	grid.reveal(1, Vector3(10, 0, 10), 6.0)
	grid.end_update(1)
	var copy: VisionGrid = VisionGrid.new(Rect2(-50, -50, 100, 100), 2.0)
	copy.from_dict(grid.to_dict())
	assert_eq(copy.state_at(1, Vector3(10, 0, 10)), VisionGrid.EXPLORED, "remembered, not seen")


func test_updates_are_staggered_round_robin() -> void:
	var vision: VisionSystem = VisionSystem.new(Rect2(-50, -50, 100, 100), 2.0, 0)
	vision.add_faction(1)
	var updated: Array[int] = []
	vision.updated.connect(func(faction: int) -> void: updated.append(faction))
	var no_units: Array[Unit] = []
	var no_buildings: Array[Building] = []
	for tick: int in range(1, 7):
		vision.tick(tick, no_units, no_buildings)
	assert_eq(updated, [1, 0, 1, 0, 1, 0] as Array[int], "one faction per tick, in turn")


func test_enemies_show_only_in_sight() -> void:
	var f: CombatFixture = CombatFixture.new(self)
	f.world.enable_vision(Rect2(-100, -100, 200, 200), 2.0)
	var scout: Unit = f.spawn(f.scout, 0, Vector3.ZERO)
	var enemy: Unit = f.spawn(f.scout, 1, Vector3(0, 0, -60))
	assert_false(enemy.visible, "hidden from the start")
	f.tick(2)
	assert_false(enemy.is_visible_to_player)
	enemy.locomotion.mover.position = Vector3(0, 0, -20)
	f.tick(2)
	assert_true(enemy.is_visible_to_player, "walked into sight")
	assert_true(enemy.visible)
	assert_true(scout.visible and scout.is_visible_to_player, "own units always shown")
	f.dispose()


func test_enemy_buildings_stay_as_last_seen_and_nodes_show_once_explored() -> void:
	var f: CombatFixture = CombatFixture.new(self)
	f.world.enable_vision(Rect2(-100, -100, 200, 200), 2.0)
	var post: Building = f.world.spawn_building(f.hq, 1, Vector3(0, 0, -50), true)
	var deposit: ResourceNode = f.world.spawn_resource_node(f.base.deposit, Vector3(10, 0, -50))
	assert_false(post.visible, "unknown building hidden")
	assert_false(deposit.visible, "unexplored deposit hidden")
	var scout: Unit = f.spawn(f.scout, 0, Vector3(0, 0, -30))
	f.tick(2)
	assert_true(post.visible and post.is_visible_to_player)
	assert_true(deposit.visible)
	scout.locomotion.mover.position = Vector3(0, 0, 60)
	f.tick(2)
	assert_false(post.is_visible_to_player, "out of sight now")
	assert_true(post.visible, "still shown as last seen")
	assert_true(deposit.visible, "explored nodes stay shown")
	f.dispose()


func test_update_cost_with_a_hundred_units_is_small() -> void:
	var f: CombatFixture = CombatFixture.new(self)
	var vision: VisionSystem = f.world.enable_vision(Rect2(-120, -120, 240, 240), 2.0)
	for i: int in 100:
		var at: Vector3 = Vector3(-100 + (i % 10) * 20.0, 0, -100 + floori(i / 10.0) * 20.0)
		f.spawn(f.soldier, 0, at)
	vision.update_faction(0, f.world.units, f.world.buildings)
	var started: int = Time.get_ticks_usec()
	for i: int in 10:
		vision.update_faction(0, f.world.units, f.world.buildings)
	var per_update: float = (Time.get_ticks_usec() - started) / 10000.0
	gut.p("vision update, 100 spread units: %.2f ms" % per_update)
	assert_lt(per_update, 15.0, "cheap enough for a staggered 10 Hz tick")
	f.dispose()
