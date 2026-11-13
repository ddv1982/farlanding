class_name Prop
extends Node3D
## A prop on the map (ADR 0011): a thin root holding its PropDef, its footprint and,
## when destructible, a Health. Spawned by SimWorld (which sets `def`,
## `quarter_turns`, `world` and `entity_id`), which also cuts it out of the navmesh
## and registers it as a sight blocker. Its look is a child: the def's model, or a
## placeholder box until the model exists. Props have no faction and are not
## selectable.

const SAVE_VERSION: int = 1
const GROUP: StringName = &"props"
## Props lower than this never block sight (eyes are at 1.6 m).
const MIN_SIGHT_HEIGHT: float = 1.5
const PLACEHOLDER_COLOR := Color(0.42, 0.36, 0.30)

var def: PropDef
var world: SimWorld = null
var entity_id: int = -1
## 0..3 quarter turns about +Y.
var quarter_turns: int = 0
## Null for indestructible props.
var health: Health = null
## Props are terrain-like: always drawn. Read by audio and UI.
var is_visible_to_player: bool = true
var is_dead: bool:
	get:
		return health != null and health.is_dead()
## True if it hides what is behind it.
var blocks_sight: bool:
	get:
		return def != null and def.blocks_sight and def.size.y >= MIN_SIGHT_HEIGHT


func _enter_tree() -> void:
	add_to_group(GROUP)


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


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"def": def.resource_path if def != null else "",
		"entity_id": entity_id,
		"position": var_to_str(position),
		"turns": quarter_turns,
		"health": health.to_dict() if health != null else {},
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Prop save version")
	var health_data: Dictionary = data.get("health", {})
	if health != null and not health_data.is_empty():
		health.from_dict(health_data)


## The def's model, or a placeholder box of the prop's size.
func _add_look() -> void:
	if def.model != null:
		var model: Node = def.model.instantiate()
		model.name = &"Model"
		add_child(model)
		return
	var box := BoxMesh.new()
	box.size = def.size
	var material := StandardMaterial3D.new()
	material.albedo_color = PLACEHOLDER_COLOR
	material.roughness = 0.9
	var mesh := MeshInstance3D.new()
	mesh.name = &"Placeholder"
	mesh.mesh = box
	mesh.material_override = material
	mesh.position.y = def.size.y * 0.5
	add_child(mesh)
