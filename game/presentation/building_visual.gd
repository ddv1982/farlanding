class_name BuildingVisual
extends Node3D
## Everything you can see of a building: model, team colour, selection ring,
## damage and the construction reveal. Holds no gameplay state.

const RING_SHADER: Shader = preload("res://presentation/shaders/selection_ring.gdshader")
const DISH_SPEED := 0.6

@export var model_scene: PackedScene
## Radius of the selection ring in metres.
@export var footprint_radius: float = 5.0

var _meshes: Array[MeshInstance3D] = []
var _dish: Node3D
var _ring: MeshInstance3D
var _height: float = 1.0


func _ready() -> void:
	if model_scene != null:
		var model := model_scene.instantiate() as Node3D
		add_child(model)
		_collect(model)
	for mesh in _meshes:
		_height = maxf(_height, mesh.position.y + mesh.get_aabb().end.y)
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"build_height", _height)
	_ring = _build_ring()
	add_child(_ring)
	set_selected(false)


func _process(delta: float) -> void:
	if _dish != null:
		_dish.rotate_y(DISH_SPEED * delta)


func set_team_color(color: Color) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"team_color", color)
	_ring.set_instance_shader_parameter(&"ring_color", color.lightened(0.35))


## 0 = just placed, 1 = finished. The model rises out of the ground as it grows.
func set_build_progress(progress: float) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"build_progress", clampf(progress, 0.0, 1.0))


## 0 = pristine, 1 = wrecked.
func set_damage(amount: float) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"damage", clampf(amount, 0.0, 1.0))


func set_selected(selected: bool) -> void:
	_ring.visible = selected


func _collect(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		_meshes.append(mesh)
	if String(node.name) == "dish":
		_dish = node as Node3D
	for child in node.get_children():
		_collect(child)


func _build_ring() -> MeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * footprint_radius * 2.0
	var material := ShaderMaterial.new()
	material.shader = RING_SHADER
	var ring := MeshInstance3D.new()
	ring.name = "SelectionRing"
	ring.mesh = quad
	ring.material_override = material
	ring.position.y = 0.12
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring
