class_name VisionGrid
extends RefCounted
## Per-faction knowledge of the map on a square cell grid (PLAN 3.4). Each cell is
## CHARTED (never seen: terrain shape only), EXPLORED (seen before) or VISIBLE (in
## sight now). A faction's update clears its visible layer, stamps a disc for every
## sight source with `reveal()` and ends with `end_update()`. Discs are drawn as
## horizontal spans with Image.fill_rect (native), sources that share a cell and
## radius are stamped once, and the explored layer skips any disc it already holds,
## so an update costs a few native calls per distinct source.

const CHARTED: int = 0
const EXPLORED: int = 1
const VISIBLE: int = 2
const SAVE_VERSION: int = 1

## World X/Z area covered.
var area: Rect2
var cell_size: float = 2.0
var columns: int = 1
var rows: int = 1

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
	var spans: Array = _spans(quarters)
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
