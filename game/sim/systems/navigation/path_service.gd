class_name PathService
extends RefCounted
## The one interface ground movement uses to find its way. The base class is the
## trivial backend (straight lines, no obstacles), used by tests; the game uses
## NavmeshPathService. A flow-field backend would implement the same methods.
##
## Buildings and deposits block areas with `block_area()`: paths go around them and
## `is_walkable()` is false inside. The base class only records the areas.

var _blocked: Dictionary[int, Rect2] = {}
var _next_block_id: int = 1


## Returns world-space corner points from `from` to (the reachable point nearest)
## `to`, excluding `from`. Empty if no path exists. Called once per order per unit
## (and on a stuck-repath), never per frame.
func find_path(_from: Vector3, to: Vector3) -> PackedVector3Array:
	return PackedVector3Array([to])


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
	return not is_blocked(point)


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
