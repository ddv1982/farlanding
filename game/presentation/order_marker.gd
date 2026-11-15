class_name OrderMarker
extends MeshInstance3D
## One-shot ground pulse shown where an order was issued; frees itself.
## Use OrderMarker.spawn(parent, position, color). An attack order's marker is
## larger (ATTACK_SCALE) and drawn as a cross in a broken ring, so it differs from a
## move's by more than its colour.

const SHADER: Shader = preload("res://presentation/shaders/order_marker.gdshader")
const DURATION := 0.55
const SIZE := 3.0
const ATTACK_SCALE := 1.6

var _age: float = 0.0


static func spawn(
	parent: Node, at: Vector3, color: Color, marker_scale: float = 1.0
) -> OrderMarker:
	var marker := OrderMarker.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * SIZE * marker_scale
	var material := ShaderMaterial.new()
	material.shader = SHADER
	marker.mesh = quad
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(marker)
	marker.global_position = at + Vector3.UP * 0.1
	ShaderParameters.set_value(marker, &"marker_color", color)
	ShaderParameters.set_value(marker, &"attack", marker_scale > 1.0)
	return marker


func _process(delta: float) -> void:
	_age += delta
	ShaderParameters.set_value(self, &"progress", clampf(_age / DURATION, 0.0, 1.0))
	if _age >= DURATION:
		queue_free()
