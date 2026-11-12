class_name UnitVisual
extends Node3D
## Everything you can see of a unit: its model, team colour, selection ring and
## the code-driven motion of its moving parts. Holds no gameplay state — the
## simulation tells it how the unit is moving and what it is aiming at.
##
## Model parts are found by the names the art pipeline reserves:
## wheel_*, leg_*, turret, barrel, dish (see art/pipeline/fl.py).

const RING_SHADER: Shader = preload("res://presentation/shaders/selection_ring.gdshader")
const WHEEL_RADIUS := 0.4
const LEG_SWING := 0.5
const STRIDE_LENGTH := 2.2
const DISH_SPEED := 1.6
const TURRET_TURN_SPEED := 4.0

@export var model_scene: PackedScene
## Radius of the selection ring in metres.
@export var footprint_radius: float = 1.5
## Hovering units bob and bank instead of rolling.
@export var hovers: bool = false

var _model: Node3D
var _meshes: Array[MeshInstance3D] = []
var _wheels: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _turret: Node3D
var _dish: Node3D
var _ring: MeshInstance3D
var _speed: float = 0.0
var _stride_phase: float = 0.0
var _time: float = 0.0
var _aim_point: Vector3 = Vector3.ZERO
var _has_aim: bool = false


func _ready() -> void:
	if model_scene != null:
		_model = model_scene.instantiate() as Node3D
		add_child(_model)
		_collect_parts(_model)
	_ring = _build_ring()
	add_child(_ring)
	set_selected(false)


func _process(delta: float) -> void:
	_time += delta
	for wheel in _wheels:
		wheel.rotate_x(-_speed * delta / WHEEL_RADIUS)
	if not _legs.is_empty():
		_stride_phase += _speed * delta / STRIDE_LENGTH * TAU
		var swing := sin(_stride_phase) * LEG_SWING * minf(_speed, 1.0)
		for index in _legs.size():
			_legs[index].rotation.x = swing if index % 2 == 0 else -swing
		if _model != null:
			_model.position.y = absf(sin(_stride_phase)) * 0.06 * minf(_speed, 1.0)
	if hovers and _model != null:
		_model.position.y = 0.12 * sin(_time * 2.3)
		_model.rotation.x = lerpf(_model.rotation.x, -0.02 * _speed, 4.0 * delta)
	if _dish != null:
		_dish.rotate_y(DISH_SPEED * delta)
	if _turret != null:
		_turn_turret(delta)


## Speed along the unit's facing, in metres per second.
func set_motion(speed: float) -> void:
	_speed = speed


func set_team_color(color: Color) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"team_color", color)
	_ring.set_instance_shader_parameter(&"ring_color", color.lightened(0.35))


## 0 = pristine, 1 = wrecked.
func set_damage(amount: float) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"damage", clampf(amount, 0.0, 1.0))


func set_selected(selected: bool) -> void:
	_ring.visible = selected


## World-space point the turret should track; call clear_aim() to face forward.
func aim_at(point: Vector3) -> void:
	_aim_point = point
	_has_aim = true


func clear_aim() -> void:
	_has_aim = false


func _turn_turret(delta: float) -> void:
	var target_yaw := 0.0
	if _has_aim:
		var local := to_local(_aim_point)
		target_yaw = atan2(-local.x, -local.z)
	_turret.rotation.y = lerp_angle(_turret.rotation.y, target_yaw, TURRET_TURN_SPEED * delta)


func _collect_parts(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		_meshes.append(mesh)
	var part := node as Node3D
	if part != null:
		var part_name := String(part.name)
		if part_name.begins_with("wheel_"):
			_wheels.append(part)
		elif part_name.begins_with("leg_"):
			_legs.append(part)
		elif part_name == "turret":
			_turret = part
		elif part_name == "dish":
			_dish = part
	for child in node.get_children():
		_collect_parts(child)


func _build_ring() -> MeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * footprint_radius * 2.0
	var material := ShaderMaterial.new()
	material.shader = RING_SHADER
	var ring := MeshInstance3D.new()
	ring.name = "SelectionRing"
	ring.mesh = quad
	ring.material_override = material
	ring.position.y = 0.08
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring
