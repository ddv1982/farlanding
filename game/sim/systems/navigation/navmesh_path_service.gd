class_name NavmeshPathService
extends PathService
## PathService backed by NavigationServer3D navmesh queries on one navigation map.
## Avoidance runs on the same map through server-side RVO agents.
##
## Blocked areas (buildings, deposits) are cut out of the region's navmesh with a
## NavmeshCutter, grown by CUT_MARGIN so unit centres keep clear of walls like they
## do of cliffs; the walk grid loses the same cells and each area also becomes a
## static RVO obstacle (ADR 0006).
##
## On a tidal map (ADR 0014) the region holds one of several navmeshes baked for a few
## sea levels (`set_flood_stages()`): `set_water()` switches to the stage of the sea
## level, with every blocked area cut out of it too (each stage keeps its own cutter,
## brought up to date when it is switched to), and the walk grid takes that stage's
## cells. Hovering units use a second navigation map holding the lowest stage
## (`for_hover()`): flooded shallows stay open to them, the deep channel does not.

## Merge rasteriser scale of the hovering units' own navigation map (see
## `_make_hover_service()`).
const HOVER_MERGE_SCALE: float = 1.0
## Polygons a path search may visit (the server's default, 4096, cuts long detours
## short on a map of 11 000+ polygons).
const PATH_SEARCH_MAX_POLYGONS: int = 65536
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

## The flood stage the region holds now (0 = the lowest sea).
var flood_stage: int = 0

var _map: RID
var _walk_grid: WalkGrid
## Terrain-only walkability at the lowest sea (building placement).
var _terrain_cells: PackedByteArray = PackedByteArray()
var _region: NavigationRegion3D = null
## A region made on the server (the hover map's), used when there is no region node.
var _region_rid: RID = RID()
var _base_navmesh: NavigationMesh = null
var _obstacles: Dictionary[int, RID] = {}
var _apply_scheduled: bool = false
## Per flood stage (one entry without a sea): the baked navmesh, its cutter, the cuts
## it still lacks, whether it must be rebuilt from scratch, its terrain-only cells.
var _stage_bases: Array[NavigationMesh] = []
var _stage_cutters: Array[NavmeshCutter] = []
var _stage_pending: Array[Array] = []
var _stage_rebuild: Array[bool] = []
var _stage_cells: Array[PackedByteArray] = []
## Per flood stage: the sea level it applies from, and the height below which the
## ground was cut from its navmesh.
var _stage_levels: PackedFloat32Array = PackedFloat32Array()
var _stage_clips: PackedFloat32Array = PackedFloat32Array()
## Hovering units' service (lowest stage on its own map), or null without a sea.
var _hover_service: NavmeshPathService = null
var _hover_map: RID = RID()
## The map RVO agents join (the ground map, also for the hover service).
var _avoidance_map: RID = RID()
## False for the hover service: the ground service owns the RVO obstacles.
var _owns_obstacles: bool = true
## The stage whose (cut) navmesh the region holds.
var _shown_stage: int = 0
var _parameters: NavigationPathQueryParameters3D = NavigationPathQueryParameters3D.new()
var _result: NavigationPathQueryResult3D = NavigationPathQueryResult3D.new()


## `walk_grid` answers is_walkable(); without one everything counts as walkable.
## `region` holds the navmesh that blocked areas are cut out of (optional).
func _init(map: RID, walk_grid: WalkGrid = null, region: NavigationRegion3D = null) -> void:
	_map = map
	_avoidance_map = map
	# The map follows the simulation in step: with the engine's default (updates on
	# worker threads over several frames) a unit could plan a route over ground the
	# tide had just closed, when the machine was busy or the sim ran ahead of real time.
	NavigationServer3D.map_set_use_async_iterations(_map, false)
	_walk_grid = walk_grid
	if walk_grid != null:
		_terrain_cells = walk_grid.cells.duplicate()
	_region = region
	if region != null and region.navigation_mesh != null:
		_base_navmesh = region.navigation_mesh
	_reset_stages([_base_navmesh] as Array[NavigationMesh])
	_shown_stage = 0
	_parameters.map = map
	_parameters.pathfinding_algorithm = NavigationPathQueryParameters3D.PATHFINDING_ALGORITHM_ASTAR
	_parameters.path_postprocessing = (
		NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	)
	# Units only need the points; collecting per-point metadata costs time.
	_parameters.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	_parameters.simplify_path = true
	_parameters.simplify_epsilon = 0.5
	# The server stops a search after 4096 polygons by default and returns a path to
	# the nearest point it found: a long detour (Thalassa's causeway at high water)
	# then ends half way.
	_parameters.path_search_max_polygons = PATH_SEARCH_MAX_POLYGONS


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


## Makes this a tidal map's service: `navmeshes` are the stages, lowest sea first (the
## first is the region's own), `levels` the sea level each applies from and `clips`
## the height below which its ground was cut away. The walk grid's cells for each
## stage are rasterised over `area` now; hovering units get their own map.
func set_flood_stages(
	navmeshes: Array[NavigationMesh],
	levels: PackedFloat32Array,
	clips: PackedFloat32Array,
	area: Rect2,
	cell_size: float,
) -> void:
	assert(navmeshes.size() == levels.size() and levels.size() == clips.size())
	_reset_stages(navmeshes)
	_stage_levels = levels
	_stage_clips = clips
	_base_navmesh = navmeshes[0]
	_stage_cells.clear()
	for navmesh: NavigationMesh in navmeshes:
		_stage_cells.append(WalkGrid.from_navmesh(navmesh, area, cell_size).cells)
	_terrain_cells = _stage_cells[0].duplicate()
	flood_stage = 0
	closed_below = clips[0]
	_make_hover_service(navmeshes[0], area, cell_size)


## Switches to the flood stage of a sea at `level` (`wading_depth` was used to bake
## the stages). Returns true when the stage changed.
func set_water(level: float, wading_depth: float) -> bool:
	if _stage_levels.is_empty():
		return super(level, wading_depth)
	var stage: int = 0
	for i: int in _stage_levels.size():
		if level >= _stage_levels[i]:
			stage = i
	if stage == flood_stage:
		return false
	flood_stage = stage
	closed_below = _stage_clips[stage]
	if _walk_grid != null:
		_walk_grid.cells = _stage_cells[stage].duplicate()
		for blocked: Rect2 in _blocked.values():
			_set_cells(blocked.grow(CUT_MARGIN), false)
	_schedule_apply()
	return true


func for_hover() -> PathService:
	return _hover_service if _hover_service != null else self


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
	if _hover_service != null:
		_hover_service.block_area_as(id, area)
	if _base_navmesh == null:
		return
	for pending: Array in _stage_pending:
		pending.append(cut)
	_schedule_apply()


func _on_unblocked(id: int, area: Rect2) -> void:
	if _obstacles.has(id):
		NavigationServer3D.free_rid(_obstacles[id])
		_obstacles.erase(id)
	var cut: Rect2 = area.grow(CUT_MARGIN)
	_restore_cells(cut)
	if _hover_service != null:
		_hover_service.unblock_area(id)
	if _base_navmesh == null:
		return
	for stage: int in _stage_rebuild.size():
		_stage_rebuild[stage] = true
	_schedule_apply()


## Blocks `area` under the id the ground service gave it (the hover service mirrors
## the ground service's blocked areas).
func block_area_as(id: int, area: Rect2) -> void:
	_blocked[id] = area
	_next_block_id = maxi(_next_block_id, id + 1)
	_on_blocked(id, area)


## Applies waiting cuts now instead of at the end of the frame (tests, map load).
func apply_cuts() -> void:
	_apply_scheduled = false
	if _hover_service != null:
		_hover_service.apply_cuts()
	if _base_navmesh == null or (_region == null and not _region_rid.is_valid()):
		return
	var stage: int = flood_stage
	var pending: Array = _stage_pending[stage]
	var untouched: bool = _stage_cutters[stage] == null and _blocked.is_empty()
	if _shown_stage == stage and (untouched or (not _stage_rebuild[stage] and pending.is_empty())):
		return
	var started: int = Time.get_ticks_usec()
	var base: NavigationMesh = _stage_bases[stage]
	if _stage_rebuild[stage] or _stage_cutters[stage] == null:
		_stage_cutters[stage] = NavmeshCutter.new(base)
		pending.clear()
		for blocked: Rect2 in _blocked.values():
			pending.append(blocked.grow(CUT_MARGIN))
		_stage_rebuild[stage] = false
	var cutter: NavmeshCutter = _stage_cutters[stage]
	for cut: Variant in pending:
		var rect: Rect2 = cut
		cutter.cut(rect)
	pending.clear()
	_set_region_mesh(cutter.to_navmesh(base), stage)
	last_cut_msec = (Time.get_ticks_usec() - started) / 1000.0


## Releases the RVO obstacles (call when the mission ends).
func free_obstacles() -> void:
	for rid: RID in _obstacles.values():
		NavigationServer3D.free_rid(rid)
	_obstacles.clear()


## Builds every other flood stage's cutter now, with the areas blocked so far, so the
## first switch to a stage only applies the cuts made since (instead of half a second
## of cutting in the middle of play). Call once the landing is placed or restored.
func prepare_flood_stages() -> void:
	for stage: int in _stage_bases.size():
		if stage == flood_stage or _stage_bases[stage] == null:
			continue
		var cutter: NavmeshCutter = NavmeshCutter.new(_stage_bases[stage])
		for blocked: Rect2 in _blocked.values():
			cutter.cut(blocked.grow(CUT_MARGIN))
		_stage_cutters[stage] = cutter
		_stage_pending[stage].clear()
		_stage_rebuild[stage] = false


## Releases everything this service made on the navigation server (obstacles, the
## hover map and its region). Call when the mission ends.
func release() -> void:
	free_obstacles()
	if _hover_service != null:
		_hover_service.release()
		_hover_service = null
	if _region_rid.is_valid():
		NavigationServer3D.free_rid(_region_rid)
		_region_rid = RID()
	if _hover_map.is_valid():
		NavigationServer3D.free_rid(_hover_map)
		_hover_map = RID()


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


## Gives cells in `area` back their terrain walkability (at the current flood stage)
## unless another area blocks them.
func _restore_cells(area: Rect2) -> void:
	if _walk_grid == null:
		return
	var terrain: PackedByteArray = (
		_stage_cells[flood_stage] if flood_stage < _stage_cells.size() else _terrain_cells
	)
	for cell: Vector2i in _cells_in(area):
		var centre: Vector2 = (
			_walk_grid.origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _walk_grid.cell_size
		)
		var walkable: bool = terrain[cell.y * _walk_grid.columns + cell.x] != 0
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
	if not avoidance_enabled or not _owns_obstacles or not _map.is_valid():
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
	return _avoidance_map if avoidance_enabled else RID()


func _reset_stages(navmeshes: Array[NavigationMesh]) -> void:
	_stage_bases = navmeshes
	_stage_cutters.clear()
	_stage_pending.clear()
	_stage_rebuild.clear()
	for i: int in navmeshes.size():
		_stage_cutters.append(null)
		_stage_pending.append([])
		_stage_rebuild.append(true)


## The hovering units' service: the lowest stage on a navigation map of its own, with
## a walk grid of its own; RVO avoidance stays on the ground map.
func _make_hover_service(lowest: NavigationMesh, area: Rect2, cell_size: float) -> void:
	_hover_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_hover_map, lowest.cell_size)
	NavigationServer3D.map_set_cell_height(_hover_map, lowest.cell_height)
	# Measured (Godot 4.7): a map made here joins edges more finely than the world's
	# default map although both report the same scale, and rejects hundreds of edges of
	# a navmesh the default map takes cleanly; scale 1 makes it join them alike.
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(_hover_map, HOVER_MERGE_SCALE)
	NavigationServer3D.map_set_edge_connection_margin(
		_hover_map, NavigationServer3D.map_get_edge_connection_margin(_map)
	)
	NavigationServer3D.map_set_use_async_iterations(_hover_map, false)
	NavigationServer3D.map_set_active(_hover_map, true)
	var region: RID = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, _hover_map)
	var grid: WalkGrid = WalkGrid.new(area.position, cell_size, 0, 0)
	if _walk_grid != null:
		grid = WalkGrid.new(
			_walk_grid.origin, _walk_grid.cell_size, _walk_grid.columns, _walk_grid.rows
		)
		grid.cells = _stage_cells[0].duplicate()
	_hover_service = NavmeshPathService.new(_hover_map, grid, null)
	_hover_service._region_rid = region
	_hover_service._base_navmesh = lowest
	_hover_service._reset_stages([lowest] as Array[NavigationMesh])
	_hover_service._avoidance_map = _map
	_hover_service._owns_obstacles = false
	_hover_service.avoidance_enabled = avoidance_enabled
	NavigationServer3D.region_set_navigation_mesh(region, lowest)
	for id: int in _blocked:
		_hover_service.block_area_as(id, _blocked[id])


func _set_region_mesh(navmesh: NavigationMesh, stage: int) -> void:
	_shown_stage = stage
	if _region != null:
		_region.navigation_mesh = navmesh
	elif _region_rid.is_valid():
		NavigationServer3D.region_set_navigation_mesh(_region_rid, navmesh)


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
