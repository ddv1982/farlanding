class_name BuildingVisual
extends Node3D
## Everything you can see of a building: model, team colour, selection ring,
## damage and the construction reveal. Holds no gameplay state.

const RING_SHADER: Shader = preload("res://presentation/shaders/selection_ring.gdshader")
const DISH_SPEED := 0.6
const TURRET_TURN_SPEED := 4.0
const SITE_COLOR := Color(0.25, 0.95, 1.0, 0.22)
## Share of the model already showing when construction starts, so a new site
## is never invisible.
const SITE_START := 0.07
## How wrecked a sabotaged building looks at least (lights out).
const SABOTAGED_DAMAGE := 0.85
const SPARK_COLOR := Color(2.4, 1.5, 0.5)

@export var model_scene: PackedScene
## Radius of the selection ring in metres.
@export var footprint_radius: float = 5.0

var _meshes: Array[MeshInstance3D] = []
var _dish: Node3D
var _turret: Node3D
var _aim_point: Vector3 = Vector3.ZERO
var _has_aim: bool = false
var _ring: MeshInstance3D
var _health_bar: HealthBar
var _site: MeshInstance3D
var _height: float = 1.0
var _damage: float = 0.0
var _sabotaged: bool = false
var _sparks: GPUParticles3D


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
	_site = _build_site_plate()
	add_child(_site)
	_health_bar = HealthBar.create(footprint_radius * 1.2, _height + 1.2)
	add_child(_health_bar)
	set_selected(false)


func _process(delta: float) -> void:
	if _dish != null:
		_dish.rotate_y(DISH_SPEED * delta)
	if _turret != null:
		# Building models keep their front towards +Z (see art/pipeline/fl.py).
		var target_yaw := 0.0
		if _has_aim:
			var local := to_local(_aim_point)
			target_yaw = atan2(local.x, local.z)
		_turret.rotation.y = lerp_angle(_turret.rotation.y, target_yaw, TURRET_TURN_SPEED * delta)


func set_team_color(color: Color) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"team_color", color)
	_ring.set_instance_shader_parameter(&"ring_color", color.lightened(0.35))


## 0 = just placed, 1 = finished. The model rises out of the ground as it grows.
func set_build_progress(progress: float) -> void:
	var done := clampf(progress, 0.0, 1.0)
	var shown := 1.0 if done >= 1.0 else lerpf(SITE_START, 0.999, done)
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"build_progress", shown)
	_site.visible = done < 1.0


## 0 = pristine, 1 = wrecked.
func set_damage(amount: float) -> void:
	_damage = clampf(amount, 0.0, 1.0)
	# A sabotaged building is dead inside whatever its hull looks like.
	var shown := maxf(_damage, SABOTAGED_DAMAGE) if _sabotaged else _damage
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"damage", shown)


## A sabotaged building goes dark and throws sparks from its roof.
func set_sabotaged(sabotaged: bool) -> void:
	_sabotaged = sabotaged
	set_damage(_damage)
	if sabotaged and _sparks == null:
		_sparks = _build_sparks()
		add_child(_sparks)
	if _sparks != null:
		_sparks.emitting = sabotaged


func set_selected(selected: bool) -> void:
	_ring.visible = selected
	_health_bar.set_selected(selected)


## 1 = full health, 0 = dead. Also drives the worn look of the model.
func set_health(fraction: float) -> void:
	_health_bar.set_fraction(fraction)
	set_damage(1.0 - clampf(fraction, 0.0, 1.0))


## World-space point a turret should track; clear_aim() returns it to rest.
func aim_at(point: Vector3) -> void:
	_aim_point = point
	_has_aim = true


func clear_aim() -> void:
	_has_aim = false


func _collect(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		_meshes.append(mesh)
	if String(node.name) == "dish":
		_dish = node as Node3D
	elif String(node.name) == "turret":
		_turret = node as Node3D
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


## Glowing pad marking the footprint while the building is under construction.
func _build_site_plate() -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = SITE_COLOR
	var pad := CylinderMesh.new()
	pad.top_radius = footprint_radius * 0.85
	pad.bottom_radius = footprint_radius * 0.85
	pad.height = 0.05
	pad.radial_segments = 8
	var plate := MeshInstance3D.new()
	plate.name = "SitePlate"
	plate.mesh = pad
	plate.material_override = material
	plate.position.y = 0.1
	plate.visible = false
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return plate


func _build_sparks() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(footprint_radius * 0.35, 0.2, footprint_radius * 0.35)
	process.direction = Vector3.UP
	process.spread = 70.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 5.0
	process.gravity = Vector3(0.0, -9.0, 0.0)
	var surface := StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	surface.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	surface.albedo_color = SPARK_COLOR
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = surface
	var sparks := GPUParticles3D.new()
	sparks.amount = 14
	sparks.lifetime = 0.7
	# Bursts with dead time between them read as shorting, not as a fountain.
	sparks.explosiveness = 0.85
	sparks.randomness = 0.6
	sparks.process_material = process
	sparks.draw_pass_1 = quad
	# Named only after the process material is set (see UnitVisual's dust: naming it
	# first leaks one shader RID at exit under the headless renderer).
	sparks.name = "SabotageSparks"
	sparks.position.y = _height * 0.8
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sparks
