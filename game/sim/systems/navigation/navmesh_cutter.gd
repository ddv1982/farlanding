class_name NavmeshCutter
extends RefCounted
## Cuts axis-aligned rectangles (building footprints grown by the agent radius) out of
## a baked navigation mesh, at runtime and in a few milliseconds, instead of
## re-baking (see ADR 0006).
##
## Every convex polygon that overlaps a rectangle is replaced by up to four convex
## pieces: the parts left of, right of, below and above the rectangle (clipped with
## axis-aligned half-planes, so no piece ever has a hole). New points are then
## inserted into the edges of every neighbouring polygon they lie on, so no
## T-junction breaks the connection between polygons. Points closer to a cut line
## than SNAP count as lying on it, so the cut makes no slivers.
##
## The navigation server joins polygons by rasterising edge end points to its cell
## size and refuses an edge that more than two polygons claim. Baked meshes on rough
## ground have slightly overlapping polygons, so a cut line can drop two new points
## into one cell. Every cut is therefore checked around the rectangle with the same
## rasterisation, and retried with the rectangle grown by a few centimetres
## (OFFSETS) until it adds no such edge.

## Vertices this close to a cut line (metres, XZ) are treated as on the line.
const SNAP: float = 0.3
## Pieces smaller than this (square metres) are dropped.
const MIN_AREA: float = 0.05
## Distance from an edge at which a point counts as lying on it.
const ON_EDGE: float = 0.02
## Rectangle growths (metres) tried in turn until a cut adds no conflicting edge.
const OFFSETS: PackedFloat32Array = [0.0, 0.11, -0.07, 0.19, 0.27, -0.13, 0.35, 0.43]

var vertices: PackedVector3Array = PackedVector3Array()
var polygons: Array[PackedInt32Array] = []
## Rasterisation the navigation server uses to join edges (cell size, cell height).
var cell_size: float = 0.25
var cell_height: float = 0.25
## Growth used by the last cut (one of OFFSETS), and how many conflicting edges it
## added (0 unless every offset failed).
var last_offset: float = 0.0
var last_conflicts: int = 0

var _boxes: Array[Rect2] = []
var _new_vertices: PackedInt32Array = PackedInt32Array()
## New crossing points by (edge, cut line), so neighbours share them exactly.
var _crossings: Dictionary[String, int] = {}
## The edge each new vertex lies on, as (start, end) indices of the longest edge of
## the mesh before this cut that holds it (or of the cut segment it was made on).
var _roots: Dictionary[int, Vector2i] = {}


func _init(navmesh: NavigationMesh = null) -> void:
	if navmesh == null:
		return
	cell_size = navmesh.cell_size
	cell_height = navmesh.cell_height
	vertices = navmesh.get_vertices()
	for p: int in navmesh.get_polygon_count():
		polygons.append(navmesh.get_polygon(p))
	_rebuild_boxes()


## A cutter over the given vertices and polygons (tests).
static func from_arrays(
	p_vertices: PackedVector3Array, p_polygons: Array[PackedInt32Array]
) -> NavmeshCutter:
	var cutter: NavmeshCutter = NavmeshCutter.new()
	cutter.vertices = p_vertices
	cutter.polygons = p_polygons.duplicate()
	cutter._rebuild_boxes()
	return cutter


## Removes the area of `rect` (world X/Z) from the mesh, grown by the first offset
## that adds no conflicting edge.
func cut(rect: Rect2) -> void:
	var check_area: Rect2 = rect.grow(OFFSETS[OFFSETS.size() - 1] + 2.0)
	var before: int = conflicting_edges(check_area)
	var best_conflicts: int = -1
	var best: Array = []
	for offset: float in OFFSETS:
		var saved: Array = [vertices.duplicate(), polygons.duplicate(), _boxes.duplicate()]
		_cut_once(rect.grow(offset))
		var added: int = maxi(conflicting_edges(check_area) - before, 0)
		if added == 0:
			last_offset = offset
			last_conflicts = 0
			return
		if best_conflicts < 0 or added < best_conflicts:
			best_conflicts = added
			best = [vertices, polygons, _boxes, offset]
		vertices = saved[0]
		polygons = saved[1]
		_boxes = saved[2]
	vertices = best[0]
	polygons = best[1]
	_boxes = best[2]
	last_offset = best[3]
	last_conflicts = best_conflicts


## Edges in `area` that the navigation server would refuse: more than two polygons
## on one rasterised edge (an edge with both ends in one cell is skipped, as the
## server does).
func conflicting_edges(area: Rect2) -> int:
	var users: Dictionary[String, int] = {}
	var conflicts: int = 0
	for p: int in polygons.size():
		if not _boxes[p].intersects(area, true):
			continue
		var polygon: PackedInt32Array = polygons[p]
		var count: int = polygon.size()
		for k: int in count:
			var a: Vector3i = _cell_of(vertices[polygon[k]])
			var b: Vector3i = _cell_of(vertices[polygon[(k + 1) % count]])
			if a == b:
				continue
			var key: String = str(a) + str(b) if str(a) < str(b) else str(b) + str(a)
			var used: int = users.get(key, 0) + 1
			users[key] = used
			if used == 3:
				conflicts += 1
	return conflicts


func _cut_once(rect: Rect2) -> void:
	_new_vertices = PackedInt32Array()
	_crossings.clear()
	_roots.clear()
	var kept: Array[PackedInt32Array] = []
	var kept_boxes: Array[Rect2] = []
	var pieces: Array[PackedInt32Array] = []
	for p: int in polygons.size():
		var polygon: PackedInt32Array = polygons[p]
		if not _boxes[p].intersects(rect) or not _overlaps(polygon, rect):
			kept.append(polygon)
			kept_boxes.append(_boxes[p])
			continue
		pieces.append_array(_split(polygon, rect))
	if pieces.is_empty() and _new_vertices.is_empty() and kept.size() == polygons.size():
		return
	var first_piece: int = kept.size()
	polygons = kept
	_boxes = kept_boxes
	for piece: PackedInt32Array in pieces:
		polygons.append(piece)
		_boxes.append(_box_of(piece))
	_repair_t_junctions(first_piece)


## Total XZ area of the mesh, in square metres.
func area() -> float:
	var total: float = 0.0
	for polygon: PackedInt32Array in polygons:
		total += absf(_signed_area(polygon))
	return total


## A copy of `template` (bake settings kept) holding this cutter's mesh, with unused
## vertices dropped.
func to_navmesh(template: NavigationMesh) -> NavigationMesh:
	var result: NavigationMesh = template.duplicate() as NavigationMesh
	result.clear_polygons()
	var remap: PackedInt32Array = PackedInt32Array()
	remap.resize(vertices.size())
	remap.fill(-1)
	var used: PackedVector3Array = PackedVector3Array()
	for polygon: PackedInt32Array in polygons:
		for index: int in polygon:
			if remap[index] == -1:
				remap[index] = used.size()
				used.append(vertices[index])
	result.set_vertices(used)
	for polygon: PackedInt32Array in polygons:
		var mapped: PackedInt32Array = PackedInt32Array()
		for index: int in polygon:
			mapped.append(remap[index])
		result.add_polygon(mapped)
	return result


## The pieces of convex `polygon` outside `rect`.
func _split(polygon: PackedInt32Array, rect: Rect2) -> Array[PackedInt32Array]:
	var x0: float = rect.position.x
	var x1: float = rect.end.x
	var z0: float = rect.position.y
	var z1: float = rect.end.y
	var result: Array[PackedInt32Array] = []
	# Half-plane `sign * (coordinate - value) <= 0` is kept; axis 0 = x, 2 = z.
	_add_piece(result, _clip(polygon, 0, x0, 1.0))
	_add_piece(result, _clip(polygon, 0, x1, -1.0))
	var strip: PackedInt32Array = _clip(_clip(polygon, 0, x0, -1.0), 0, x1, 1.0)
	_add_piece(result, _clip(strip, 2, z0, 1.0))
	_add_piece(result, _clip(strip, 2, z1, -1.0))
	return result


func _add_piece(result: Array[PackedInt32Array], piece: PackedInt32Array) -> void:
	if piece.size() >= 3 and absf(_signed_area(piece)) >= MIN_AREA:
		result.append(piece)


## Sutherland-Hodgman clip of a convex polygon by one axis-aligned half-plane.
func _clip(polygon: PackedInt32Array, axis: int, value: float, sign: float) -> PackedInt32Array:
	var count: int = polygon.size()
	var out: PackedInt32Array = PackedInt32Array()
	if count < 3:
		return out
	var distances: PackedFloat32Array = PackedFloat32Array()
	distances.resize(count)
	for i: int in count:
		var distance: float = sign * (vertices[polygon[i]][axis] - value)
		distances[i] = 0.0 if absf(distance) <= SNAP else distance
	for i: int in count:
		var j: int = (i + 1) % count
		var a: int = polygon[i]
		var da: float = distances[i]
		var db: float = distances[j]
		if da <= 0.0:
			out.append(a)
		if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
			out.append(_crossing(a, polygon[j], da / (da - db), axis, value))
	return _without_repeats(out)


## The vertex where edge a-b crosses the cut line `axis` = `value` at `t` from a;
## the same edge and line always give the same vertex.
func _crossing(a: int, b: int, t: float, axis: int, value: float) -> int:
	# Keyed by the root edge: the same point is also reached through part-edges.
	var root: Vector2i = _root_of(a, b)
	var key: String = "%d:%d:%d:%f" % [root.x, root.y, axis, value]
	if _crossings.has(key):
		return _crossings[key]
	var point: Vector3 = vertices[a].lerp(vertices[b], t)
	point[axis] = value
	vertices.append(point)
	var index: int = vertices.size() - 1
	_new_vertices.append(index)
	_crossings[key] = index
	_roots[index] = root
	return index


## The edge that segment a-b is part of: the edge of the mesh before this cut
## that holds both ends, or the segment itself.
func _root_of(a: int, b: int) -> Vector2i:
	var root_a: Vector2i = _roots.get(a, Vector2i(-1, -1))
	var root_b: Vector2i = _roots.get(b, Vector2i(-1, -1))
	if root_a.x >= 0 and (root_a == root_b or b == root_a.x or b == root_a.y):
		return root_a
	if root_b.x >= 0 and (a == root_b.x or a == root_b.y):
		return root_b
	return Vector2i(mini(a, b), maxi(a, b))


func _cell_of(point: Vector3) -> Vector3i:
	return Vector3i(
		floori(point.x / cell_size), floori(point.y / cell_height), floori(point.z / cell_size)
	)


## Inserts every new vertex into the edges it lies on, for the new pieces (from
## `first_piece` on) and for every other polygon whose box holds a new vertex.
func _repair_t_junctions(first_piece: int) -> void:
	if _new_vertices.is_empty():
		return
	var area_box: Rect2 = Rect2(vertices[_new_vertices[0]].x, vertices[_new_vertices[0]].z, 0, 0)
	for index: int in _new_vertices:
		area_box = area_box.expand(Vector2(vertices[index].x, vertices[index].z))
	area_box = area_box.grow(ON_EDGE * 2.0)
	for p: int in polygons.size():
		if p < first_piece and not _boxes[p].intersects(area_box, true):
			continue
		var repaired: PackedInt32Array = _with_points_on_edges(polygons[p], _boxes[p])
		if repaired.size() != polygons[p].size():
			polygons[p] = repaired


func _with_points_on_edges(polygon: PackedInt32Array, box: Rect2) -> PackedInt32Array:
	var grown: Rect2 = box.grow(ON_EDGE * 2.0)
	var candidates: PackedInt32Array = PackedInt32Array()
	for index: int in _new_vertices:
		if grown.has_point(Vector2(vertices[index].x, vertices[index].z)):
			candidates.append(index)
	if candidates.is_empty():
		return polygon
	var out: PackedInt32Array = PackedInt32Array()
	var count: int = polygon.size()
	for i: int in count:
		var a: int = polygon[i]
		var b: int = polygon[(i + 1) % count]
		out.append(a)
		var on_edge: Array[Vector2] = []  # (t, index)
		var start: Vector2 = Vector2(vertices[a].x, vertices[a].z)
		var end: Vector2 = Vector2(vertices[b].x, vertices[b].z)
		var edge: Vector2 = end - start
		var length_squared: float = edge.length_squared()
		if length_squared < 1e-8:
			continue
		var root: Vector2i = _root_of(a, b)
		for index: int in candidates:
			if index == a or index == b or polygon.has(index):
				continue
			if _roots[index] != root:
				continue
			var point: Vector2 = Vector2(vertices[index].x, vertices[index].z)
			var t: float = (point - start).dot(edge) / length_squared
			if t <= 1e-4 or t >= 1.0 - 1e-4:
				continue
			if (start + edge * t).distance_to(point) <= ON_EDGE:
				on_edge.append(Vector2(t, index))
		on_edge.sort_custom(func(u: Vector2, v: Vector2) -> bool: return u.x < v.x)
		for entry: Vector2 in on_edge:
			out.append(int(entry.y))
	return out


## True if convex `polygon` and `rect` share some area (not just an edge):
## separating-axis test on the polygon's edge normals (the box test already covered
## the rectangle's axes).
func _overlaps(polygon: PackedInt32Array, rect: Rect2) -> bool:
	var inner: Rect2 = rect.grow(-SNAP)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return false
	var corners: Array[Vector2] = [
		inner.position,
		Vector2(inner.end.x, inner.position.y),
		inner.end,
		Vector2(inner.position.x, inner.end.y),
	]
	var winding: float = signf(_signed_area(polygon))
	var count: int = polygon.size()
	for i: int in count:
		var a: Vector3 = vertices[polygon[i]]
		var b: Vector3 = vertices[polygon[(i + 1) % count]]
		var edge: Vector2 = Vector2(b.x - a.x, b.z - a.z)
		var all_outside: bool = true
		for corner: Vector2 in corners:
			var cross: float = edge.cross(corner - Vector2(a.x, a.z))
			if cross * winding > 0.0:
				all_outside = false
				break
		if all_outside:
			return false
	return true


func _rebuild_boxes() -> void:
	_boxes.clear()
	for polygon: PackedInt32Array in polygons:
		_boxes.append(_box_of(polygon))


func _box_of(polygon: PackedInt32Array) -> Rect2:
	var first: Vector3 = vertices[polygon[0]]
	var box: Rect2 = Rect2(first.x, first.z, 0.0, 0.0)
	for index: int in polygon:
		box = box.expand(Vector2(vertices[index].x, vertices[index].z))
	return box


func _signed_area(polygon: PackedInt32Array) -> float:
	var total: float = 0.0
	var count: int = polygon.size()
	for i: int in count:
		var a: Vector3 = vertices[polygon[i]]
		var b: Vector3 = vertices[polygon[(i + 1) % count]]
		total += a.x * b.z - b.x * a.z
	return total * 0.5


## Drops repeated indices (welding can map two points onto one vertex).
static func _without_repeats(polygon: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for index: int in polygon:
		if not out.has(index):
			out.append(index)
	return out
