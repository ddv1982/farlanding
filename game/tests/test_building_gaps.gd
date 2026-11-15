extends GutTest
## Visible building lanes remain usable with Traffic enabled. Obstacle footprints
## still block paths; optional passing room must not become an invisible wall.

var _map: RID
var _region: NavigationRegion3D
var _paths: NavmeshPathService


func before_each() -> void:
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(_map, true)
	_region = NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	(
		mesh
		. set_vertices(
			PackedVector3Array(
				[
					Vector3(-20, 0, -20),
					Vector3(-20, 0, 20),
					Vector3(20, 0, 20),
					Vector3(20, 0, -20),
				]
			)
		)
	)
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_region.navigation_mesh = mesh
	add_child_autofree(_region)
	_region.set_navigation_map(_map)
	var grid: WalkGrid = WalkGrid.from_navmesh(mesh, Rect2(-20, -20, 40, 40), 0.5)
	_paths = NavmeshPathService.new(_map, grid, _region)
	# Two building rows, separated by a 2.4 m lane. A Ranger is 1.6 m wide.
	_paths.block_area(Rect2(-20, -4, 18.8, 8))
	_paths.block_area(Rect2(1.2, -4, 18.8, 8))
	_paths.apply_cuts()
	await wait_physics_frames(2)
	NavigationServer3D.map_force_update(_map)


func after_each() -> void:
	_paths.release()
	_region.set_navigation_map(RID())
	NavigationServer3D.free_rid(_map)


func test_ranger_walks_through_visible_building_gap_with_traffic() -> void:
	var start := Vector3(0, 0, 12)
	var goal := Vector3(0, 0, -12)
	assert_true(_paths.is_segment_walkable(start, goal), "the visible lane stays open")
	var path: PackedVector3Array = _paths.find_path(start, goal)
	assert_false(path.is_empty())
	if not path.is_empty():
		assert_lt(path[path.size() - 1].distance_to(goal), 0.1, "navmesh reaches the far side")
	var ranger: Unit = Unit.new()
	ranger.def = load("res://data/units/concord_ranger.tres")
	ranger.add_child(Locomotion.new())
	ranger.add_child(UnitOrders.new())
	add_child_autofree(ranger)
	var traffic := Traffic.new()
	ranger.locomotion.setup(ranger.def, start, 0.0, _paths, null, traffic, 0)
	ranger.locomotion.move_to(goal)
	var entered_building: bool = false
	for i: int in 100:
		traffic.solve()
		ranger.sim_tick(0.1)
		entered_building = entered_building or _paths.is_blocked(ranger.sim_position())
	assert_lt(ranger.sim_position().distance_to(goal), 0.5, "Ranger passes with traffic on")
	assert_false(entered_building, "the actual buildings remain solid")


func test_footprints_still_block_and_demolition_restores_the_lane() -> void:
	var bridge: int = _paths.block_area(Rect2(-1.2, -4, 2.4, 8))
	_paths.apply_cuts()
	await wait_physics_frames(2)
	NavigationServer3D.map_force_update(_map)
	assert_false(_paths.is_walkable(Vector3.ZERO), "closed building footprint")
	_paths.unblock_area(bridge)
	_paths.apply_cuts()
	await wait_physics_frames(2)
	NavigationServer3D.map_force_update(_map)
	assert_true(_paths.is_segment_walkable(Vector3(0, 0, 12), Vector3(0, 0, -12)))
	assert_false(_paths.is_walkable(Vector3(5, 0, 0)), "remaining building stays closed")
