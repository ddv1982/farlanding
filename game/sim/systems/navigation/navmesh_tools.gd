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
## clip_navmesh(): a crossing this close (metres, XZ) to an end point uses the end point.
const CLIP_SNAP: float = 0.15
## clip_navmesh(): pieces smaller than this (square metres) are dropped.
const CLIP_MIN_AREA: float = 0.05


## Returns a new NavigationMesh baked from the static colliders under `root`.
## `root` must be inside the scene tree. Ground lower than `clip_below` is cut away
## before the bake (a tidal map's flood stage, ADR 0014): the mesh then ends, eroded
## by the agent radius as at any edge, where the terrain crosses that height.
static func bake_from_colliders(root: Node, clip_below: float = -INF) -> NavigationMesh:
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
	if clip_below > -INF:
		clip_source(source, clip_below)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	return navmesh


## Cuts every source triangle down to its part at or above `height` (triangles wholly
## below are dropped, those crossing it are clipped and fanned again).
static func clip_source(source: NavigationMeshSourceGeometryData3D, height: float) -> void:
	var vertices: PackedFloat32Array = source.get_vertices()
	var indices: PackedInt32Array = source.get_indices()
	var out_vertices: PackedFloat32Array = PackedFloat32Array()
	var out_indices: PackedInt32Array = PackedInt32Array()
	for t: int in range(0, indices.size(), 3):
		var corners: Array[Vector3] = []
		for k: int in 3:
			var i: int = indices[t + k] * 3
			corners.append(Vector3(vertices[i], vertices[i + 1], vertices[i + 2]))
		var kept: Array[Vector3] = _clip_polygon(corners, height)
		if kept.size() < 3:
			continue
		var first: int = out_vertices.size() / 3
		for point: Vector3 in kept:
			out_vertices.append_array(PackedFloat32Array([point.x, point.y, point.z]))
		for k: int in range(1, kept.size() - 1):
			out_indices.append_array(PackedInt32Array([first, first + k, first + k + 1]))
	source.set_vertices(out_vertices)
	source.set_indices(out_indices)


## The part of the convex polygon `points` at or above `height` (Sutherland-Hodgman).
static func _clip_polygon(points: Array[Vector3], height: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for k: int in points.size():
		var a: Vector3 = points[k]
		var b: Vector3 = points[(k + 1) % points.size()]
		var a_in: bool = a.y >= height
		var b_in: bool = b.y >= height
		if a_in:
			result.append(a)
		if a_in != b_in:
			result.append(a.lerp(b, (height - a.y) / (b.y - a.y)))
	return result


## Returns a copy of `navmesh` cut down to where the terrain (`ground`, a HeightField)
## is at or above `height` (a tidal map's higher flood stage, derived from the
## low-water stage; the navmesh itself floats some decimetres above the terrain, so
## the terrain is what is compared). Every polygon is clipped where its edges cross
## that height; neighbours share the new points, so the mesh stays joined edge to
## edge. A crossing within CLIP_SNAP of an end point uses that point instead (no
## near-duplicate vertices for the navigation server to reject).
static func clip_navmesh(
	navmesh: NavigationMesh, height: float, ground: HeightField
) -> NavigationMesh:
	var vertices: PackedVector3Array = navmesh.get_vertices()
	var above: PackedFloat32Array = PackedFloat32Array()
	for vertex: Vector3 in vertices:
		above.append(ground.sample(vertex.x, vertex.z) - height)
	var crossings: Dictionary[Vector2i, int] = {}
	var polygons: Array[PackedInt32Array] = []
	for p: int in navmesh.get_polygon_count():
		var polygon: PackedInt32Array = navmesh.get_polygon(p)
		var kept: PackedInt32Array = PackedInt32Array()
		for k: int in polygon.size():
			var a: int = polygon[k]
			var b: int = polygon[(k + 1) % polygon.size()]
			var a_in: bool = above[a] >= 0.0
			if a_in:
				_append_once(kept, a)
			if a_in == (above[b] >= 0.0):
				continue
			var key: Vector2i = _edge_key(a, b)
			if not crossings.has(key):
				var from: Vector3 = vertices[key.x]
				var to: Vector3 = vertices[key.y]
				var point: Vector3 = from.lerp(to, above[key.x] / (above[key.x] - above[key.y]))
				if Vector2(point.x - from.x, point.z - from.z).length() <= CLIP_SNAP:
					crossings[key] = key.x
				elif Vector2(point.x - to.x, point.z - to.z).length() <= CLIP_SNAP:
					crossings[key] = key.y
				else:
					crossings[key] = vertices.size()
					vertices.append(point)
			_append_once(kept, crossings[key])
		if kept.size() > 1 and kept[0] == kept[kept.size() - 1]:
			kept.remove_at(kept.size() - 1)
		if kept.size() >= 3 and _area(vertices, kept) > CLIP_MIN_AREA:
			polygons.append(kept)
	var result: NavigationMesh = navmesh.duplicate() as NavigationMesh
	result.clear_polygons()
	var remap: Dictionary[int, int] = {}
	var used: PackedVector3Array = PackedVector3Array()
	for polygon: PackedInt32Array in polygons:
		var mapped: PackedInt32Array = PackedInt32Array()
		for index: int in polygon:
			if not remap.has(index):
				remap[index] = used.size()
				used.append(vertices[index])
			mapped.append(remap[index])
		result.add_polygon(mapped)
	result.set_vertices(used)
	return result


## Returns a copy of `navmesh` without the polygons that make an edge non-manifold
## (shared by more than two polygons; Recast produces a few on noisy terrain and the
## navigation server rejects them). The smallest polygons on such an edge are dropped.
## With `merge_scale` > 0, edges are compared the way the navigation server joins them:
## by their end points rasterised to the navmesh's cell size times that scale (the
## map's merge rasteriser scale, 0.1), so nearly coincident vertices count as one.
static func remove_nonmanifold_edges(
	navmesh: NavigationMesh, merge_scale: float = 0.0
) -> NavigationMesh:
	var vertices: PackedVector3Array = navmesh.get_vertices()
	var polygon_count: int = navmesh.get_polygon_count()
	var point_ids: PackedInt32Array = _point_ids(navmesh, merge_scale)
	var users: Dictionary[Vector2i, PackedInt32Array] = {}
	for p: int in polygon_count:
		var polygon: PackedInt32Array = navmesh.get_polygon(p)
		for k: int in polygon.size():
			var a: int = point_ids[polygon[k]]
			var b: int = point_ids[polygon[(k + 1) % polygon.size()]]
			if a == b:
				continue
			var key: Vector2i = _edge_key(a, b)
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


## Per vertex: an id shared by the vertices that rasterise to the same cell at
## `merge_scale` (0: every vertex its own id).
static func _point_ids(navmesh: NavigationMesh, merge_scale: float) -> PackedInt32Array:
	var vertices: PackedVector3Array = navmesh.get_vertices()
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(vertices.size())
	if merge_scale <= 0.0:
		for i: int in vertices.size():
			ids[i] = i
		return ids
	var cell: Vector3 = (
		Vector3(navmesh.cell_size, navmesh.cell_height, navmesh.cell_size) * merge_scale
	)
	var by_cell: Dictionary[Vector3i, int] = {}
	for i: int in vertices.size():
		var key: Vector3i = Vector3i((vertices[i] / cell).floor())
		if not by_cell.has(key):
			by_cell[key] = by_cell.size()
		ids[i] = by_cell[key]
	return ids


static func _append_once(polygon: PackedInt32Array, index: int) -> void:
	if polygon.is_empty() or polygon[polygon.size() - 1] != index:
		polygon.append(index)


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
