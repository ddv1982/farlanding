class_name KesselProving
extends Node3D
## Kessel Reach proving ground: the map, not the mission. It builds the terrain data,
## wires the mission services (world, combat, fog of war), places the Alloy deposits
## and Flux vents, charts the discovery sites the orbital scan found (a chain's later
## steps stay hidden until led to), posts the dormant Custodian Wardens and scatters
## the map's natural cover (boulders, `prop_layout`). Then the
## MissionDef in `mission` supplies the forces and rules through a Mission node
## (missions/mission.gd): who lands where, the enemy, objectives, script. Without one
## it plays the default mission, so the scene also runs on its own.
##
## A saved landing (ADR 0013) is restored instead when `restore_state` is set: the
## map builds its terrain data and services as usual, then places nothing itself and
## restores everything from the save (resource nodes, sites, props, buildings, units,
## the storm, the mission runner and its AI), the camera and the control groups.
## `snapshot()` produces that dictionary for a running landing.

## The terrain is 240 m square, centred on the origin.
const TERRAIN_AREA: Rect2 = Rect2(-120.0, -120.0, 240.0, 240.0)
const HEIGHT_SPACING: float = 1.0
## Vision grid cell size, in metres.
const VISION_CELL: float = 2.0
## The usual landing site (the conquest Lander's place).
const LANDING_ZONE: Vector3 = Vector3(-80.0, 0.0, 85.0)

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
## Played when nothing set `mission` before the map entered the tree (a path, not a
## reference: the mission refers to this scene).
@export_file("*.tres") var default_mission_path: String = ""
## False: terrain, resources and sites only, no mission (benchmarks).
@export var with_mission: bool = true
## Buildings may only be placed inside this area (world X/Z).
@export var build_bounds: Rect2 = Rect2(-104.0, -104.0, 208.0, 208.0)
@export_group("Resources")
@export var deposit: ResourceNodeDef
@export var deposit_positions: PackedVector3Array = PackedVector3Array()
@export var rich_deposit: ResourceNodeDef
@export var rich_deposit_positions: PackedVector3Array = PackedVector3Array()
@export var vent: ResourceNodeDef
@export var vent_positions: PackedVector3Array = PackedVector3Array()
@export_group("Discovery")
## Discovery sites, one position per entry of `discovery_positions`.
@export var discoveries: Array[DiscoveryDef] = []
@export var discovery_positions: PackedVector3Array = PackedVector3Array()
## Dormant Custodians, one position per entry of `custodian_positions`.
@export var custodian_roster: Array[UnitDef] = []
@export var custodian_positions: PackedVector3Array = PackedVector3Array()
@export_group("Props")
## Natural cover every mission on this map has (boulders); the mission adds its own.
@export var prop_layout: PropLayout
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
	var started: int = Time.get_ticks_msec()
	Events.mission_started.emit()
	if mission == null and with_mission and default_mission_path != "":
		mission = load(default_mission_path) as MissionDef
	var player_faction: int = mission.player_faction if mission != null else 0
	heights = HeightField.from_physics(
		get_world_3d().direct_space_state, TERRAIN_AREA, HEIGHT_SPACING
	)
	walk_grid = WalkGrid.from_navmesh(
		navigation_region.navigation_mesh, TERRAIN_AREA, HEIGHT_SPACING
	)
	var paths: NavmeshPathService = NavmeshPathService.new(
		get_world_3d().navigation_map, walk_grid, navigation_region
	)
	world.setup(context, paths, heights, economy_rules, player_faction, damage_table)
	world.build_bounds = build_bounds
	if fog_of_war:
		world.enable_vision(TERRAIN_AREA, VISION_CELL)
	camera.heights = heights
	print("kessel_proving: terrain data built in %d ms" % (Time.get_ticks_msec() - started))
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
	if hud != null and mission != null and mission.enemy_alert_meter:
		hud.show_alert_meter(mission.hostile_faction)
	if runner != null and restore_state.is_empty():
		runner.start()
	elif runner != null:
		var mission_data: Dictionary = restore_state.get("mission", {})
		runner.resume(mission_data)


## The landing as it is now, for a saved game: the sim clock, the world, the mission
## runner (objectives, script, AI), the camera's focus and the control groups.
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
	_spawn_nodes(deposit, deposit_positions)
	_spawn_nodes(rich_deposit, rich_deposit_positions)
	_spawn_nodes(vent, vent_positions)
	_spawn_props()
	_make_runner()
	if runner != null:
		runner.spawn_structures()
	_spawn_sites()
	paths.apply_cuts()
	print(
		(
			"kessel_proving: %d resource nodes and the bases placed, navmesh cut in %d ms"
			% [world.resource_nodes.size(), Time.get_ticks_msec() - started]
		)
	)
	for i: int in mini(custodian_roster.size(), custodian_positions.size()):
		var towards_centre: float = Mover.yaw_for(-custodian_positions[i])
		world.spawn_unit(
			custodian_roster[i], Factions.CUSTODIANS, custodian_positions[i], towards_centre
		)
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
			"kessel_proving: landing restored (%d units, %d buildings) in %d ms"
			% [world.units.size(), world.buildings.size(), Time.get_ticks_msec() - started]
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
	runner.setup(mission, context, world, TERRAIN_AREA)


func _make_presentation() -> void:
	presentation = MissionPresentation.new()
	presentation.name = &"MissionPresentation"
	add_child(presentation)
	presentation.setup(world, world.player_faction)


func _center_camera() -> void:
	if mission == null:
		camera.center_on(LANDING_ZONE)
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
	for i: int in mini(discoveries.size(), discovery_positions.size()):
		var def: DiscoveryDef = discoveries[i]
		if def != null:
			var charted: bool = not Discovery.is_led_to(discoveries, def.id)
			if modifiers != null and modifiers.charts(def.id):
				charted = true
			world.spawn_site(def, discovery_positions[i], charted)


func _spawn_props() -> void:
	if prop_layout == null:
		return
	for placement: PropPlacement in prop_layout.placements:
		if placement != null and placement.def != null:
			world.spawn_prop(placement.def, placement.position, placement.quarter_turns)


func _spawn_nodes(def: ResourceNodeDef, positions: PackedVector3Array) -> void:
	if def == null:
		return
	for point: Vector3 in positions:
		world.spawn_resource_node(def, point)
