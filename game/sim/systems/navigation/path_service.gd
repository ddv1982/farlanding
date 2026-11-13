class_name PathService
extends RefCounted
## The one interface ground movement uses to find its way. The base class is the
## trivial backend (straight lines, no obstacles), used by tests; the game uses
## NavmeshPathService. A flow-field backend would implement the same methods.
##
## Buildings and deposits block areas with `block_area()`: paths go around them and
## `is_walkable()` is false inside. The base class only records the areas.
##
## On a tidal map the sea closes ground to ground units (ADR 0014): `set_water()` says
## where it stands; ground lower than `closed_below` is closed. The base class judges
## that against `water_heights` point by point (tests); NavmeshPathService switches
## between navmeshes baked for a few sea levels. Hovering units cross flooded ground:
## they move with `for_hover()`, which ignores the sea but not blocked areas.

## The base class re-judges the sea only when the closing height moved this much.
const WATER_STEP: float = 0.1
## Spacing of the samples along a straight path checked against the sea, in metres.
const WATER_SAMPLE: float = 1.0

## Ground lower than this is under water too deep to wade: closed to ground units.
## -INF = no sea.
var closed_below: float = -INF
## Ground heights the base class judges the sea against; null = no sea.
var water_heights: HeightField = null

var _blocked: Dictionary[int, Rect2] = {}
var _next_block_id: int = 1
var _hover: PathService = null


## Returns world-space corner points from `from` to (the reachable point nearest)
## `to`, excluding `from`. Empty if no path exists. Called once per order per unit
## (and on a stuck-repath), never per frame.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return PackedVector3Array([_dry_end(from, to)])


## Paths for a group: one per (start, goal) pair, same format as find_path(). The
## base version asks find_path() for each; backends override it to share work.
func find_group_paths(
	starts: PackedVector3Array, goals: PackedVector3Array
) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	for i: int in starts.size():
		result.append(find_path(starts[i], goals[i]))
	return result


## True if a unit may stand at `point`. Must be cheap: called per unit per tick.
func is_walkable(point: Vector3) -> bool:
	return not is_blocked(point) and not is_flooded(point)


## True if the sea closes `point` to ground units now.
func is_flooded(point: Vector3) -> bool:
	return (
		water_heights != null
		and closed_below > -INF
		and water_heights.sample(point.x, point.z) < closed_below
	)


## Tells navigation the sea stands at `level`; ground deeper than `wading_depth`
## under it closes to ground units. Returns true when the closed ground changed
## (routes in progress may have to re-plan).
func set_water(level: float, wading_depth: float) -> bool:
	var closed: float = level - wading_depth
	if closed_below > -INF and absf(closed - closed_below) < WATER_STEP:
		return false
	closed_below = closed
	return true


## The paths hovering units use: the same blocked areas, but the sea does not close
## anything to them. Without a sea, this service itself.
func for_hover() -> PathService:
	if water_heights == null:
		return self
	if _hover == null:
		_hover = PathService.new()
		_hover._blocked = _blocked
	return _hover


## True if the terrain alone lets a unit stand at `point` (blocked areas ignored).
## Used for building placement.
func is_terrain_walkable(_point: Vector3) -> bool:
	return true


## Makes `area` (world X/Z) impassable. Returns a handle for `unblock_area()`.
func block_area(area: Rect2) -> int:
	var id: int = _next_block_id
	_next_block_id += 1
	_blocked[id] = area
	_on_blocked(id, area)
	return id


## Makes an area blocked by `block_area()` passable again.
func unblock_area(id: int) -> void:
	if not _blocked.has(id):
		return
	var area: Rect2 = _blocked[id]
	_blocked.erase(id)
	_on_unblocked(id, area)


## True if `point` lies in a blocked area.
func is_blocked(point: Vector3) -> bool:
	for area: Rect2 in _blocked.values():
		if area.has_point(Vector2(point.x, point.z)):
			return true
	return false


## How far a ground unit gets walking straight from `from` to `to` before closed
## water stops it (it may start in water and wade out): `to`, or the last dry point
## (the base class's "nearest reachable point").
func _dry_end(from: Vector3, to: Vector3) -> Vector3:
	if water_heights == null or closed_below <= -INF:
		return to
	var length: float = Vector2(to.x - from.x, to.z - from.z).length()
	var steps: int = maxi(1, ceili(length / WATER_SAMPLE))
	var left_water: bool = not is_flooded(from)
	var last_dry: Vector3 = from
	for i: int in range(1, steps + 1):
		var point: Vector3 = from.lerp(to, float(i) / steps)
		var wet: bool = is_flooded(point)
		if wet and left_water:
			return last_dry
		if not wet:
			left_water = true
			last_dry = point
	return to


## Backend hook: `area` was just blocked under `id`.
func _on_blocked(_id: int, _area: Rect2) -> void:
	pass


## Backend hook: the area of `id` is passable again.
func _on_unblocked(_id: int, _area: Rect2) -> void:
	pass


## The nearest walkable point to `point`. Can be expensive; not for per-tick use.
func closest_point(point: Vector3) -> Vector3:
	return point


## The navigation map RVO agents should join, or an invalid RID when this backend has
## no server-side avoidance.
func get_avoidance_map() -> RID:
	return RID()
