class_name Prop
extends Node3D
## A prop on the map (ADR 0011): a thin root holding its PropDef, its footprint and,
## when destructible, a Health. Spawned by SimWorld (which sets `def`,
## `quarter_turns`, `world` and `entity_id`), which also cuts it out of the navmesh
## and registers it as a sight blocker. Its look is a child: the def's model, or a
## placeholder box until the model exists. Props have no faction and are not
## selectable. A carriable prop (an artefact) can be lifted by a unit's Carrier: it
## then follows its carrier (`carrier`) until dropped.

## A unit lifted it (`carrier`) or put it down (null). Presentation shows the carried
## look; audio may play a pick-up or drop.
signal carried_changed(carrier: Node3D)

## 2: carriable props remember being lifted and by whom last.
const SAVE_VERSION: int = 2
const GROUP: StringName = &"props"
## Carriable props are also in this group: audio hums for them (ADR 0014).
const ARTEFACTS_GROUP: StringName = &"artefacts"
## A model's part of this name turns slowly (the artefact's core).
const SPIN_PART: StringName = &"core"
## Radians per second the spinning part turns.
const SPIN_SPEED: float = 0.6
## Props lower than this never block sight (eyes are at 1.6 m).
const MIN_SIGHT_HEIGHT: float = 1.5
const PLACEHOLDER_COLOR := Color(0.42, 0.36, 0.30)
## A carriable prop's placeholder colour (until its model exists).
const CARRIABLE_COLOR := Color(0.75, 0.6, 1.0)
## A carried prop rides this far above its carrier's origin.
const CARRY_LIFT: float = 1.9

var def: PropDef
var world: SimWorld = null
var entity_id: int = -1
## 0..3 quarter turns about +Y.
var quarter_turns: int = 0
## Null for indestructible props.
var health: Health = null
## The unit carrying it, or null (carriable props).
var carrier: Unit = null
## True once a unit lifted it (it is no longer where the map put it).
var lifted: bool = false
## The faction of the unit that carried it last, or -1 (announcements, ADR 0014).
var last_faction: int = -1
## Props are terrain-like: always drawn. Read by audio and UI. A carried prop is seen
## as its carrier is.
var is_visible_to_player: bool = true
var is_dead: bool:
	get:
		return health != null and health.is_dead()
## True if it hides what is behind it.
var blocks_sight: bool:
	get:
		return def != null and def.blocks_sight and def.size.y >= MIN_SIGHT_HEIGHT

var _spinner: Node3D = null


func _enter_tree() -> void:
	add_to_group(GROUP)
	if def != null and def.carriable:
		add_to_group(ARTEFACTS_GROUP)


func _process(delta: float) -> void:
	if _spinner != null:
		_spinner.rotate_y(SPIN_SPEED * delta)
	if carrier == null or not is_instance_valid(carrier):
		# Lying on the ground it is terrain-like again: always drawn.
		carrier = null
		is_visible_to_player = true
		visible = true
		return
	position = carrier.position + Vector3.UP * CARRY_LIFT
	# Carried, it is seen exactly as its carrier is: it must not give away a carrier
	# the fog hides.
	is_visible_to_player = carrier.is_visible_to_player
	visible = carrier.is_visible_to_player


func _ready() -> void:
	rotation.y = quarter_turns * PI * 0.5
	if def == null:
		return
	if def.is_destructible() and health == null:
		health = Health.new()
		health.name = &"Health"
		add_child(health)
		health.setup(def.max_health, def.armour_type, self)
	_add_look()


## Ground footprint (world X/Z), turned with the prop.
func footprint() -> Rect2:
	var extent: Vector2 = size_on_ground()
	return Rect2(Vector2(position.x, position.z) - extent * 0.5, extent)


## Width and depth on the ground after turning.
func size_on_ground() -> Vector2:
	if def == null:
		return Vector2.ONE
	if quarter_turns % 2 == 1:
		return Vector2(def.size.z, def.size.x)
	return Vector2(def.size.x, def.size.z)


func height() -> float:
	return def.size.y if def != null else 0.0


## Half its larger ground extent: how close a unit must come to reach it.
func radius() -> float:
	var extent: Vector2 = size_on_ground()
	return maxf(extent.x, extent.y) * 0.5


func is_carriable() -> bool:
	return def != null and def.carriable and not is_dead


## True while a living unit carries it.
func is_carried() -> bool:
	return carrier != null and is_instance_valid(carrier) and not carrier.is_dead


## Where it is in the simulation: its carrier's position while carried.
func sim_position() -> Vector3:
	if is_carried():
		return carrier.sim_position()
	return position


## True once a unit has lifted it.
func was_moved() -> bool:
	return lifted


## The faction of the unit carrying it, or -1.
func carrier_faction() -> int:
	return carrier.faction if is_carried() else -1


## `point` on the ground (props stand on the terrain).
func ground_point(point: Vector3) -> Vector3:
	if world != null and world.heights != null:
		point.y = world.heights.sample(point.x, point.z)
	return point


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"def": def.resource_path if def != null else "",
		"entity_id": entity_id,
		"position": var_to_str(ground_point(sim_position())),
		"turns": quarter_turns,
		"health": health.to_dict() if health != null else {},
		"lifted": lifted,
		"last_faction": last_faction,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported Prop save version")
	lifted = data.get("lifted", false)
	last_faction = data.get("last_faction", -1)
	var health_data: Dictionary = data.get("health", {})
	if health != null and not health_data.is_empty():
		health.from_dict(health_data)


## The def's model, or a placeholder box of the prop's size.
func _add_look() -> void:
	if def.model != null:
		var model: Node = def.model.instantiate()
		model.name = &"Model"
		add_child(model)
		_spinner = model.find_child(String(SPIN_PART), true, false) as Node3D
		return
	var box := BoxMesh.new()
	box.size = def.size
	var material := StandardMaterial3D.new()
	material.albedo_color = CARRIABLE_COLOR if def.carriable else PLACEHOLDER_COLOR
	material.roughness = 0.9
	var mesh := MeshInstance3D.new()
	mesh.name = &"Placeholder"
	mesh.mesh = box
	mesh.material_override = material
	mesh.position.y = def.size.y * 0.5
	add_child(mesh)
