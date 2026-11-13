class_name KesselProving
extends Node3D
## Kessel Reach proving ground: wires the mission services together (combat, fog of
## war, win/lose), lands the player's Lander (it becomes the HQ) with a small starting
## crew, places the Alloy deposits and Flux vents, and sets up a Combine base on the
## far side of the basin, run by a Commander AI (ai/commander.gd), charts the
## discovery sites the orbital scan found (a chain's later steps stay hidden until
## led to) and posts the dormant Custodian Wardens. The player wins by destroying
## every Combine unit and building (Custodians do not count) and loses with the
## Lander. Every spawn is data in the exported properties.

## The terrain is 240 m square, centred on the origin.
const TERRAIN_AREA: Rect2 = Rect2(-120.0, -120.0, 240.0, 240.0)
const HEIGHT_SPACING: float = 1.0
## Vision grid cell size, in metres.
const VISION_CELL: float = 2.0

@export var context: MissionContext
@export var world: SimWorld
@export var camera: RtsCamera
@export var navigation_region: NavigationRegion3D
@export var economy_rules: EconomyRules
## Armour x damage multipliers for this mission.
@export var damage_table: DamageTable
## Fog of war on (off shows the whole map, for testing).
@export var fog_of_war: bool = true
@export var player_faction: int = 0
## Where the Lander stands (its centre).
@export var player_start: Vector3 = Vector3(-80.0, 0.0, 85.0)
@export var lander: BuildingDef
## Starting crew, lined up in front of the Lander's door. Haulers start harvesting.
@export var start_roster: Array[UnitDef] = []
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
@export_group("Combine")
@export var hostile_faction: int = 1
## The Combine base, pre-built: its HQ (a Hub) first, then its other buildings.
@export var hostile_hq: BuildingDef
@export var hostile_hq_position: Vector3 = Vector3(66.0, 0.0, -95.0)
@export var hostile_buildings: Array[BuildingDef] = []
## One position per entry of `hostile_buildings` (building centres).
@export var hostile_building_positions: PackedVector3Array = PackedVector3Array()
## The Combine crew, lined up at `hostile_start` facing `hostile_facing`: harvesters
## start mining, the rest wait for the commander.
@export var hostile_roster: Array[UnitDef] = []
@export var hostile_start: Vector3 = Vector3(56.0, 0.0, -83.0)
@export var hostile_facing: Vector3 = Vector3(0.0, 0.0, 1.0)
@export_group("Enemy AI")
## The commander that plays the Combine; none leaves the base idle (testing).
@export var commander_profile: CommanderProfile
@export_enum("easy", "normal", "hard") var enemy_difficulty: String = "easy"
## Prints the commander's notable decisions to the output (play-testing).
@export var log_enemy_ai: bool = false

var heights: HeightField
var walk_grid: WalkGrid
var outcome: ConquestOutcome
var fog: FogOfWar
var commander: Commander

var _outcome_check_pending: bool = false


func _ready() -> void:
	var started: int = Time.get_ticks_msec()
	Events.mission_started.emit()
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
	# Look a little in front of the Lander so its door and the units it
	# produces are not hidden behind the command panel.
	camera.center_on(player_start + Vector3(0.0, 0.0, 9.0))
	print("kessel_proving: terrain data built in %d ms" % (Time.get_ticks_msec() - started))
	started = Time.get_ticks_msec()
	_spawn_nodes(deposit, deposit_positions)
	_spawn_nodes(rich_deposit, rich_deposit_positions)
	_spawn_nodes(vent, vent_positions)
	var hq: Building = null
	if lander != null:
		hq = world.spawn_building(lander, player_faction, player_start, true)
	_spawn_hostile_base()
	_spawn_sites()
	paths.apply_cuts()
	print(
		(
			"kessel_proving: %d resource nodes and the Lander placed, navmesh cut in %d ms"
			% [world.resource_nodes.size(), Time.get_ticks_msec() - started]
		)
	)
	var crew_at: Vector3 = hq.door_position() + Vector3(0.0, 0.0, -5.0) if hq else player_start
	for unit: Unit in spawn_group(start_roster, player_faction, crew_at, Vector3.FORWARD):
		if unit.harvester != null:
			world.auto_harvest(unit, unit.sim_position())
	for unit: Unit in spawn_group(hostile_roster, hostile_faction, hostile_start, hostile_facing):
		if unit.harvester != null:
			world.auto_harvest(unit, unit.sim_position())
	for i: int in mini(custodian_roster.size(), custodian_positions.size()):
		var towards_centre: float = Mover.yaw_for(-custodian_positions[i])
		world.spawn_unit(
			custodian_roster[i], Factions.CUSTODIANS, custodian_positions[i], towards_centre
		)
	if world.vision != null:
		# See the landing site from the first frame, not one sim tick later.
		world.vision.update_faction(
			player_faction, world.units, world.buildings, world.resource_nodes
		)
		fog = FogOfWar.new()
		fog.name = &"FogOfWar"
		add_child(fog)
		fog.setup(world.vision, player_faction)
	outcome = ConquestOutcome.new(player_faction, lander)
	Events.entity_died.connect(_on_entity_died)
	if commander_profile != null:
		commander = Commander.new()
		commander.name = &"Commander"
		add_child(commander)
		commander.verbose = log_enemy_ai
		commander.setup(
			context,
			world,
			hostile_faction,
			commander_profile,
			StringName(enemy_difficulty),
			TERRAIN_AREA
		)


## Spawns `defs` as one formation centred on `center`, facing `facing`.
func spawn_group(
	defs: Array[UnitDef], faction: int, center: Vector3, facing: Vector3
) -> Array[Unit]:
	var spawned: Array[Unit] = []
	if defs.is_empty():
		return spawned
	var radii: PackedFloat32Array = PackedFloat32Array()
	for def: UnitDef in defs:
		radii.append(def.radius)
	var formation: Formation = Formation.new(
		defs.size(), center, facing, Formation.spacing_for(radii), world.paths.is_walkable
	)
	var yaw: float = Mover.yaw_for(formation.forward)
	for i: int in defs.size():
		spawned.append(world.spawn_unit(defs[i], faction, formation.slots[i], yaw))
	return spawned


# Judged once the frame's deaths are all in, not per death: if the Lander and the
# last enemy die together, the order they died in must not decide the mission.
func _on_entity_died(_entity: Node3D) -> void:
	if _outcome_check_pending:
		return
	_outcome_check_pending = true
	_check_outcome.call_deferred()


func _check_outcome() -> void:
	_outcome_check_pending = false
	outcome.check(world)


func _spawn_hostile_base() -> void:
	if hostile_hq != null:
		world.spawn_building(hostile_hq, hostile_faction, hostile_hq_position, true)
	for i: int in mini(hostile_buildings.size(), hostile_building_positions.size()):
		world.spawn_building(
			hostile_buildings[i], hostile_faction, hostile_building_positions[i], true
		)


func _spawn_sites() -> void:
	for i: int in mini(discoveries.size(), discovery_positions.size()):
		var def: DiscoveryDef = discoveries[i]
		if def != null:
			var charted: bool = not Discovery.is_led_to(discoveries, def.id)
			world.spawn_site(def, discovery_positions[i], charted)


func _spawn_nodes(def: ResourceNodeDef, positions: PackedVector3Array) -> void:
	if def == null:
		return
	for point: Vector3 in positions:
		world.spawn_resource_node(def, point)
