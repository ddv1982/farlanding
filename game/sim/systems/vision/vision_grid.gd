class_name VisionGrid
extends RefCounted
## Per-faction knowledge of the map on a square cell grid (PLAN 3.4). Each cell is
## CHARTED (never seen: terrain shape only), EXPLORED (seen before) or VISIBLE (in
## sight now). A faction's update clears its visible layer, stamps a disc for every
## sight source with `reveal()` and ends with `end_update()`. Discs are drawn as
## horizontal spans with Image.fill_rect (native), sources that share a cell and
## radius are stamped once, and the explored layer skips any disc it already holds,
## so an update costs a few native calls per distinct source.
##
## Occluders (props that block sight, ADR 0011) cast shadows: a disc that reaches one
## is stamped as the runs of cells whose centre the source can see (a segment test
## per cell against the nearby occluders), cached per source cell and radius until
## the occluders change. Discs that reach no occluder stay on the fast path.

const CHARTED: int = 0
const EXPLORED: int = 1
const VISIBLE: int = 2
const SAVE_VERSION: int = 1
## Occluder bucket side, in cells.
const BUCKET_CELLS: int = 8
## Shadowed discs kept; the cache is cleared beyond this.
const MAX_OCCLUDED_CACHE: int = 20000

## World X/Z area covered.
var area: Rect2
var cell_size: float = 2.0
var columns: int = 1
var rows: int = 1
## Discs drawn with shadows since the occluders last changed (tests, profiling).
var shadowed_discs: int = 0

var _visible: Dictionary[int, Image] = {}
var _explored: Dictionary[int, Image] = {}
var _visible_bytes: Dictionary[int, PackedByteArray] = {}
var _explored_bytes: Dictionary[int, PackedByteArray] = {}
## Per faction: disc keys already stamped into the explored layer.
var _explored_stamps: Dictionary[int, Dictionary] = {}
## Disc keys stamped into the visible layer during the current update.
var _frame_stamps: Dictionary[int, bool] = {}
var _explored_dirty: bool = false
## Radius in quarter cells -> spans (x offset, row offset, width, rows).
var _span_cache: Dictionary[int, Array] = {}
## Sight blockers in cell units (x0, z0, x1, z1), and a coarse bucket index of them.
var _occluders: Array[Vector4] = []
var _occluder_buckets: Dictionary[Vector2i, PackedInt32Array] = {}
## Disc key -> spans with shadows cut out (or the plain spans when none fall in it).
var _occluded_cache: Dictionary[int, Array] = {}


func _init(p_area: Rect2 = Rect2(0, 0, 100, 100), p_cell_size: float = 2.0) -> void:
	area = p_area
	cell_size = maxf(p_cell_size, 0.1)
	columns = maxi(ceili(area.size.x / cell_size), 1)
	rows = maxi(ceili(area.size.y / cell_size), 1)


## Starts a new visible layer for `faction` (everything not in sight).
func begin_update(faction: int) -> void:
	_ensure(faction)
	_visible[faction].fill(Color.BLACK)
	_frame_stamps.clear()
	_explored_dirty = false


## Marks the disc of `radius` metres around `at` visible (and explored).
func reveal(faction: int, at: Vector3, radius: float) -> void:
	if radius <= 0.0:
		return
	_ensure(faction)
	var cell: Vector2i = cell_of(at)
	var quarters: int = roundi(radius / cell_size * 4.0)
	var key: int = (cell.y * columns + cell.x) * 4096 + quarters
	if _frame_stamps.has(key):
		return
	_frame_stamps[key] = true
	var spans: Array = _spans(quarters) if _occluders.is_empty() else _spans_at(key, cell, quarters)
	_stamp(_visible[faction], cell, spans)
	var stamps: Dictionary = _explored_stamps[faction]
	if not stamps.has(key):
		stamps[key] = true
		_stamp(_explored[faction], cell, spans)
		_explored_dirty = true


## Publishes the layers drawn since `begin_update()` to the queries.
func end_update(faction: int) -> void:
	_ensure(faction)
	_visible_bytes[faction] = _visible[faction].get_data()
	if _explored_dirty or not _explored_bytes.has(faction):
		_explored_bytes[faction] = _explored[faction].get_data()
	_explored_dirty = false


## CHARTED, EXPLORED or VISIBLE for `faction` at `at`. Outside the grid: CHARTED.
func state_at(faction: int, at: Vector3) -> int:
	var index: int = index_of(at)
	if index < 0 or not _visible_bytes.has(faction):
		return CHARTED
	if _visible_bytes[faction][index] > 0:
		return VISIBLE
	return EXPLORED if _explored_bytes[faction][index] > 0 else CHARTED


func is_visible(faction: int, at: Vector3) -> bool:
	return state_at(faction, at) == VISIBLE


func is_explored(faction: int, at: Vector3) -> bool:
	return state_at(faction, at) != CHARTED


## True if any of the centre and four corners of `rect` (world X/Z) is visible.
func is_area_visible(faction: int, rect: Rect2) -> bool:
	for point: Vector3 in _area_samples(rect):
		if is_visible(faction, point):
			return true
	return false


func is_area_explored(faction: int, rect: Rect2) -> bool:
	for point: Vector3 in _area_samples(rect):
		if is_explored(faction, point):
			return true
	return false


## The faction's visible layer (L8: 255 = visible), one pixel per cell.
func visible_image(faction: int) -> Image:
	_ensure(faction)
	return _visible[faction]


## The faction's explored layer (L8: 255 = explored at some point).
func explored_image(faction: int) -> Image:
	_ensure(faction)
	return _explored[faction]


func cell_of(at: Vector3) -> Vector2i:
	return Vector2i(
		floori((at.x - area.position.x) / cell_size), floori((at.z - area.position.y) / cell_size)
	)


## Index of the cell holding `at`, or -1 outside the grid.
func index_of(at: Vector3) -> int:
	var cell: Vector2i = cell_of(at)
	if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
		return -1
	return cell.y * columns + cell.x


func to_dict() -> Dictionary:
	var explored: Dictionary = {}
	for faction: int in _explored:
		explored[str(faction)] = Marshalls.raw_to_base64(_explored[faction].get_data())
	return {
		"version": SAVE_VERSION,
		"columns": columns,
		"rows": rows,
		"explored": explored,
	}


## Restores what each faction explored; nothing is visible until the next update.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported VisionGrid save version")
	var saved_columns: int = data.get("columns", columns)
	var saved_rows: int = data.get("rows", rows)
	if saved_columns != columns or saved_rows != rows:
		return
	var explored: Dictionary = data.get("explored", {})
	for key: Variant in explored:
		var faction: int = int(str(key))
		var text: String = explored[key]
		_ensure(faction)
		var bytes: PackedByteArray = Marshalls.base64_to_raw(text)
		if bytes.size() != columns * rows:
			continue
		_explored[faction].set_data(columns, rows, false, Image.FORMAT_L8, bytes)
		_explored_bytes[faction] = bytes
		_explored_stamps[faction] = {}
		_visible_bytes[faction] = _visible[faction].get_data()


## Sets the sight blockers (world X/Z rectangles). Shadows are recomputed lazily, and
## every faction may stamp its explored discs again (a destroyed prop opens a view).
func set_occluders(rects: Array[Rect2]) -> void:
	_occluders.clear()
	_occluder_buckets.clear()
	_occluded_cache.clear()
	for faction: int in _explored_stamps:
		_explored_stamps[faction] = {}
	for rect: Rect2 in rects:
		var low: Vector2 = (rect.position - area.position) / cell_size
		var high: Vector2 = (rect.end - area.position) / cell_size
		var index: int = _occluders.size()
		_occluders.append(Vector4(low.x, low.y, high.x, high.y))
		for bz: int in range(floori(low.y / BUCKET_CELLS), floori(high.y / BUCKET_CELLS) + 1):
			for bx: int in range(floori(low.x / BUCKET_CELLS), floori(high.x / BUCKET_CELLS) + 1):
				var bucket: Vector2i = Vector2i(bx, bz)
				if not _occluder_buckets.has(bucket):
					_occluder_buckets[bucket] = PackedInt32Array()
				_occluder_buckets[bucket].append(index)


func occluder_count() -> int:
	return _occluders.size()


## True if the centre of cell `to` can be seen from the centre of cell `from`
## (no occluder in between). Cells inside an occluder are seen (its top).
func cell_sees(from: Vector2i, to: Vector2i) -> bool:
	var source: Vector2 = Vector2(from) + Vector2(0.5, 0.5)
	var near: Array[Vector4] = _blockers(from, Vector2(to - from).length() + 1.0)
	return not _hidden(source, Vector2(to) + Vector2(0.5, 0.5), near)


## The disc's spans with the shadows of nearby occluders cut out (cached).
func _spans_at(key: int, cell: Vector2i, quarters: int) -> Array:
	var cached: Variant = _occluded_cache.get(key)
	if cached != null:
		return cached
	var radius: float = quarters / 4.0
	var source: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
	var kept: Array[Vector4] = _blockers(cell, radius + 1.0)
	if kept.is_empty():
		var plain: Array = _spans(quarters)
		_remember(key, plain)
		return plain
	shadowed_discs += 1
	var spans: Array = []
	var reach: int = floori(radius)
	for dz: int in range(-reach, reach + 1):
		var half: int = floori(sqrt(maxf(radius * radius - dz * dz, 0.0)))
		var hidden: Array[Vector2i] = []
		for occluder: Vector4 in kept:
			_row_shadow(source, source.y + dz, occluder, -half, half, hidden)
		_append_runs(spans, dz, -half, half, hidden)
	_remember(key, spans)
	return spans


## Adds to `hidden` the cells (dx ranges within `low`..`high`) of the row whose
## centres lie at height `y` that `occluder` hides from `source` (cell units). The
## shadow of a box from a point is the set source + λ (box - source), λ ≥ 1; on one
## row that is one interval of x, found from the λ range the row allows. Cells inside
## the box itself stay seen (its top).
static func _row_shadow(
	source: Vector2, y: float, box: Vector4, low: int, high: int, hidden: Array[Vector2i]
) -> void:
	var dy: float = y - source.y
	var near_y: float = box.y - source.y
	var far_y: float = box.w - source.y
	var lambda_low: float = 1.0
	var lambda_high: float = INF
	if dy > 0.0:
		if far_y <= 0.0:
			return
		lambda_low = maxf(lambda_low, dy / far_y)
		if near_y > 0.0:
			lambda_high = dy / near_y
	elif dy < 0.0:
		if near_y >= 0.0:
			return
		lambda_low = maxf(lambda_low, dy / near_y)
		if far_y < 0.0:
			lambda_high = dy / far_y
	elif near_y > 0.0 or far_y < 0.0:
		return
	if lambda_low > lambda_high:
		return
	var left: float = box.x - source.x
	var right: float = box.z - source.x
	var lo: float = -INF
	var hi: float = INF
	if lambda_high == INF:
		if left >= 0.0:
			lo = lambda_low * left
		if right <= 0.0:
			hi = lambda_low * right
	else:
		lo = minf(lambda_low * left, lambda_high * left)
		hi = maxf(lambda_low * right, lambda_high * right)
	# Cells exactly on the shadow's edge (a face or a tangent) are still seen.
	var first: int = maxi(ceili(lo + 0.0001), low) if lo > -INF else low
	var last: int = mini(floori(hi - 0.0001), high) if hi < INF else high
	if first > last:
		return
	if y > box.y and y < box.w:
		# The box's own cells on this row are seen; the shadow is what lies beyond.
		var inside_first: int = ceili(left + 0.0001)
		var inside_last: int = floori(right - 0.0001)
		if inside_first <= inside_last:
			if first < inside_first:
				hidden.append(Vector2i(first, mini(last, inside_first - 1)))
			if last > inside_last:
				hidden.append(Vector2i(maxi(first, inside_last + 1), last))
			return
	hidden.append(Vector2i(first, last))


## Appends to `spans` the runs of `low`..`high` on row `dz` not covered by `hidden`.
static func _append_runs(
	spans: Array, dz: int, low: int, high: int, hidden: Array[Vector2i]
) -> void:
	if hidden.is_empty():
		spans.append(Rect2i(low, dz, high - low + 1, 1))
		return
	hidden.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var cursor: int = low
	for range_x: Vector2i in hidden:
		if range_x.x > cursor:
			spans.append(Rect2i(cursor, dz, range_x.x - cursor, 1))
		cursor = maxi(cursor, range_x.y + 1)
	if cursor <= high:
		spans.append(Rect2i(cursor, dz, high - cursor + 1, 1))


## Occluders near `cell` that block its view: one the source stands in or touches it
## sees over (it is right at it).
func _blockers(cell: Vector2i, radius: float) -> Array[Vector4]:
	var source: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
	var kept: Array[Vector4] = []
	for occluder: Vector4 in _occluders_near(cell, radius):
		var touching: bool = (
			source.x >= occluder.x - 0.5
			and source.x <= occluder.z + 0.5
			and source.y >= occluder.y - 0.5
			and source.y <= occluder.w + 0.5
		)
		if not touching:
			kept.append(occluder)
	return kept


func _remember(key: int, spans: Array) -> void:
	if _occluded_cache.size() >= MAX_OCCLUDED_CACHE:
		_occluded_cache.clear()
	_occluded_cache[key] = spans


## Occluders whose bucket lies within `radius` cells of `cell`.
func _occluders_near(cell: Vector2i, radius: float) -> Array[Vector4]:
	var found: Array[Vector4] = []
	if _occluders.is_empty():
		return found
	var low_x: int = floori((cell.x - radius) / BUCKET_CELLS)
	var high_x: int = floori((cell.x + radius) / BUCKET_CELLS)
	var low_z: int = floori((cell.y - radius) / BUCKET_CELLS)
	var high_z: int = floori((cell.y + radius) / BUCKET_CELLS)
	var seen: Dictionary[int, bool] = {}
	for bz: int in range(low_z, high_z + 1):
		for bx: int in range(low_x, high_x + 1):
			var bucket: Variant = _occluder_buckets.get(Vector2i(bx, bz))
			if bucket == null:
				continue
			var indices: PackedInt32Array = bucket
			for index: int in indices:
				if not seen.has(index):
					seen[index] = true
					found.append(_occluders[index])
	return found


## True if an occluder lies between `source` and `target` (cell units). A target
## inside an occluder is not hidden by that one.
static func _hidden(source: Vector2, target: Vector2, occluders: Array[Vector4]) -> bool:
	var delta: Vector2 = target - source
	for box: Vector4 in occluders:
		if target.x > box.x and target.x < box.z and target.y > box.y and target.y < box.w:
			continue
		var t_in: float = 0.0
		var t_out: float = 1.0
		var crosses: bool = true
		for axis: int in 2:
			var start: float = source.x if axis == 0 else source.y
			var step: float = delta.x if axis == 0 else delta.y
			var low: float = box.x if axis == 0 else box.y
			var high: float = box.z if axis == 0 else box.w
			if absf(step) < 0.000001:
				if start <= low or start >= high:
					crosses = false
					break
				continue
			var t1: float = (low - start) / step
			var t2: float = (high - start) / step
			t_in = maxf(t_in, minf(t1, t2))
			t_out = minf(t_out, maxf(t1, t2))
			if t_in >= t_out:
				crosses = false
				break
		if crosses and t_in < 1.0:
			return true
	return false


func _ensure(faction: int) -> void:
	if _visible.has(faction):
		return
	_visible[faction] = Image.create_empty(columns, rows, false, Image.FORMAT_L8)
	_explored[faction] = Image.create_empty(columns, rows, false, Image.FORMAT_L8)
	_explored_stamps[faction] = {}


func _stamp(image: Image, cell: Vector2i, spans: Array) -> void:
	for entry: Variant in spans:
		var span: Rect2i = entry
		image.fill_rect(Rect2i(span.position + cell, span.size), Color.WHITE)


## Horizontal spans covering every cell whose centre lies within the radius
## (`quarters` / 4 cells) of the source cell's centre; equal rows merged.
func _spans(quarters: int) -> Array:
	if _span_cache.has(quarters):
		return _span_cache[quarters]
	var radius: float = quarters / 4.0
	var reach: int = floori(radius)
	var spans: Array = []
	var run_start: int = -reach
	var run_half: int = -1
	for dz: int in range(-reach, reach + 2):
		var half: int = -1
		if dz <= reach:
			half = floori(sqrt(maxf(radius * radius - dz * dz, 0.0)))
		if half != run_half:
			if run_half >= 0:
				spans.append(Rect2i(-run_half, run_start, run_half * 2 + 1, dz - run_start))
			run_start = dz
			run_half = half
	_span_cache[quarters] = spans
	return spans


func _area_samples(rect: Rect2) -> Array[Vector3]:
	var centre: Vector2 = rect.get_center()
	return [
		Vector3(centre.x, 0.0, centre.y),
		Vector3(rect.position.x, 0.0, rect.position.y),
		Vector3(rect.end.x, 0.0, rect.position.y),
		Vector3(rect.position.x, 0.0, rect.end.y),
		Vector3(rect.end.x, 0.0, rect.end.y),
	]
