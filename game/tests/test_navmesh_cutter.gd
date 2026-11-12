extends GutTest
## NavmeshCutter on a flat grid of square polygons: the cut area disappears, nothing
## overlaps it, and neighbouring polygons stay joined (no T-junctions), which shows
## as the mesh's open boundary being exactly the outer edge plus the hole.

const CELL: float = 5.0
const CELLS: int = 4


## A CELLS x CELLS grid of CELL-metre squares from (0, 0) to (20, 20).
func _grid() -> NavmeshCutter:
	var vertices: PackedVector3Array = PackedVector3Array()
	for row: int in CELLS + 1:
		for column: int in CELLS + 1:
			vertices.append(Vector3(column * CELL, 0.0, row * CELL))
	var polygons: Array[PackedInt32Array] = []
	for row: int in CELLS:
		for column: int in CELLS:
			var a: int = row * (CELLS + 1) + column
			polygons.append(PackedInt32Array([a, a + 1, a + CELLS + 2, a + CELLS + 1]))
	return NavmeshCutter.from_arrays(vertices, polygons)


## Total length of edges used by exactly one polygon; fails the test on an edge
## used by more than two.
func _open_boundary_length(cutter: NavmeshCutter) -> float:
	var users: Dictionary[Vector2i, int] = {}
	for polygon: PackedInt32Array in cutter.polygons:
		for k: int in polygon.size():
			var a: int = polygon[k]
			var b: int = polygon[(k + 1) % polygon.size()]
			var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			users[key] = users.get(key, 0) + 1
	var length: float = 0.0
	for key: Vector2i in users:
		assert_lte(users[key], 2, "edge %s shared by more than two polygons" % key)
		if users[key] == 1:
			length += cutter.vertices[key.x].distance_to(cutter.vertices[key.y])
	return length


func _overlaps(cutter: NavmeshCutter, rect: Rect2) -> bool:
	var inner: Rect2 = rect.grow(-0.01)
	for polygon: PackedInt32Array in cutter.polygons:
		var centre: Vector2 = Vector2.ZERO
		for index: int in polygon:
			centre += Vector2(cutter.vertices[index].x, cutter.vertices[index].z)
		centre /= polygon.size()
		if inner.has_point(centre):
			return true
	return false


func test_the_grid_starts_whole() -> void:
	var cutter: NavmeshCutter = _grid()
	assert_almost_eq(cutter.area(), 400.0, 0.001)
	assert_almost_eq(_open_boundary_length(cutter), 80.0, 0.001)


func test_a_cut_inside_one_polygon_leaves_a_hole_and_stays_joined() -> void:
	var cutter: NavmeshCutter = _grid()
	var hole: Rect2 = Rect2(6, 6, 3, 3)
	cutter.cut(hole)
	assert_almost_eq(cutter.area(), 400.0 - 9.0, 0.01)
	assert_false(_overlaps(cutter, hole))
	assert_almost_eq(_open_boundary_length(cutter), 80.0 + 12.0, 0.01, "outer edge + hole only")


func test_a_cut_across_several_polygons_stays_joined() -> void:
	var cutter: NavmeshCutter = _grid()
	var hole: Rect2 = Rect2(3, 4, 9, 8)
	cutter.cut(hole)
	assert_almost_eq(cutter.area(), 400.0 - 72.0, 0.01)
	assert_false(_overlaps(cutter, hole))
	assert_almost_eq(_open_boundary_length(cutter), 80.0 + 34.0, 0.01)


func test_cuts_add_up_and_a_cut_over_the_edge_trims_the_mesh() -> void:
	var cutter: NavmeshCutter = _grid()
	cutter.cut(Rect2(2, 2, 4, 4))
	cutter.cut(Rect2(12, 12, 4, 4))
	cutter.cut(Rect2(-5, 16, 10, 10))
	assert_almost_eq(cutter.area(), 400.0 - 16.0 - 16.0 - 20.0, 0.01)
	# Trimming the corner swaps 9 m of outer edge for 9 m of new edge.
	assert_almost_eq(_open_boundary_length(cutter), 80.0 + 16.0 + 16.0, 0.01)


func test_a_line_close_to_vertices_snaps_onto_them() -> void:
	var cutter: NavmeshCutter = _grid()
	# x = 5.1 is within SNAP of the grid line x = 5: no 0.1 m slivers are made.
	cutter.cut(Rect2(5.1, 6, 4, 3))
	for polygon: PackedInt32Array in cutter.polygons:
		for k: int in polygon.size():
			var a: Vector3 = cutter.vertices[polygon[k]]
			var b: Vector3 = cutter.vertices[polygon[(k + 1) % polygon.size()]]
			assert_gt(a.distance_to(b), NavmeshCutter.SNAP - 0.01, "no edge shorter than SNAP")
	assert_almost_eq(_open_boundary_length(cutter), 80.0 + 2.0 * (4.1 + 3.0), 0.05)


func test_the_result_converts_to_a_navmesh_with_its_settings() -> void:
	var cutter: NavmeshCutter = _grid()
	cutter.cut(Rect2(6, 6, 3, 3))
	var template: NavigationMesh = NavigationMesh.new()
	template.cell_size = 0.25
	var navmesh: NavigationMesh = cutter.to_navmesh(template)
	assert_eq(navmesh.get_polygon_count(), cutter.polygons.size())
	assert_eq(navmesh.cell_size, 0.25)
	assert_eq(cutter.conflicting_edges(Rect2(-1, -1, 22, 22)), 0)
