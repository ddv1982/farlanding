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
	started = Time.get_ticks_msec()
	_spawn_nodes(deposit, deposit_positions)
	_spawn_nodes(rich_deposit, rich_deposit_positions)
	_spawn_nodes(vent, vent_positions)
	_spawn_props()
	if mission != null:
		runner = Mission.new()
		runner.name = &"Mission"
		runner.log_enemy_ai = log_enemy_ai
		add_child(runner)
		runner.setup(mission, context, world, TERRAIN_AREA)
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
	presentation = MissionPresentation.new()
	presentation.name = &"MissionPresentation"
	add_child(presentation)
	presentation.setup(world, player_faction)
	if runner != null:
		runner.spawn_units()
	_center_camera()
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
	if runner != null:
		runner.start()


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
