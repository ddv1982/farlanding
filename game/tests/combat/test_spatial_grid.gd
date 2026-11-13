extends GutTest
## The combat grid outlives the entities in it for up to a tick.


func test_a_query_skips_entities_freed_since_the_rebuild() -> void:
	var kept: Node3D = Node3D.new()
	var gone: Node3D = Node3D.new()
	add_child_autofree(kept)
	add_child(gone)
	var grid: SpatialGrid = SpatialGrid.new()
	grid.insert(kept, Vector3(1, 0, 1))
	grid.insert(gone, Vector3(2, 0, 2))
	gone.free()
	var found: Array[Node3D] = grid.query(Vector3.ZERO, 10.0)
	assert_eq(found, [kept] as Array[Node3D])
