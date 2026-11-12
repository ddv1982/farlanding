class_name OrderMarker
extends MeshInstance3D
## One-shot ground pulse shown where an order was issued; frees itself.
## Use OrderMarker.spawn(parent, position, color).

const SHADER: Shader = preload("res://presentation/shaders/order_marker.gdshader")
const DURATION := 0.55
const SIZE := 3.0

var _age: float = 0.0


static func spawn(parent: Node, at: Vector3, color: Color) -> OrderMarker:
	var marker := OrderMarker.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * SIZE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	marker.mesh = quad
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(marker)
	marker.global_position = at + Vector3.UP * 0.1
	marker.set_instance_shader_parameter(&"marker_color", color)
	return marker


func _process(delta: float) -> void:
	_age += delta
	set_instance_shader_parameter(&"progress", clampf(_age / DURATION, 0.0, 1.0))
	if _age >= DURATION:
		queue_free()
