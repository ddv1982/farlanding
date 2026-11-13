class_name StormVfx
extends Node3D
## The look of a Kessel dust storm, driven by `Events.storm_changed`: the air
## thickens and turns the colour of the basin, the sun dims, grit streaks past
## the camera and a haze blows across the screen. Add one to a map's visuals and
## point it at the WorldEnvironment and the sun; it eases toward each new
## intensity so sparse updates still look continuous.

const HAZE_SHADER: Shader = preload("res://presentation/shaders/storm_haze.gdshader")
const DUST := Color(0.80, 0.56, 0.36)
## Fog density at full storm (the calm value is whatever the environment has).
const STORM_FOG_DENSITY := 0.008
## Share of sunlight left at full storm.
const STORM_SUN := 0.5
const STORM_AMBIENT := 0.7
## Seconds to ease most of the way to a new intensity.
const EASE_SECONDS := 1.5
const GRIT_COUNT := 700
## Size of the box of blowing grit kept around the camera's ground point.
const GRIT_BOX := Vector3(70.0, 9.0, 55.0)
const WIND := Vector3(1.0, 0.0, 0.25)

@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D

var _target: float = 0.0
var _shown: float = 0.0
var _environment: Environment
var _calm_fog_density: float = 0.0
var _calm_fog_color: Color = DUST
var _calm_sun: float = 1.0
var _calm_ambient: float = 1.0
var _grit: GPUParticles3D
var _haze: ShaderMaterial
var _haze_rect: ColorRect


func _ready() -> void:
	if world_environment != null and world_environment.environment != null:
		# A private copy: the storm must not write into the shared resource.
		_environment = world_environment.environment.duplicate() as Environment
		world_environment.environment = _environment
		_calm_fog_density = _environment.fog_density
		_calm_fog_color = _environment.fog_light_color
		_calm_ambient = _environment.ambient_light_energy
	if sun != null:
		_calm_sun = sun.light_energy
	_grit = _build_grit()
	add_child(_grit)
	_build_haze()
	Events.storm_changed.connect(set_intensity)
	Events.mission_started.connect(_on_mission_started)
	_apply(0.0)


func _process(delta: float) -> void:
	if not is_equal_approx(_shown, _target):
		_shown = lerpf(_shown, _target, 1.0 - exp(-delta * 3.0 / EASE_SECONDS))
		if absf(_shown - _target) < 0.002:
			_shown = _target
		_apply(_shown)
	if _shown <= 0.0:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		# Keep the grit where the camera is looking, not where it is hanging.
		var forward: Vector3 = -camera.global_transform.basis.z
		var reach: float = 0.0
		if forward.y < -0.05:
			reach = camera.global_position.y / -forward.y
		var focus: Vector3 = camera.global_position + forward * minf(reach, 120.0)
		_grit.global_position = Vector3(focus.x, focus.y + GRIT_BOX.y * 0.5, focus.z)


## 0 = clear, 1 = full storm.
func set_intensity(intensity: float) -> void:
	_target = clampf(intensity, 0.0, 1.0)


func _on_mission_started() -> void:
	_target = 0.0
	_shown = 0.0
	_apply(0.0)


func _apply(amount: float) -> void:
	if _environment != null:
		_environment.fog_density = lerpf(_calm_fog_density, STORM_FOG_DENSITY, amount * amount)
		_environment.fog_light_color = _calm_fog_color.lerp(DUST, amount)
		_environment.ambient_light_energy = lerpf(
			_calm_ambient, _calm_ambient * STORM_AMBIENT, amount
		)
	if sun != null:
		sun.light_energy = lerpf(_calm_sun, _calm_sun * STORM_SUN, amount)
	_grit.emitting = amount > 0.02
	_grit.amount_ratio = clampf(amount, 0.05, 1.0)
	_haze.set_shader_parameter(&"intensity", amount)
	_haze_rect.visible = amount > 0.0


func _build_grit() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = GRIT_BOX * 0.5
	process.direction = WIND.normalized()
	process.spread = 6.0
	process.initial_velocity_min = 22.0
	process.initial_velocity_max = 38.0
	process.gravity = Vector3(0.0, -0.6, 0.0)
	var surface := StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.albedo_color = Color(0.93, 0.74, 0.55, 0.32)
	# Long thin quads turned along their velocity and toward the camera read as streaks.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 1.1)
	quad.material = surface
	var grit := GPUParticles3D.new()
	grit.name = "Grit"
	grit.amount = GRIT_COUNT
	grit.lifetime = 1.6
	grit.process_material = process
	grit.draw_pass_1 = quad
	grit.local_coords = false
	grit.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	grit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grit.visibility_aabb = AABB(-GRIT_BOX, GRIT_BOX * 2.0)
	grit.emitting = false
	return grit


func _build_haze() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	_haze = ShaderMaterial.new()
	_haze.shader = HAZE_SHADER
	_haze.set_shader_parameter(&"noise", texture)
	_haze_rect = ColorRect.new()
	_haze_rect.material = _haze
	_haze_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Under the HUD, over the world.
	var layer := CanvasLayer.new()
	layer.name = "StormHaze"
	layer.layer = -1
	layer.add_child(_haze_rect)
	add_child(layer)
