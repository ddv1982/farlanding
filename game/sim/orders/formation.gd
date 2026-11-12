class_name Formation
extends RefCounted
## Slots for a group arriving at one point: a block of rows facing the travel
## direction, wider than deep, centred on the target. Slots that are not walkable
## (inside a mesa, past a cliff) are replaced by the nearest free walkable points of
## the same grid, so the group wraps around obstacles instead of piling up on them.
## `assign()` gives each unit a slot so that paths do not cross: the front-most units
## take the front row, and within a row units keep their left-to-right order.

## Gap between neighbouring bodies, in metres.
const GAP: float = 1.0

## Slot positions, front row first, each row left to right.
var slots: PackedVector3Array = PackedVector3Array()
## Number of slots in each row, front row first.
var row_sizes: PackedInt32Array = PackedInt32Array()
var forward: Vector3 = Vector3.FORWARD
var right: Vector3 = Vector3.RIGHT


## `walkable` is an optional `func(point: Vector3) -> bool`.
func _init(
	count: int = 0,
	center: Vector3 = Vector3.ZERO,
	p_forward: Vector3 = Vector3.FORWARD,
	spacing: float = 2.0,
	walkable: Callable = Callable(),
) -> void:
	forward = Vector3(p_forward.x, 0.0, p_forward.z)
	forward = forward.normalized() if forward.length_squared() > 1e-6 else Vector3.FORWARD
	right = forward.cross(Vector3.UP)
	if count <= 0:
		return
	# Every slot is a point (row, column) on one lattice; row 0 is the front.
	var columns: int = mini(count, ceili(sqrt(count * 2.0)))
	var rows: int = ceili(float(count) / columns)
	var cells: Array[Vector2i] = []
	for row: int in rows - 1:
		for column: int in columns:
			cells.append(Vector2i(row, column))
	# The last row may be short: fill it from the middle outwards.
	var middle: float = (columns - 1) * 0.5
	var last_columns: Array[int] = []
	for column: int in columns:
		last_columns.append(column)
	last_columns.sort_custom(
		func(a: int, b: int) -> bool:
			return (
				absf(a - middle) < absf(b - middle)
				or (absf(a - middle) == absf(b - middle) and a < b)
			)
	)
	for k: int in count - (rows - 1) * columns:
		cells.append(Vector2i(rows - 1, last_columns[k]))
	# Origin of the lattice so that the ideal block's centroid is the target.
	var mean: Vector2 = Vector2.ZERO
	for cell: Vector2i in cells:
		mean += Vector2(cell)
	mean /= float(count)
	var origin: Vector3 = center - _offset(mean.x, mean.y, spacing)
	if walkable.is_valid():
		cells = _walkable_cells(cells, rows, columns, origin, center, spacing, walkable)
	cells.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y)
	)
	var current_row: int = -1
	for cell: Vector2i in cells:
		# Rows can be negative (replacement cells ahead of the block), so no row
		# number is safe as a "none yet" marker.
		if row_sizes.is_empty() or cell.x != current_row:
			current_row = cell.x
			row_sizes.append(0)
		row_sizes[row_sizes.size() - 1] += 1
		slots.append(origin + _offset(cell.x, cell.y, spacing))


## Spacing for a group: the widest body plus a gap.
static func spacing_for(radii: PackedFloat32Array) -> float:
	var widest: float = 0.5
	for value: float in radii:
		widest = maxf(widest, value)
	return widest * 2.0 + GAP


## Returns, for each position in `positions`, the index of its slot. Every slot is used
## once; `positions.size()` must equal `slots.size()`.
func assign(positions: PackedVector3Array) -> PackedInt32Array:
	assert(positions.size() == slots.size(), "One position per slot")
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(positions.size())
	var by_depth: Array[int] = []
	for i: int in positions.size():
		by_depth.append(i)
	by_depth.sort_custom(
		func(a: int, b: int) -> bool: return forward.dot(positions[a]) > forward.dot(positions[b])
	)
	var first_slot: int = 0
	for size: int in row_sizes:
		var row_units: Array[int] = by_depth.slice(first_slot, first_slot + size)
		row_units.sort_custom(
			func(a: int, b: int) -> bool: return right.dot(positions[a]) < right.dot(positions[b])
		)
		for k: int in size:
			result[row_units[k]] = first_slot + k
		first_slot += size
	return result


func _offset(row: float, column: float, spacing: float) -> Vector3:
	return (-forward * row + right * column) * spacing


## Keeps the walkable cells of the ideal block and replaces the others with the free
## walkable lattice cells nearest the target. May return fewer cells than asked for
## when the area around the target is almost entirely blocked; the rest then keep
## their (unwalkable) ideal cells and their paths end at the nearest reachable point.
func _walkable_cells(
	ideal: Array[Vector2i],
	rows: int,
	columns: int,
	origin: Vector3,
	center: Vector3,
	spacing: float,
	walkable: Callable,
) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	for cell: Vector2i in ideal:
		var ok: bool = walkable.call(origin + _offset(cell.x, cell.y, spacing))
		if ok:
			kept.append(cell)
		else:
			blocked.append(cell)
	if blocked.is_empty():
		return ideal
	var reach: int = maxi(3, ceili(sqrt(float(ideal.size()))))
	var taken: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in kept:
		taken[cell] = true
	var candidates: Array[Vector2i] = []
	for row: int in range(-reach, rows + reach):
		for column: int in range(-reach, columns + reach):
			var cell: Vector2i = Vector2i(row, column)
			if not taken.has(cell):
				candidates.append(cell)
	var distance_of: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in candidates:
		distance_of[cell] = (origin + _offset(cell.x, cell.y, spacing)).distance_squared_to(center)
	candidates.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return distance_of[a] < distance_of[b]
	)
	var needed: int = blocked.size()
	for cell: Vector2i in candidates:
		if needed == 0:
			break
		var ok: bool = walkable.call(origin + _offset(cell.x, cell.y, spacing))
		if ok:
			kept.append(cell)
			needed -= 1
	for k: int in needed:
		kept.append(blocked[k])
	return kept
