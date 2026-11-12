class_name WalkGrid
extends RefCounted
## Coarse walkability lookup on an XZ grid, rasterised once from a NavigationMesh. A
## cell is walkable when its centre lies inside a navmesh polygon. Gives O(1) answers
## where a navmesh closest-point query costs time proportional to the polygon count.

## World X/Z of the corner of cell (0, 0).
var origin: Vector2 = Vector2.ZERO
var cell_size: float = 1.0
var columns: int = 0
var rows: int = 0
var cells: PackedByteArray = PackedByteArray()


func _init(
	p_origin: Vector2 = Vector2.ZERO, p_cell_size: float = 1.0, p_columns: int = 0, p_rows: int = 0
) -> void:
	origin = p_origin
	cell_size = p_cell_size
	columns = p_columns
	rows = p_rows
	cells.resize(columns * rows)


## True if (x, z) falls in a walkable cell. Outside the grid is never walkable.
func is_walkable(x: float, z: float) -> bool:
	var column: int = floori((x - origin.x) / cell_size)
	var row: int = floori((z - origin.y) / cell_size)
	if column < 0 or row < 0 or column >= columns or row >= rows:
		return false
	return cells[row * columns + column] != 0


## True if every point on the segment a→b (XZ, sampled once per cell length) is
## walkable. Inlined lookups: this runs for every unit of a group order.
func is_segment_walkable(a: Vector3, b: Vector3) -> bool:
	var dx: float = b.x - a.x
	var dz: float = b.z - a.z
	var steps: int = maxi(1, ceili(sqrt(dx * dx + dz * dz) / cell_size))
	var inverse: float = 1.0 / cell_size
	for i: int in steps + 1:
		var t: float = float(i) / steps
		var column: int = floori((a.x + dx * t - origin.x) * inverse)
		var row: int = floori((a.z + dz * t - origin.y) * inverse)
		if column < 0 or row < 0 or column >= columns or row >= rows:
			return false
		if cells[row * columns + column] == 0:
			return false
	return true


func set_walkable(column: int, row: int, walkable: bool) -> void:
	cells[row * columns + column] = 1 if walkable else 0


## Rasterises the polygons of `navmesh` (convex, as Recast produces) over `area`.
static func from_navmesh(navmesh: NavigationMesh, area: Rect2, p_cell_size: float) -> WalkGrid:
	var grid: WalkGrid = (
		WalkGrid
		. new(
			area.position,
			p_cell_size,
			ceili(area.size.x / p_cell_size),
			ceili(area.size.y / p_cell_size),
		)
	)
	var vertices: PackedVector3Array = navmesh.get_vertices()
	for p: int in navmesh.get_polygon_count():
		var polygon: PackedInt32Array = navmesh.get_polygon(p)
		var outline: PackedVector2Array = PackedVector2Array()
		var low: Vector2 = Vector2(INF, INF)
		var high: Vector2 = Vector2(-INF, -INF)
		for index: int in polygon:
			var point: Vector2 = Vector2(vertices[index].x, vertices[index].z)
			outline.append(point)
			low = low.min(point)
			high = high.max(point)
		var first_column: int = maxi(ceili((low.x - area.position.x) / p_cell_size - 0.5), 0)
		var last_column: int = mini(
			floori((high.x - area.position.x) / p_cell_size - 0.5), grid.columns - 1
		)
		var first_row: int = maxi(ceili((low.y - area.position.y) / p_cell_size - 0.5), 0)
		var last_row: int = mini(
			floori((high.y - area.position.y) / p_cell_size - 0.5), grid.rows - 1
		)
		for row: int in range(first_row, last_row + 1):
			var z: float = area.position.y + (row + 0.5) * p_cell_size
			for column: int in range(first_column, last_column + 1):
				var x: float = area.position.x + (column + 0.5) * p_cell_size
				if Geometry2D.is_point_in_polygon(Vector2(x, z), outline):
					grid.set_walkable(column, row, true)
	return grid
