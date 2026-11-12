class_name NavmeshPathService
extends PathService
## PathService backed by NavigationServer3D navmesh queries on one navigation map.
## Avoidance runs on the same map through server-side RVO agents.
##
## Blocked areas (buildings, deposits) are cut out of the region's navmesh with a
## NavmeshCutter, grown by CUT_MARGIN so unit centres keep clear of walls like they
## do of cliffs; the walk grid loses the same cells and each area also becomes a
## static RVO obstacle (ADR 0006).

## How many leading corridor corners a unit may skip when joining.
const JOIN_LOOKAHEAD: int = 4
## Blocked areas are cut out of the navmesh grown by this much (metres): the baked
## agent radius plus room for the widest unit's avoidance radius.
const CUT_MARGIN: float = NavmeshTools.AGENT_RADIUS + 0.5

## When false, units get no RVO agents (benchmarks compare both).
var avoidance_enabled: bool = true
## Benchmark and debug counters: shared group corridors built, and group members
## that could not use the corridor and got their own query.
var shared_paths_built: int = 0
var group_fallback_paths: int = 0

## Milliseconds the last navmesh cut took (cut + rebuild), for ADR numbers.
var last_cut_msec: float = 0.0

var _map: RID
var _walk_grid: WalkGrid
var _terrain_cells: PackedByteArray = PackedByteArray()
var _region: NavigationRegion3D = null
var _base_navmesh: NavigationMesh = null
var _cutter: NavmeshCutter = null
var _obstacles: Dictionary[int, RID] = {}
var _pending_cuts: Array[Rect2] = []
var _rebuild_all: bool = false
var _apply_scheduled: bool = false
var _parameters: NavigationPathQueryParameters3D = NavigationPathQueryParameters3D.new()
var _result: NavigationPathQueryResult3D = NavigationPathQueryResult3D.new()


## `walk_grid` answers is_walkable(); without one everything counts as walkable.
## `region` holds the navmesh that blocked areas are cut out of (optional).
func _init(map: RID, walk_grid: WalkGrid = null, region: NavigationRegion3D = null) -> void:
	_map = map
	_walk_grid = walk_grid
	if walk_grid != null:
		_terrain_cells = walk_grid.cells.duplicate()
	_region = region
	if region != null and region.navigation_mesh != null:
		_base_navmesh = region.navigation_mesh
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


func is_terrain_walkable(point: Vector3) -> bool:
	if _walk_grid == null:
		return true
	var column: int = floori((point.x - _walk_grid.origin.x) / _walk_grid.cell_size)
	var row: int = floori((point.z - _walk_grid.origin.y) / _walk_grid.cell_size)
	if column < 0 or row < 0 or column >= _walk_grid.columns or row >= _walk_grid.rows:
		return false
	return _terrain_cells[row * _walk_grid.columns + column] != 0


func _on_blocked(id: int, area: Rect2) -> void:
	var cut: Rect2 = area.grow(CUT_MARGIN)
	_set_cells(cut, false)
	var obstacle: RID = _create_obstacle(area)
	if obstacle.is_valid():
		_obstacles[id] = obstacle
	if _base_navmesh == null:
		return
	_pending_cuts.append(cut)
	_schedule_apply()


func _on_unblocked(id: int, area: Rect2) -> void:
	if _obstacles.has(id):
		NavigationServer3D.free_rid(_obstacles[id])
		_obstacles.erase(id)
	var cut: Rect2 = area.grow(CUT_MARGIN)
	_restore_cells(cut)
	if _base_navmesh == null:
		return
	_rebuild_all = true
	_schedule_apply()


## Applies waiting cuts now instead of at the end of the frame (tests, map load).
func apply_cuts() -> void:
	_apply_scheduled = false
	if _base_navmesh == null or _region == null:
		return
	if not _rebuild_all and _pending_cuts.is_empty():
		return
	var started: int = Time.get_ticks_usec()
	if _rebuild_all or _cutter == null:
		_cutter = NavmeshCutter.new(_base_navmesh)
		_pending_cuts.clear()
		for blocked: Rect2 in _blocked.values():
			_pending_cuts.append(blocked.grow(CUT_MARGIN))
		_rebuild_all = false
	for cut: Rect2 in _pending_cuts:
		_cutter.cut(cut)
	_pending_cuts.clear()
	_region.navigation_mesh = _cutter.to_navmesh(_base_navmesh)
	last_cut_msec = (Time.get_ticks_usec() - started) / 1000.0


## Releases the RVO obstacles (call when the mission ends).
func free_obstacles() -> void:
	for rid: RID in _obstacles.values():
		NavigationServer3D.free_rid(rid)
	_obstacles.clear()


func _schedule_apply() -> void:
	if _apply_scheduled:
		return
	_apply_scheduled = true
	apply_cuts.call_deferred()


func _set_cells(area: Rect2, walkable: bool) -> void:
	if _walk_grid == null:
		return
	for cell: Vector2i in _cells_in(area):
		_walk_grid.set_walkable(cell.x, cell.y, walkable)


## Gives cells in `area` back their terrain walkability unless another area blocks them.
func _restore_cells(area: Rect2) -> void:
	if _walk_grid == null:
		return
	for cell: Vector2i in _cells_in(area):
		var centre: Vector2 = (
			_walk_grid.origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _walk_grid.cell_size
		)
		var walkable: bool = _terrain_cells[cell.y * _walk_grid.columns + cell.x] != 0
		for other: Rect2 in _blocked.values():
			if other.grow(CUT_MARGIN).has_point(centre):
				walkable = false
				break
		_walk_grid.set_walkable(cell.x, cell.y, walkable)


## Grid cells whose centre lies in `area`.
func _cells_in(area: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var size: float = _walk_grid.cell_size
	var first_column: int = maxi(ceili((area.position.x - _walk_grid.origin.x) / size - 0.5), 0)
	var last_column: int = mini(
		floori((area.end.x - _walk_grid.origin.x) / size - 0.5), _walk_grid.columns - 1
	)
	var first_row: int = maxi(ceili((area.position.y - _walk_grid.origin.y) / size - 0.5), 0)
	var last_row: int = mini(
		floori((area.end.y - _walk_grid.origin.y) / size - 0.5), _walk_grid.rows - 1
	)
	for row: int in range(first_row, last_row + 1):
		for column: int in range(first_column, last_column + 1):
			cells.append(Vector2i(column, row))
	return cells


## A static RVO obstacle over `area`, wound so agents are pushed out.
func _create_obstacle(area: Rect2) -> RID:
	if not avoidance_enabled or not _map.is_valid():
		return RID()
	var outline: PackedVector2Array = PackedVector2Array(
		[
			area.position,
			Vector2(area.end.x, area.position.y),
			area.end,
			Vector2(area.position.x, area.end.y)
		]
	)
	if Geometry2D.is_polygon_clockwise(outline):
		outline.reverse()
	var points: PackedVector3Array = PackedVector3Array()
	for point: Vector2 in outline:
		points.append(Vector3(point.x, 0.0, point.y))
	var obstacle: RID = NavigationServer3D.obstacle_create()
	NavigationServer3D.obstacle_set_map(obstacle, _map)
	NavigationServer3D.obstacle_set_vertices(obstacle, points)
	NavigationServer3D.obstacle_set_height(obstacle, 50.0)
	NavigationServer3D.obstacle_set_position(obstacle, Vector3(0.0, -10.0, 0.0))
	NavigationServer3D.obstacle_set_avoidance_enabled(obstacle, true)
	return obstacle


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
