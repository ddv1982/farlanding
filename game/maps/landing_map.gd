class_name LandingMap
extends Node3D
## A landing map: the map, not the mission (ADR 0014). It reads its layout from
## `map_def` (a MapDef): builds the terrain data (heights from the terrain collider, the
## walk grid from the navmesh, one per flood stage on a tidal map), wires the mission
## services (world, combat, vision, fog of war), places the resource nodes, charts the
## discovery sites the orbital scan found (a chain's later steps stay hidden until led
## to), posts the dormant Custodians and scatters the natural cover. Then the MissionDef
## in `mission` supplies the forces and rules through a Mission node
## (missions/mission.gd): who lands where, the enemy, objectives, script. Without one it
## plays the map's default mission, so a map scene also runs on its own.
##
## A map scene inherits `landing_map.tscn` (services, camera, selection, HUD), adds the
## map's visuals (terrain with its collider, light, VFX) and sets `map_def`.
##
## A saved landing (ADR 0013) is restored instead when `restore_state` is set: the
## map builds its terrain data and services as usual, then places nothing itself and
## restores everything from the save (resource nodes, sites, props, buildings, units,
## the planet's rule, the mission runner and its AI), the camera and the control
## groups. `snapshot()` produces that dictionary for a running landing.

## The map's layout.
@export var map_def: MapDef
@export var context: MissionContext
@export var world: SimWorld
@export var camera: RtsCamera
@export var navigation_region: NavigationRegion3D
@export var hud: Hud
@export var selection_controller: SelectionController
@export var economy_rules: EconomyRules
## Armour x damage multipliers for this map.
@export var damage_table: DamageTable
## Fog of war on (off shows the whole map, for testing).
@export var fog_of_war: bool = true
## False: terrain, resources and sites only, no mission (benchmarks).
@export var with_mission: bool = true
## False: the map's own cover (`map_def.prop_layout`) is left out (benchmarks).
@export var with_props: bool = true
@export_group("Enemy AI")
## Prints the commander's notable decisions to the output (play-testing).
@export var log_enemy_ai: bool = false

## The mission to play; set before the map enters the tree.
var mission: MissionDef = null
## What the player brings into the landing (campaign), or null; set with `mission`.
var modifiers: LandingModifiers = null
## A saved landing to restore instead of a fresh one (`snapshot()` of an earlier
## run); set with `mission` before the map enters the tree. Empty = a fresh landing.
var restore_state: Dictionary = {}
## The running mission, or null.
var runner: Mission = null
var heights: HeightField
var walk_grid: WalkGrid
var fog: FogOfWar
var presentation: MissionPresentation


func _ready() -> void:
	assert(map_def != null, "%s has no MapDef" % name)
	var started: int = Time.get_ticks_msec()
	Events.mission_started.emit()
	if mission == null and with_mission and map_def.default_mission_path != "":
		mission = load(map_def.default_mission_path) as MissionDef
	var player_faction: int = mission.player_faction if mission != null else 0
	var area: Rect2 = map_def.terrain_area
	heights = HeightField.from_physics(
		get_world_3d().direct_space_state, area, map_def.height_spacing
	)
	navigation_region.navigation_mesh = map_def.navmesh
	walk_grid = WalkGrid.from_navmesh(map_def.navmesh, area, map_def.height_spacing)
	var paths: NavmeshPathService = NavmeshPathService.new(
		get_world_3d().navigation_map, walk_grid, navigation_region
	)
	if map_def.has_flood_stages():
		paths.set_flood_stages(
			map_def.stage_navmeshes(),
			map_def.flood_levels,
			map_def.flood_clips,
			area,
			map_def.height_spacing
		)
	world.setup(context, paths, heights, economy_rules, player_faction, damage_table)
	world.build_bounds = map_def.build_bounds
	world.dry_crossings = map_def.dry_crossings
	world.canopy_zones = map_def.canopy_zones
	if not map_def.canopy_zones.is_empty():
		add_to_group(&"canopy")
	if fog_of_war:
		world.enable_vision(area, map_def.vision_cell)
	camera.heights = heights
	print("%s: terrain data built in %d ms" % [map_def.id, Time.get_ticks_msec() - started])
	if restore_state.is_empty():
		_place_landing(paths)
	else:
		_restore_landing(paths)
	if world.vision != null:
		# See the landing site from the first frame, not one sim tick later.
		world.vision.update_faction(
			player_faction, world.units, world.buildings, world.resource_nodes
		)
		fog = FogOfWar.new()
		fog.name = &"FogOfWar"
		add_child(fog)
		fog.setup(world.vision, player_faction)
	if hud != null:
		hud.set_map_colors(map_def.minimap_low, map_def.minimap_high)
	if hud != null and mission != null and mission.enemy_alert_meter:
		hud.show_alert_meter(mission.hostile_faction)
	if runner != null and restore_state.is_empty():
		runner.start()
	elif runner != null:
		var mission_data: Dictionary = restore_state.get("mission", {})
		runner.resume(mission_data)


func _exit_tree() -> void:
	var paths: NavmeshPathService = world.paths as NavmeshPathService if world != null else null
	if paths != null:
		paths.release()


## The landing as it is now, for a saved game: the sim clock, the world, the mission
## runner (objectives, script, AI), the camera's focus and the control groups.
## True when `point` is under a tree crown (asked by the sound of the canopy).
func is_under_canopy(point: Vector3) -> bool:
	var canopy: CanopySystem = world.planet as CanopySystem if world != null else null
	return canopy != null and canopy.is_under_canopy(point)


func snapshot() -> Dictionary:
	var groups: Dictionary = (
		selection_controller.control_groups().to_dict() if selection_controller != null else {}
	)
	return {
		"clock": context.sim_clock.to_dict(),
		"world": world.to_dict(),
		"mission": runner.to_dict() if runner != null else {},
		"camera": var_to_str(camera.get_focus()),
		"groups": groups,
	}


## A fresh landing: the map's resources, props and sites, the mission's forces.
func _place_landing(paths: NavmeshPathService) -> void:
	var started: int = Time.get_ticks_msec()
	_spawn_nodes(map_def.deposit, map_def.deposit_positions)
	_spawn_nodes(map_def.rich_deposit, map_def.rich_deposit_positions)
	_spawn_nodes(map_def.vent, map_def.vent_positions)
	_spawn_nodes(map_def.rich_vent, map_def.rich_vent_positions)
	if with_props:
		_spawn_props()
	_make_runner()
	if runner != null:
		runner.spawn_structures()
	_spawn_machines()
	_spawn_sites()
	paths.apply_cuts()
	paths.prepare_flood_stages()
	print(
		(
			"%s: %d resource nodes and the bases placed, navmesh cut in %d ms"
			% [map_def.id, world.resource_nodes.size(), Time.get_ticks_msec() - started]
		)
	)
	var roster: Array[UnitDef] = map_def.custodian_roster
	var posts: PackedVector3Array = map_def.custodian_positions
	for i: int in mini(roster.size(), posts.size()):
		var towards_centre: float = Mover.yaw_for(-posts[i])
		world.spawn_unit(roster[i], Factions.CUSTODIANS, posts[i], towards_centre)
	_make_presentation()
	if runner != null:
		runner.spawn_units()
	_center_camera()


## A saved landing: nothing is placed from the map's lists; the save has it all.
func _restore_landing(paths: NavmeshPathService) -> void:
	var started: int = Time.get_ticks_msec()
	var clock_data: Dictionary = restore_state.get("clock", {})
	if not clock_data.is_empty():
		context.sim_clock.from_dict(clock_data)
		context.sim_clock.paused = false
	# The runner first: it starts the planet rule and the perks the world restores into.
	_make_runner()
	var world_data: Dictionary = restore_state.get("world", {})
	world.from_dict(world_data)
	paths.apply_cuts()
	paths.prepare_flood_stages()
	_make_presentation()
	presentation.show_restored_state()
	var groups: Dictionary = restore_state.get("groups", {})
	if selection_controller != null:
		selection_controller.control_groups().from_dict(groups, world.entity)
	var focus_text: String = restore_state.get("camera", "")
	var focus: Variant = str_to_var(focus_text) if focus_text != "" else null
	if focus is Vector3:
		var point: Vector3 = focus
		camera.center_on(point)
	else:
		_center_camera()
	print(
		(
			"%s: landing restored (%d units, %d buildings) in %d ms"
			% [
				map_def.id,
				world.units.size(),
				world.buildings.size(),
				Time.get_ticks_msec() - started
			]
		)
	)


func _make_runner() -> void:
	if mission == null:
		return
	runner = Mission.new()
	runner.name = &"Mission"
	runner.log_enemy_ai = log_enemy_ai
	runner.modifiers = modifiers
	add_child(runner)
	runner.setup(mission, context, world, map_def.terrain_area)


func _make_presentation() -> void:
	presentation = MissionPresentation.new()
	presentation.name = &"MissionPresentation"
	add_child(presentation)
	presentation.setup(world, world.player_faction)


func _center_camera() -> void:
	if mission == null:
		camera.center_on(map_def.landing_zone)
		return
	if mission.camera_start != Vector3.INF:
		camera.center_on(mission.camera_start)
	elif runner != null and runner.player_hq != null:
		# Look a little in front of the Lander so its door and the units it
		# produces are not hidden behind the command panel.
		camera.center_on(runner.player_hq.position + Vector3(0.0, 0.0, 9.0))
	else:
		camera.center_on(mission.player_start)


func _spawn_sites() -> void:
	var discoveries: Array[DiscoveryDef] = map_def.discoveries
	for i: int in mini(discoveries.size(), map_def.discovery_positions.size()):
		var def: DiscoveryDef = discoveries[i]
		if def != null:
			var charted: bool = not Discovery.is_led_to(discoveries, def.id)
			if modifiers != null and modifiers.charts(def.id):
				charted = true
			world.spawn_site(def, map_def.discovery_positions[i], charted)


## The map's Antecedent machines (Hollow Meridian's engines), dormant and held by the
## Custodians until somebody reactivates one (ADR 0017).
func _spawn_machines() -> void:
	if map_def.machine == null:
		return
	for point: Vector3 in map_def.machine_positions:
		world.spawn_building(map_def.machine, Factions.CUSTODIANS, point, true)


func _spawn_props() -> void:
	if map_def.prop_layout == null:
		return
	for placement: PropPlacement in map_def.prop_layout.placements:
		if placement != null and placement.def != null:
			world.spawn_prop(placement.def, placement.position, placement.quarter_turns)


func _spawn_nodes(def: ResourceNodeDef, positions: PackedVector3Array) -> void:
	if def == null:
		return
	for point: Vector3 in positions:
		world.spawn_resource_node(def, point)
