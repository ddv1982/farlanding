class_name HealthBar
extends MeshInstance3D
## Camera-facing health bar. Shown while its owner is damaged or selected.
## Use HealthBar.create(width, height_above_ground).

const SHADER: Shader = preload("res://presentation/shaders/health_bar.gdshader")
const THICKNESS := 0.22

var _fraction: float = 1.0
var _selected: bool = false


static func create(width: float, above: float) -> HealthBar:
	var bar := HealthBar.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, THICKNESS)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 10
	bar.name = "HealthBar"
	bar.mesh = quad
	bar.material_override = material
	bar.position.y = above
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.visible = false
	return bar


## 1 = full health, 0 = dead.
func set_fraction(fraction: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	set_instance_shader_parameter(&"health", _fraction)
	_refresh()


func set_selected(selected: bool) -> void:
	_selected = selected
	_refresh()


func _refresh() -> void:
	visible = _selected or _fraction < 1.0
