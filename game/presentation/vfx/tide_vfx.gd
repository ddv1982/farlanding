class_name TideVfx
extends Node3D
## The sea on a tidal map, driven by `Events.tide_changed` (0 = low water, 1 = high
## water): a sheet of water that rises and falls between `low_water` and
## `high_water`, and a wet line on the terrain that follows it. Add one to a map's
## visuals and point it at the terrain; it eases toward each new level so sparse
## updates still look continuous. The simulation never calls this.

const WATER_SHADER: Shader = preload("res://presentation/shaders/tide_water.gdshader")
## Seconds to ease most of the way to a new level.
const EASE_SECONDS: float = 2.0
## The sheet is a little larger than the map so its edge is never seen.
const MARGIN: float = 30.0
## Sand stays dark this far above the water while the tide falls.
const WET_MARGIN: float = 0.25

## Sea level at low and at high water, in metres (the terrain recipe's numbers).
@export var low_water: float = -1.3
@export var high_water: float = 0.15
## The map's side, in metres.
@export var map_size: float = 240.0
## The terrain whose material carries `wet_level` (searched for its meshes).
@export var terrain: Node3D

var _target: float = 0.0
var _shown: float = 0.0
var _sheet: MeshInstance3D
var _terrain_materials: Array[ShaderMaterial] = []
## The highest the water has been lately: sand dries slowly behind a falling tide.
var _wet: float = 0.0


func _ready() -> void:
	_sheet = _build_sheet()
	add_child(_sheet)
	if terrain != null:
		_collect_materials(terrain)
	Events.tide_changed.connect(set_level)
	Events.mission_started.connect(_on_mission_started)
	_apply()


func _process(delta: float) -> void:
	if not is_equal_approx(_shown, _target):
		_shown = lerpf(_shown, _target, 1.0 - exp(-delta * 3.0 / EASE_SECONDS))
		if absf(_shown - _target) < 0.001:
			_shown = _target
	# The wet line follows a rising sea at once and a falling one slowly.
	_wet = maxf(_shown, _wet - delta * 0.01)
	_apply()


## Sets the level the sea moves toward: 0 = low water, 1 = high water.
func set_level(level: float) -> void:
	_target = clampf(level, 0.0, 1.0)


## The sea's height now, in metres.
func water_height() -> float:
	return lerpf(low_water, high_water, _shown)


func _on_mission_started() -> void:
	_target = 0.0
	_shown = 0.0
	_wet = 0.0
	_apply()


func _apply() -> void:
	_sheet.position.y = water_height()
	var wet_height: float = lerpf(low_water, high_water, _wet) + WET_MARGIN
	for material: ShaderMaterial in _terrain_materials:
		material.set_shader_parameter(&"wet_level", wet_height)


func _build_sheet() -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter(&"noise_tex", texture)
	var plane := PlaneMesh.new()
	plane.size = Vector2(map_size + MARGIN, map_size + MARGIN)
	var sheet := MeshInstance3D.new()
	sheet.mesh = plane
	sheet.material_override = material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.name = &"Sea"
	return sheet


## The terrain's own copies of its shader materials, so the wet line of one map
## never writes into the shared resource.
func _collect_materials(node: Node) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: ShaderMaterial = (
				mesh_instance.get_active_material(surface) as ShaderMaterial
			)
			if material != null and material.shader != null:
				if material.shader.resource_path.ends_with("terrain.gdshader"):
					var own: ShaderMaterial = material.duplicate() as ShaderMaterial
					mesh_instance.set_surface_override_material(surface, own)
					_terrain_materials.append(own)
	for child: Node in node.get_children():
		_collect_materials(child)
