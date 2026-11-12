class_name NavmeshPathService
extends PathService
## PathService backed by NavigationServer3D navmesh queries on one navigation map.
## Avoidance runs on the same map through server-side RVO agents.

## How many leading corridor corners a unit may skip when joining.
const JOIN_LOOKAHEAD: int = 4

## When false, units get no RVO agents (benchmarks compare both).
var avoidance_enabled: bool = true
## Benchmark and debug counters: shared group corridors built, and group members
## that could not use the corridor and got their own query.
var shared_paths_built: int = 0
var group_fallback_paths: int = 0

var _map: RID
var _walk_grid: WalkGrid
var _parameters: NavigationPathQueryParameters3D = NavigationPathQueryParameters3D.new()
var _result: NavigationPathQueryResult3D = NavigationPathQueryResult3D.new()


## `walk_grid` answers is_walkable(); without one everything counts as walkable.
func _init(map: RID, walk_grid: WalkGrid = null) -> void:
	_map = map
	_walk_grid = walk_grid
	_parameters.map = map
	_parameters.pathfinding_algorithm = NavigationPathQueryParameters3D.PATHFINDING_ALGORITHM_ASTAR
	_parameters.path_postprocessing = (
		NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	)
	# Units only need the points; collecting per-point metadata costs time.
	_parameters.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	_parameters.simplify_path = true
	_parameters.simplify_epsilon = 0.5


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	_parameters.start_position = from
	_parameters.target_position = to
	NavigationServer3D.query_path(_parameters, _result)
	var path: PackedVector3Array = _result.path
	# The first point is the snapped start position; the unit is already there.
	if path.size() > 1:
		path.remove_at(0)
	return path


## One navmesh query for the whole group: a corridor from the member nearest the
## group's centre to the centre of the goals. Each unit joins the corridor at its first
## corner and leaves it for its own goal at the last corner from which the goal is in
## clear view (walk grid). Units that cannot see the corridor get their own query.
func find_group_paths(
	starts: PackedVector3Array, goals: PackedVector3Array
) -> Array[PackedVector3Array]:
	if starts.size() < 3 or _walk_grid == null:
		return super(starts, goals)
	var start_centre: Vector3 = _centre(starts)
	var goal_centre: Vector3 = _centre(goals)
	var leader: int = 0
	for i: int in starts.size():
		if (
			starts[i].distance_squared_to(start_centre)
			< starts[leader].distance_squared_to(start_centre)
		):
			leader = i
	var corridor: PackedVector3Array = find_path(starts[leader], goal_centre)
	shared_paths_built += 1
	var result: Array[PackedVector3Array] = []
	for i: int in starts.size():
		var path: PackedVector3Array = _join(corridor, starts[i], goals[i])
		if path.is_empty():
			group_fallback_paths += 1
			path = find_path(starts[i], goals[i])
		result.append(path)
	return result


func is_walkable(point: Vector3) -> bool:
	return _walk_grid == null or _walk_grid.is_walkable(point.x, point.z)


func closest_point(point: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_map, point)


func get_avoidance_map() -> RID:
	return _map if avoidance_enabled else RID()


## Path for one unit along `corridor`, or empty if it cannot join or leave the
## corridor in a straight walkable line. Joins at the furthest of the first corners it
## can see, leaves at the earliest corner that sees its goal (so units fan out to
## their slots instead of all touching the group's centre first).
func _join(corridor: PackedVector3Array, start: Vector3, goal: Vector3) -> PackedVector3Array:
	if _walk_grid.is_segment_walkable(start, goal):
		return PackedVector3Array([goal])
	var entry: int = -1
	for k: int in mini(corridor.size(), JOIN_LOOKAHEAD):
		if not _walk_grid.is_segment_walkable(start, corridor[k]):
			break
		entry = k
	if entry < 0:
		return PackedVector3Array()
	for exit: int in range(entry, corridor.size()):
		if _walk_grid.is_segment_walkable(corridor[exit], goal):
			var path: PackedVector3Array = corridor.slice(entry, exit + 1)
			path.append(goal)
			return path
	return PackedVector3Array()


static func _centre(points: PackedVector3Array) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	for point: Vector3 in points:
		sum += point
	return sum / float(maxi(points.size(), 1))
