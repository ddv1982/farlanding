extends GutTest


## Two separate quads: one around the origin, one far away.
func _two_islands() -> NavigationMesh:
	var mesh: NavigationMesh = NavigationMesh.new()
	(
		mesh
		. set_vertices(
			PackedVector3Array(
				[
					Vector3(-1, 0, -1),
					Vector3(1, 0, -1),
					Vector3(1, 0, 1),
					Vector3(-1, 0, 1),
					Vector3(50, 0, 50),
					Vector3(52, 0, 50),
					Vector3(52, 0, 52),
					Vector3(50, 0, 52),
				]
			)
		)
	)
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	mesh.add_polygon(PackedInt32Array([4, 5, 6, 7]))
	return mesh


func test_keep_island_drops_disconnected_polygons() -> void:
	var kept: NavigationMesh = NavmeshTools.keep_island(_two_islands(), Vector3.ZERO)
	assert_eq(kept.get_polygon_count(), 1)
	assert_eq(kept.get_vertices().size(), 4)
	assert_eq(kept.get_vertices()[0], Vector3(-1, 0, -1))


func test_keep_island_picks_island_near_point() -> void:
	var kept: NavigationMesh = NavmeshTools.keep_island(_two_islands(), Vector3(51, 0, 51))
	assert_eq(kept.get_polygon_count(), 1)
	assert_eq(kept.get_vertices()[0], Vector3(50, 0, 50))


func test_remove_nonmanifold_edges_drops_smallest() -> void:
	var mesh: NavigationMesh = NavigationMesh.new()
	# Edge 0-1 shared by three triangles; the tiny one goes.
	mesh.set_vertices(
		PackedVector3Array(
			[
				Vector3(0, 0, 0),
				Vector3(2, 0, 0),
				Vector3(1, 0, 2),
				Vector3(1, 0, -2),
				Vector3(1, 0, 0.1)
			]
		)
	)
	mesh.add_polygon(PackedInt32Array([0, 1, 2]))
	mesh.add_polygon(PackedInt32Array([1, 0, 3]))
	mesh.add_polygon(PackedInt32Array([0, 1, 4]))
	var cleaned: NavigationMesh = NavmeshTools.remove_nonmanifold_edges(mesh)
	assert_eq(cleaned.get_polygon_count(), 2)
	assert_eq(cleaned.get_polygon(0), PackedInt32Array([0, 1, 2]))
	assert_eq(cleaned.get_polygon(1), PackedInt32Array([1, 0, 3]))
