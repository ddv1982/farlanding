class_name EruptionVfx
extends Node3D
## Emberfall's lava and its eruptions. Lays the lava sheet under the terrain's
## river beds, and draws what `Events.eruption_warning` and `Events.eruption`
## announce: a ring on the ground that tightens and brightens while a vent builds
## up, then a fountain of fire, a flash of light and a scorch mark. The simulation
## never calls this.

const LAVA_SHADER: Shader = preload("res://presentation/shaders/lava.gdshader")
const WARNING_COLOR := Color(1.0, 0.45, 0.08)
const FIRE_COLOR := Color(1.0, 0.55, 0.12)
const SCORCH_COLOR := Color(0.03, 0.02, 0.02)
const DECAL_HEIGHT: float = 14.0
const RING_PIXELS: int = 256
const FOUNTAIN_SECONDS: float = 2.4
const SCORCH_SECONDS: float = 40.0
## The sheet is a little larger than the map so its edge is never seen.
const MARGIN: float = 30.0

## Height of the lava's surface, in metres (the terrain recipe's number).
@export var lava_level: float = -0.9
## The map's side, in metres.
@export var map_size: float = 240.0

var _ring: Texture2D
var _disc: Texture2D
var _spark: Texture2D
## Warning rings by vent instance id, so an eruption removes its own.
var _warnings: Dictionary[int, Decal] = {}


func _ready() -> void:
	_ring = _make_texture(0.9, 0.06, 0.0)
	_disc = _make_texture(2.0, 0.01, 1.0)
	_spark = _make_texture(0.0, 0.9, 0.0)
	add_child(_build_sheet())
	Events.eruption_warning.connect(_on_warning)
	Events.eruption.connect(_on_eruption)
	Events.mission_started.connect(_clear)


## A ring `radius` wide on the ground at `at` that pulses faster and brighter
## over `seconds`. Returns the decal (freed by the eruption or after `seconds`).
func warn(at: Vector3, radius: float, seconds: float) -> Decal:
	var decal: Decal = _decal(_ring, at, WARNING_COLOR, radius)
	decal.emission_energy = 0.0
	var tween: Tween = decal.create_tween()
	var beats: int = maxi(int(seconds / 0.9), 1)
	for i: int in beats:
		var strength: float = lerpf(1.2, 4.0, float(i + 1) / beats)
		var half: float = seconds / beats * 0.5
		tween.tween_property(decal, ^"emission_energy", strength, half)
		tween.tween_property(decal, ^"emission_energy", strength * 0.35, half)
	tween.tween_callback(decal.queue_free)
	return decal


## The burst: fountain, light and scorch at `at` over `radius` metres.
func erupt(at: Vector3, radius: float) -> void:
	var fountain: GPUParticles3D = _fountain(radius)
	add_child(fountain)
	fountain.global_position = at + Vector3.UP * 0.4
	fountain.emitting = true
	get_tree().create_timer(FOUNTAIN_SECONDS + 2.0).timeout.connect(fountain.queue_free)

	var light := OmniLight3D.new()
	light.light_color = FIRE_COLOR
	light.omni_range = radius * 2.2
	light.light_energy = 9.0
	add_child(light)
	light.global_position = at + Vector3.UP * 3.0
	var fade: Tween = light.create_tween()
	fade.tween_property(light, ^"light_energy", 0.0, FOUNTAIN_SECONDS)
	fade.tween_callback(light.queue_free)

	var blast: Decal = _decal(_disc, at, FIRE_COLOR, radius)
	blast.emission_energy = 3.0
	var cool: Tween = blast.create_tween()
	cool.tween_property(blast, ^"emission_energy", 0.0, FOUNTAIN_SECONDS * 1.5)
	cool.tween_callback(blast.queue_free)

	var scorch: Decal = _decal(_disc, at, SCORCH_COLOR, radius * 0.9)
	scorch.albedo_mix = 0.85
	scorch.texture_emission = null
	var heal: Tween = scorch.create_tween()
	heal.tween_interval(SCORCH_SECONDS * 0.6)
	heal.tween_property(scorch, ^"albedo_mix", 0.0, SCORCH_SECONDS * 0.4)
	heal.tween_callback(scorch.queue_free)


func _on_warning(vent: Node3D, seconds: float, radius: float) -> void:
	if not is_instance_valid(vent):
		return
	_drop_warning(vent.get_instance_id())
	_warnings[vent.get_instance_id()] = warn(vent.global_position, radius, seconds)


func _on_eruption(vent: Node3D, radius: float) -> void:
	if not is_instance_valid(vent):
		return
	_drop_warning(vent.get_instance_id())
	erupt(vent.global_position, radius)


func _drop_warning(id: int) -> void:
	var decal: Decal = _warnings.get(id, null)
	_warnings.erase(id)
	if is_instance_valid(decal):
		decal.queue_free()


func _clear() -> void:
	for id: int in _warnings.keys():
		_drop_warning(id)


func _build_sheet() -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	var material := ShaderMaterial.new()
	material.shader = LAVA_SHADER
	material.set_shader_parameter(&"noise_tex", texture)
	var plane := PlaneMesh.new()
	plane.size = Vector2(map_size + MARGIN, map_size + MARGIN)
	var sheet := MeshInstance3D.new()
	sheet.mesh = plane
	sheet.material_override = material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.position.y = lava_level
	sheet.name = &"Lava"
	return sheet


func _fountain(radius: float) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 28.0
	process.initial_velocity_min = radius * 1.1
	process.initial_velocity_max = radius * 2.0
	process.gravity = Vector3(0.0, -14.0, 0.0)
	process.scale_min = 0.4
	process.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray(
		[Color(1.0, 0.9, 0.5), Color(1.0, 0.4, 0.06), Color(0.2, 0.03, 0.0, 0.0)]
	)
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = _spark
	material.albedo_color = Color(3.0, 2.2, 1.4)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.5)
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.amount = 260
	particles.lifetime = FOUNTAIN_SECONDS
	particles.one_shot = true
	particles.explosiveness = 0.75
	particles.emitting = false
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 60, 80))
	# Named last: naming a GPUParticles3D before its material leaks a shader in
	# headless runs (ADR 0011).
	particles.name = &"Fountain"
	return particles


func _decal(texture: Texture2D, at: Vector3, color: Color, radius: float) -> Decal:
	var decal := Decal.new()
	decal.texture_albedo = texture
	decal.texture_emission = texture
	decal.modulate = color
	decal.albedo_mix = 0.0
	decal.upper_fade = 0.01
	decal.lower_fade = 0.01
	decal.size = Vector3(radius * 2.0, DECAL_HEIGHT, radius * 2.0)
	add_child(decal)
	decal.global_position = at
	return decal


## White on transparent: a rim at `rim` of the radius, `width` wide, over a fill
## of `fill` alpha fading toward the edge.
static func _make_texture(rim: float, width: float, fill: float) -> Texture2D:
	var image: Image = Image.create(RING_PIXELS, RING_PIXELS, false, Image.FORMAT_RGBA8)
	var half: float = RING_PIXELS * 0.5
	for y: int in RING_PIXELS:
		for x: int in RING_PIXELS:
			var r: float = Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			var edge: float = 1.0 - smoothstep(0.0, width, absf(r - rim))
			var inside: float = fill * (1.0 - smoothstep(0.0, 1.0, r))
			var alpha: float = clampf(edge + inside, 0.0, 1.0) * (1.0 if r < 1.0 else 0.0)
			image.set_pixel(x, y, Color(alpha, alpha, alpha, alpha))
	return ImageTexture.create_from_image(image)
