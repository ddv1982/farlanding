extends GutTest


func _square_navmesh() -> NavigationMesh:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.set_vertices(
		PackedVector3Array([Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(4, 0, 4), Vector3(0, 0, 4)])
	)
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	return mesh


func test_cells_inside_polygon_are_walkable() -> void:
	var grid: WalkGrid = WalkGrid.from_navmesh(_square_navmesh(), Rect2(-10, -10, 20, 20), 1.0)
	assert_true(grid.is_walkable(0.5, 0.5))
	assert_true(grid.is_walkable(3.5, 3.5))
	assert_false(grid.is_walkable(-0.5, 2.0))
	assert_false(grid.is_walkable(4.5, 2.0))


func test_outside_grid_is_not_walkable() -> void:
	var grid: WalkGrid = WalkGrid.from_navmesh(_square_navmesh(), Rect2(0, 0, 4, 4), 1.0)
	assert_false(grid.is_walkable(50.0, 1.0))
	assert_false(grid.is_walkable(-0.1, 1.0))


func test_segment_inside_is_walkable() -> void:
	var grid: WalkGrid = WalkGrid.from_navmesh(_square_navmesh(), Rect2(-10, -10, 20, 20), 1.0)
	assert_true(grid.is_segment_walkable(Vector3(0.5, 0, 0.5), Vector3(3.5, 0, 3.5)))


func test_segment_leaving_the_mesh_is_not_walkable() -> void:
	var grid: WalkGrid = WalkGrid.from_navmesh(_square_navmesh(), Rect2(-10, -10, 20, 20), 1.0)
	assert_false(grid.is_segment_walkable(Vector3(0.5, 0, 0.5), Vector3(8.5, 0, 0.5)))
