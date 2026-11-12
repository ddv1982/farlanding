class_name PlacementGhost
extends Node3D
## Translucent preview of a building while the player chooses where to put it.
## Use PlacementGhost.create(model_scene), move it with the cursor, call
## set_valid(), and free it when placement ends.

const SHADER: Shader = preload("res://presentation/shaders/ghost.gdshader")
const VALID_COLOR := Color(0.25, 0.95, 1.0)
const INVALID_COLOR := Color(1.0, 0.2, 0.12)

var _meshes: Array[MeshInstance3D] = []


static func create(model_scene: PackedScene) -> PlacementGhost:
	var ghost := PlacementGhost.new()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var model := model_scene.instantiate() as Node3D
	ghost.add_child(model)
	ghost._apply(model, material)
	ghost.set_valid(true)
	return ghost


func set_valid(valid: bool) -> void:
	var color := VALID_COLOR if valid else INVALID_COLOR
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"ghost_color", color)


func _apply(node: Node, material: ShaderMaterial) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_meshes.append(mesh)
	for child in node.get_children():
		_apply(child, material)
