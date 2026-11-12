class_name KesselProving
extends Node3D
## Kessel Reach proving ground: wires the mission services together and spawns the
## player's starting force and a small idle hostile group to practise orders on.

## The terrain is 240 m square, centred on the origin.
const TERRAIN_AREA: Rect2 = Rect2(-120.0, -120.0, 240.0, 240.0)
const HEIGHT_SPACING: float = 1.0

@export var context: MissionContext
@export var world: SimWorld
@export var camera: RtsCamera
@export var navigation_region: NavigationRegion3D
@export var player_faction: int = 0
@export var player_start: Vector3 = Vector3(-80.0, 0.0, 85.0)
## Direction the starting force faces (toward the basin centre).
@export var player_facing: Vector3 = Vector3(1.0, 0.0, -1.0)
## One entry per starting unit, front rows first.
@export var start_roster: Array[UnitDef] = []
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
	var paths: NavmeshPathService = NavmeshPathService.new(get_world_3d().navigation_map, walk_grid)
	world.setup(context, paths, heights)
	camera.heights = heights
	camera.center_on(player_start)
	print("kessel_proving: terrain data built in %d ms" % (Time.get_ticks_msec() - started))
	spawn_group(start_roster, player_faction, player_start, player_facing)
	spawn_group(hostile_roster, hostile_faction, hostile_start, hostile_facing)


## Spawns `defs` as one formation centred on `center`, facing `facing`.
func spawn_group(defs: Array[UnitDef], faction: int, center: Vector3, facing: Vector3) -> void:
	if defs.is_empty():
		return
	var radii: PackedFloat32Array = PackedFloat32Array()
	for def: UnitDef in defs:
		radii.append(def.radius)
	var formation: Formation = Formation.new(
		defs.size(), center, facing, Formation.spacing_for(radii), world.paths.is_walkable
	)
	var yaw: float = Mover.yaw_for(formation.forward)
	for i: int in defs.size():
		world.spawn_unit(defs[i], faction, formation.slots[i], yaw)
