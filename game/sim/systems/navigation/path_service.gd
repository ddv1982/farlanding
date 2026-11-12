class_name PathService
extends RefCounted
## The one interface ground movement uses to find its way. The base class is the
## trivial backend (straight lines, no obstacles), used by tests; the game uses
## NavmeshPathService. A flow-field backend would implement the same methods.


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
func is_walkable(_point: Vector3) -> bool:
	return true


## The nearest walkable point to `point`. Can be expensive; not for per-tick use.
func closest_point(point: Vector3) -> Vector3:
	return point


## The navigation map RVO agents should join, or an invalid RID when this backend has
## no server-side avoidance.
func get_avoidance_map() -> RID:
	return RID()
