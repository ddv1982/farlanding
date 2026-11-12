class_name FogOfWar
extends Node
## Uploads the player's vision grid as the global fog texture every world shader
## reads (see presentation/shaders/fog.gdshaderinc): `fog_map` red = visible now,
## green = explored, plus `fog_origin_x`, `fog_origin_z` and `fog_size`.
##
## The grid's two layers go to the GPU as small L8 textures whenever the player's
## vision updates. A SubViewport renders them into `fog_map` at OVERSAMPLE pixels per
## cell with a soft blur, blending each frame toward the new state over a few frames
## (it reads its own previous frame), so edges are smooth and changes ease in.
## It also answers the audio side's fog query (group GROUP).

## Audio finds the fog through this group (CombatSoundRouter.FOG_GROUP).
const GROUP: StringName = &"fog_of_war"
## Output pixels per vision cell.
const OVERSAMPLE: int = 4
## How quickly the shown fog follows the grid (per second).
const EASE_RATE: float = 9.0

const BLEND_SHADER: String = """
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D visible_cells : filter_linear, repeat_disable;
uniform sampler2D explored_cells : filter_linear, repeat_disable;
uniform sampler2D previous : hint_screen_texture, filter_nearest;
uniform vec2 cell_texel = vec2(0.01);
uniform float blend = 1.0;

vec2 sample_cells(vec2 uv) {
	return vec2(texture(visible_cells, uv).r, texture(explored_cells, uv).r);
}

void fragment() {
	vec2 sum = vec2(0.0);
	float weight = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			float w = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
			sum += sample_cells(UV + vec2(float(x), float(y)) * cell_texel * 0.75) * w;
			weight += w;
		}
	}
	vec2 target = sum / weight;
	target.y = max(target.y, target.x);
	vec2 shown = mix(texture(previous, SCREEN_UV).rg, target, blend);
	COLOR = vec4(shown, 0.0, 1.0);
}
"""

var _grid: VisionGrid = null
var _faction: int = 0
var _visible_texture: ImageTexture = null
var _explored_texture: ImageTexture = null
var _viewport: SubViewport = null
var _material: ShaderMaterial = null
var _first_frame: bool = true


## Starts showing `faction`'s view of `vision`.
func setup(vision: VisionSystem, faction: int) -> void:
	_grid = vision.grid
	_faction = faction
	_visible_texture = ImageTexture.create_from_image(_grid.visible_image(faction))
	_explored_texture = ImageTexture.create_from_image(_grid.explored_image(faction))
	_viewport = SubViewport.new()
	_viewport.name = &"FogViewport"
	_viewport.size = Vector2i(_grid.columns, _grid.rows) * OVERSAMPLE
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	add_child(_viewport)
	var shader: Shader = Shader.new()
	shader.code = BLEND_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter(&"visible_cells", _visible_texture)
	_material.set_shader_parameter(&"explored_cells", _explored_texture)
	_material.set_shader_parameter(&"cell_texel", Vector2(1.0 / _grid.columns, 1.0 / _grid.rows))
	var canvas: ColorRect = ColorRect.new()
	canvas.material = _material
	canvas.size = Vector2(_viewport.size)
	_viewport.add_child(canvas)
	vision.updated.connect(_on_vision_updated)
	var side: float = maxf(_grid.columns, _grid.rows) * _grid.cell_size
	RenderingServer.global_shader_parameter_set(&"fog_map", _viewport.get_texture())
	RenderingServer.global_shader_parameter_set(&"fog_origin_x", _grid.area.position.x)
	RenderingServer.global_shader_parameter_set(&"fog_origin_z", _grid.area.position.y)
	RenderingServer.global_shader_parameter_set(&"fog_size", side)


func _enter_tree() -> void:
	add_to_group(GROUP)


## True if the player sees `position` now (audio: is a ground impact heard).
func is_point_visible_to_player(position: Vector3) -> bool:
	return _grid == null or _grid.is_visible(_faction, position)


func _process(delta: float) -> void:
	if _material == null:
		return
	# The first frame takes the grid as it is; later ones ease toward it.
	_material.set_shader_parameter(&"blend", 1.0 if _first_frame else 1.0 - exp(-EASE_RATE * delta))
	_first_frame = false


func _exit_tree() -> void:
	# Menus and showcases render without fog.
	RenderingServer.global_shader_parameter_set(&"fog_size", 0.0)


func _on_vision_updated(faction: int) -> void:
	if faction != _faction:
		return
	_visible_texture.update(_grid.visible_image(faction))
	_explored_texture.update(_grid.explored_image(faction))
