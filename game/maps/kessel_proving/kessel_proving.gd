class_name KesselProving
extends Node3D
## Kessel Reach proving ground: wires the mission services together, lands the
## player's Lander (it becomes the HQ) with a small starting crew, places the Alloy
## deposits and Flux vents, and a small idle hostile group to practise orders on.
## Every spawn is data in the scene's exported properties.

## The terrain is 240 m square, centred on the origin.
const TERRAIN_AREA: Rect2 = Rect2(-120.0, -120.0, 240.0, 240.0)
const HEIGHT_SPACING: float = 1.0

@export var context: MissionContext
@export var world: SimWorld
@export var camera: RtsCamera
@export var navigation_region: NavigationRegion3D
@export var economy_rules: EconomyRules
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
@export_group("Hostiles")
@export var hostile_faction: int = 1
## Centre of the hostile group (about 45 m from the player start, on open ground).
@export var hostile_start: Vector3 = Vector3(-48.0, 0.0, 53.0)
@export var hostile_facing: Vector3 = Vector3(-1.0, 0.0, 1.0)
## One entry per hostile unit. They stand idle.
@export var hostile_roster: Array[UnitDef] = []

var heights: HeightField
var walk_grid: WalkGrid


func _ready() -> void:
	var started: int = Time.get_ticks_msec()
	heights = HeightField.from_physics(
		get_world_3d().direct_space_state, TERRAIN_AREA, HEIGHT_SPACING
	)
	walk_grid = WalkGrid.from_navmesh(
		navigation_region.navigation_mesh, TERRAIN_AREA, HEIGHT_SPACING
	)
	var paths: NavmeshPathService = NavmeshPathService.new(
		get_world_3d().navigation_map, walk_grid, navigation_region
	)
	world.setup(context, paths, heights, economy_rules, player_faction)
	world.build_bounds = build_bounds
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
	spawn_group(hostile_roster, hostile_faction, hostile_start, hostile_facing)


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


func _spawn_nodes(def: ResourceNodeDef, positions: PackedVector3Array) -> void:
	if def == null:
		return
	for point: Vector3 in positions:
		world.spawn_resource_node(def, point)
