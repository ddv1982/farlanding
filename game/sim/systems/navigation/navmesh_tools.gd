class_name NavmeshTools
extends RefCounted
## Offline navmesh helpers: bake from a scene's static colliders and drop
## unreachable islands (mesa tops, cliff rims). Used by the map bake scripts, not at
## runtime.

## Ground-unit navmesh settings shared by every map. The agent radius is the largest
## ground unit's (the Bulwark, 1.75 m), so ramps must be modelled wide enough to
## survive that erosion (see ADR 0004).
const AGENT_RADIUS: float = 1.75
const AGENT_HEIGHT: float = 2.0
const AGENT_MAX_SLOPE: float = 32.0
const AGENT_MAX_CLIMB: float = 0.5


## Returns a new NavigationMesh baked from the static colliders under `root`.
## `root` must be inside the scene tree.
static func bake_from_colliders(root: Node) -> NavigationMesh:
	var navmesh: NavigationMesh = NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	navmesh.agent_radius = AGENT_RADIUS
	navmesh.agent_height = AGENT_HEIGHT
	navmesh.agent_max_slope = AGENT_MAX_SLOPE
	navmesh.agent_max_climb = AGENT_MAX_CLIMB
	navmesh.filter_ledge_spans = true
	navmesh.filter_walkable_low_height_spans = true
	navmesh.detail_sample_distance = 3.0
	navmesh.detail_sample_max_error = 0.25
	navmesh.edge_max_error = 1.0
	navmesh.edge_max_length = 12.0
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, root)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	return navmesh


## Returns a copy of `navmesh` without the polygons that make an edge non-manifold
## (shared by more than two polygons; Recast produces a few on noisy terrain and the
## navigation server rejects them). The smallest polygons on such an edge are dropped.
static func remove_nonmanifold_edges(navmesh: NavigationMesh) -> NavigationMesh:
	var vertices: PackedVector3Array = navmesh.get_vertices()
	var polygon_count: int = navmesh.get_polygon_count()
	var users: Dictionary[Vector2i, PackedInt32Array] = {}
	for p: int in polygon_count:
		var polygon: PackedInt32Array = navmesh.get_polygon(p)
		for k: int in polygon.size():
			var key: Vector2i = _edge_key(polygon[k], polygon[(k + 1) % polygon.size()])
			var list: PackedInt32Array = users.get(key, PackedInt32Array())
			list.append(p)
			users[key] = list
	var dropped: Dictionary[int, bool] = {}
	for key: Vector2i in users:
		var list: PackedInt32Array = users[key]
		if list.size() <= 2:
			continue
		var by_area: Array[int] = []
		for p: int in list:
			by_area.append(p)
		by_area.sort_custom(
			func(a: int, b: int) -> bool:
				return (
					_area(vertices, navmesh.get_polygon(a))
					< _area(vertices, navmesh.get_polygon(b))
				)
		)
		for i: int in by_area.size() - 2:
			dropped[by_area[i]] = true
	var result: NavigationMesh = navmesh.duplicate() as NavigationMesh
	result.clear_polygons()
	for p: int in polygon_count:
		if not dropped.has(p):
			result.add_polygon(navmesh.get_polygon(p))
	return result


## Returns a copy of `navmesh` holding only the polygons connected (through shared
## vertices) to the polygon nearest `keep_point`. Copies the bake settings too.
static func keep_island(navmesh: NavigationMesh, keep_point: Vector3) -> NavigationMesh:
	var vertices: PackedVector3Array = navmesh.get_vertices()
	var polygon_count: int = navmesh.get_polygon_count()
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(vertices.size())
	for i: int in vertices.size():
		parent[i] = i
	for p: int in polygon_count:
		var polygon: PackedInt32Array = navmesh.get_polygon(p)
		for k: int in range(1, polygon.size()):
			_union(parent, polygon[0], polygon[k])
	# Find the island of the polygon whose centre is nearest keep_point.
	var best_root: int = -1
	var best_distance: float = INF
	for p: int in polygon_count:
		var polygon: PackedInt32Array = navmesh.get_polygon(p)
		var centre: Vector3 = Vector3.ZERO
		for index: int in polygon:
			centre += vertices[index]
		centre /= float(polygon.size())
		var distance: float = centre.distance_squared_to(keep_point)
		if distance < best_distance:
			best_distance = distance
			best_root = _find(parent, polygon[0])
	var result: NavigationMesh = navmesh.duplicate() as NavigationMesh
	result.clear_polygons()
	var remap: Dictionary[int, int] = {}
	var kept_vertices: PackedVector3Array = PackedVector3Array()
	for p: int in polygon_count:
		var polygon: PackedInt32Array = navmesh.get_polygon(p)
		if _find(parent, polygon[0]) != best_root:
			continue
		var new_polygon: PackedInt32Array = PackedInt32Array()
		for index: int in polygon:
			if not remap.has(index):
				remap[index] = kept_vertices.size()
				kept_vertices.append(vertices[index])
			new_polygon.append(remap[index])
		result.add_polygon(new_polygon)
	result.set_vertices(kept_vertices)
	return result


static func _edge_key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


static func _area(vertices: PackedVector3Array, polygon: PackedInt32Array) -> float:
	var total: float = 0.0
	for k: int in range(1, polygon.size() - 1):
		var u: Vector3 = vertices[polygon[k]] - vertices[polygon[0]]
		var v: Vector3 = vertices[polygon[k + 1]] - vertices[polygon[0]]
		total += u.cross(v).length() * 0.5
	return total


static func _find(parent: PackedInt32Array, i: int) -> int:
	var root: int = i
	while parent[root] != root:
		root = parent[root]
	while parent[i] != root:
		var next: int = parent[i]
		parent[i] = root
		i = next
	return root


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var root_a: int = _find(parent, a)
	var root_b: int = _find(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a
