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
const DUST_COLOR := Color(0.78, 0.58, 0.40, 0.55)
## Speed in m/s at which a unit starts raising dust.
const DUST_MIN_SPEED := 1.0

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
var _health_bar: HealthBar
var _dust: GPUParticles3D
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
	_dust = _build_dust()
	add_child(_dust)
	_health_bar = HealthBar.create(footprint_radius * 1.6, 2.6)
	add_child(_health_bar)
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
	_dust.emitting = absf(speed) > DUST_MIN_SPEED


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
	_health_bar.set_selected(selected)


## 0 = plain, 1 = cloaked (drawn as a shimmering ghost; the owner still sees it).
func set_cloaked(amount: float) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"cloak", clampf(amount, 0.0, 1.0))


## 1 = full health, 0 = dead. Also drives the worn look of the model.
func set_health(fraction: float) -> void:
	_health_bar.set_fraction(fraction)
	set_damage(1.0 - clampf(fraction, 0.0, 1.0))


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


func _build_dust() -> GPUParticles3D:
	var fade := Gradient.new()
	fade.set_color(0, DUST_COLOR)
	fade.set_color(1, Color(DUST_COLOR, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(footprint_radius * 0.5, 0.05, footprint_radius * 0.3)
	process.direction = Vector3.UP
	process.spread = 60.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 1.0
	process.gravity = Vector3(0.0, 0.25, 0.0)
	process.damping_min = 0.6
	process.damping_max = 1.0
	process.scale_min = 0.7
	process.scale_max = 1.3
	process.scale_curve = grow_texture
	process.color_ramp = fade_texture
	var puff := GradientTexture2D.new()
	var soft := Gradient.new()
	soft.set_color(0, Color.WHITE)
	soft.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	puff.gradient = soft
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 64
	puff.height = 64
	var surface := StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	surface.vertex_color_use_as_albedo = true
	surface.albedo_texture = puff
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * footprint_radius * 1.4
	quad.material = surface
	var dust := GPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 14
	dust.lifetime = 1.3
	dust.emitting = false
	dust.process_material = process
	dust.draw_pass_1 = quad
	dust.position = Vector3(0.0, 0.25, footprint_radius * 0.6)
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return dust
