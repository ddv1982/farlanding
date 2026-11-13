@tool
extends EditorScenePostImport
## Runs on every imported model (see importer_defaults in project.godot).
## Swaps the placeholder materials that Blender exports (matched by name) for
## the game's shared ShaderMaterials, so models never carry their own.

const MATERIALS: Dictionary[String, String] = {
	"fl_palette": "res://assets/materials/fl_palette.tres",
	"fl_terrain": "res://assets/materials/fl_terrain_kessel.tres",
	"fl_terrain_thalassa": "res://assets/materials/fl_terrain_thalassa.tres",
}


func _post_import(scene: Node) -> Object:
	_apply(scene)
	return scene


func _apply(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface in mesh_instance.mesh.get_surface_count():
			var current := mesh_instance.mesh.surface_get_material(surface)
			if current != null and MATERIALS.has(current.resource_name):
				var material: Material = load(MATERIALS[current.resource_name])
				mesh_instance.mesh.surface_set_material(surface, material)
	for child in node.get_children():
		_apply(child)
