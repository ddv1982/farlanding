class_name CombatVfx
extends Node3D
## Draws combat from the event bus: muzzle flashes, projectile looks, impacts,
## explosions and scorch marks. The simulation never calls this; add one
## instance to a map and it listens to `Events`.
##
## Reads from a WeaponDef: `projectile_style` (&"bolt", &"shell", &"lance") and
## `impact_size` (metres; 0 = sparks only). Reads `faction` and
## `is_visible_to_player` from entities when they have them.

const CONCORD_COLOR := Color(0.35, 0.92, 1.0)
const COMBINE_COLOR := Color(0.25, 1.0, 0.55)
const SHELL_COLOR := Color(1.0, 0.55, 0.15)
const FIRE_COLOR := Color(1.0, 0.62, 0.2)
const SMOKE_COLOR := Color(0.22, 0.17, 0.14, 0.7)
## Brightness above 1 so the glow post-effect picks effects up.
const GLOW := 3.0
## Effects alive at once; beyond this new ones are skipped, not queued.
const MAX_EFFECTS := 80
const SCORCH_SECONDS := 14.0

var _puff: Texture2D
var _additive: StandardMaterial3D
var _blended: StandardMaterial3D
var _scorch: StandardMaterial3D
var _live: int = 0


func _ready() -> void:
	_puff = _make_puff_texture()
	_additive = _make_material(BaseMaterial3D.BLEND_MODE_ADD)
	_blended = _make_material(BaseMaterial3D.BLEND_MODE_MIX)
	_scorch = _make_material(BaseMaterial3D.BLEND_MODE_MIX)
	_scorch.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.projectile_launched.connect(_on_projectile_launched)
	Events.projectile_impacted.connect(_on_projectile_impacted)
	Events.entity_died.connect(_on_entity_died)


func _on_weapon_fired(
	shooter: Node3D, _weapon: Resource, muzzle: Vector3, _target: Vector3
) -> void:
	if _hidden(shooter):
		return
	flash(muzzle, _faction_color(shooter), 0.9, 0.07)


func _on_projectile_launched(projectile: Node3D, weapon: Resource) -> void:
	if not is_instance_valid(projectile):
		return
	var style: StringName = _string_name(weapon, &"projectile_style", &"bolt")
	var color: Color = _faction_color(projectile)
	match style:
		&"shell":
			projectile.add_child(_solid(_sphere(0.16), SHELL_COLOR, Vector3.ZERO))
			projectile.add_child(_trail(SMOKE_COLOR, 0.5, 0.5))
		&"lance":
			projectile.add_child(_solid(_capsule(0.045, 2.6), color, Vector3(0, 0, 0.9)))
		_:
			projectile.add_child(_solid(_capsule(0.07, 0.9), color, Vector3(0, 0, 0.3)))


func _on_projectile_impacted(weapon: Resource, at: Vector3, victim: Node3D) -> void:
	if victim != null and _hidden(victim):
		return
	var size: float = _float(weapon, &"impact_size", 0.0)
	if size > 0.0:
		explosion(at, size)
	else:
		sparks(at, FIRE_COLOR, 8)
		flash(at, Color.WHITE, 0.6, 0.06)


func _on_entity_died(entity: Node3D) -> void:
	if not is_instance_valid(entity) or _hidden(entity):
		return
	var size: float = 1.6
	var def: Variant = entity.get(&"def")
	if def is Resource:
		var resource: Resource = def
		size = maxf(_float(resource, &"radius", 0.0) * 2.2, 1.6)
		var footprint: Variant = resource.get(&"footprint")
		if footprint is Rect2:
			var area: Rect2 = footprint
			size = maxf(area.size.x, area.size.y) * 0.7
	explosion(entity.global_position + Vector3.UP * 0.6, size)


## A brief bright disc, e.g. a muzzle flash.
func flash(at: Vector3, color: Color, size: float, seconds: float) -> void:
	if not _claim(seconds):
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var disc := MeshInstance3D.new()
	disc.mesh = quad
	disc.material_override = _additive
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	disc.global_position = at
	_tint(disc, Color(color.r * GLOW, color.g * GLOW, color.b * GLOW))
	var tween := create_tween()
	tween.tween_property(disc, ^"scale", Vector3.ONE * 0.2, seconds)
	tween.tween_callback(disc.queue_free)


## A burst of fast sparks.
func sparks(at: Vector3, color: Color, count: int) -> void:
	var process := _burst_process(4.0, 9.0, Vector3(0, -14.0, 0), 0.08, 0.16)
	process.color_ramp = _ramp(
		Color(color.r * GLOW, color.g * GLOW, color.b * GLOW), Color(color, 0)
	)
	_emit(at, process, _additive, count, 0.35, 0.5)


## Fireball, smoke, sparks and a scorch mark. `radius` in metres.
func explosion(at: Vector3, radius: float) -> void:
	flash(at, Color(1.0, 0.9, 0.7), radius * 3.2, 0.12)
	var fire := _burst_process(radius * 1.2, radius * 2.6, Vector3(0, 1.5, 0), 0.6, 1.1)
	fire.color_ramp = _ramp(
		Color(FIRE_COLOR.r * GLOW, FIRE_COLOR.g * GLOW, FIRE_COLOR.b * GLOW),
		Color(0.3, 0.05, 0.0, 0)
	)
	_emit(at, fire, _additive, 12, 0.55, radius * 1.3)
	var smoke := _burst_process(radius * 0.5, radius * 1.4, Vector3(0, 1.2, 0), 0.8, 1.4)
	smoke.color_ramp = _ramp(SMOKE_COLOR, Color(SMOKE_COLOR, 0))
	_emit(at, smoke, _blended, 9, 1.8, radius * 1.8)
	sparks(at, FIRE_COLOR, 14)
	_scorch_mark(at, radius * 2.4)


func _scorch_mark(at: Vector3, size: float) -> void:
	if not _claim(SCORCH_SECONDS):
		return
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * size
	var mark := MeshInstance3D.new()
	mark.mesh = quad
	mark.material_override = _scorch
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	mark.global_position = Vector3(at.x, at.y - 0.45, at.z)
	_tint(mark, Color(0.03, 0.02, 0.02, 0.75))
	var tween := create_tween()
	tween.tween_interval(SCORCH_SECONDS * 0.6)
	tween.tween_method(
		func(alpha: float) -> void: _tint(mark, Color(0.03, 0.02, 0.02, alpha)),
		0.75,
		0.0,
		SCORCH_SECONDS * 0.4
	)
	tween.tween_callback(mark.queue_free)


func _emit(
	at: Vector3,
	process: ParticleProcessMaterial,
	material: Material,
	count: int,
	seconds: float,
	size: float,
) -> void:
	if not _claim(seconds):
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = seconds
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.global_position = at
	particles.emitting = true
	get_tree().create_timer(seconds + 0.3).timeout.connect(particles.queue_free)


## Counts an effect against the budget; false when the budget is used up.
func _claim(seconds: float) -> bool:
	if _live >= MAX_EFFECTS:
		return false
	_live += 1
	get_tree().create_timer(seconds + 0.3).timeout.connect(func() -> void: _live -= 1)
	return true


func _trail(color: Color, seconds: float, size: float) -> GPUParticles3D:
	var process := _burst_process(0.0, 0.3, Vector3(0, 0.4, 0), 0.5, 1.0)
	process.color_ramp = _ramp(color, Color(color, 0))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = _blended
	var trail := GPUParticles3D.new()
	trail.amount = 10
	trail.lifetime = seconds
	trail.process_material = process
	trail.draw_pass_1 = quad
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return trail


func _solid(mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r * GLOW, color.g * GLOW, color.b * GLOW)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part


## A capsule lying along Z, the direction projectiles travel.
static func _capsule(radius: float, length: float) -> Mesh:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = length
	capsule.radial_segments = 6
	capsule.rings = 2
	var turned := ArrayMesh.new()
	var arrays: Array = capsule.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index: int in vertices.size():
		var vertex: Vector3 = vertices[index]
		vertices[index] = Vector3(vertex.x, vertex.z, vertex.y)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	turned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return turned


static func _sphere(radius: float) -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	return sphere


static func _burst_process(
	speed_min: float, speed_max: float, gravity: Vector3, scale_min: float, scale_max: float
) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = gravity
	process.damping_min = 1.0
	process.damping_max = 2.5
	process.scale_min = scale_min
	process.scale_max = scale_max
	return process


static func _ramp(from: Color, to: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, from)
	gradient.set_color(1, to)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _make_material(blend: BaseMaterial3D.BlendMode) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = blend
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _puff
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _make_puff_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


## Per-instance colour for meshes drawn with the shared billboard materials.
static func _tint(mesh: MeshInstance3D, color: Color) -> void:
	var quad: PrimitiveMesh = mesh.mesh as PrimitiveMesh
	if quad == null:
		return
	var material: StandardMaterial3D = (mesh.material_override as StandardMaterial3D).duplicate()
	material.vertex_color_use_as_albedo = false
	material.albedo_color = color
	mesh.material_override = material


static func _hidden(entity: Node3D) -> bool:
	if not is_instance_valid(entity):
		return false
	var visible_to_player: Variant = entity.get(&"is_visible_to_player")
	return visible_to_player is bool and not visible_to_player


static func _faction_color(entity: Node3D) -> Color:
	if is_instance_valid(entity):
		var faction: Variant = entity.get(&"faction")
		if faction is int and faction != 0:
			return COMBINE_COLOR
	return CONCORD_COLOR


static func _float(resource: Resource, property: StringName, fallback: float) -> float:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property)
	if value is float or value is int:
		var number: float = value
		return number
	return fallback


static func _string_name(
	resource: Resource, property: StringName, fallback: StringName
) -> StringName:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property)
	if value is StringName or value is String:
		var text: StringName = value
		return text
	return fallback
