extends GutTest


func test_planet_models_use_their_runtime_materials() -> void:
	var expected: Dictionary[String, String] = {
		"kessel_proving_ground": "fl_terrain_kessel",
		"thalassa_tidewater_ground": "fl_terrain_thalassa",
		"emberfall_caldera_ground": "fl_terrain_emberfall",
		"verdance_basin_ground": "fl_terrain_verdance",
		"hollow_meridian_ground": "fl_terrain_hollow",
	}
	for model: String in expected:
		var path: String = "res://assets/models/terrain/%s.glb" % model
		var scene: Node = (load(path) as PackedScene).instantiate()
		var matched: bool = false
		for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			for index: int in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(index)
				if material.resource_path == "res://assets/materials/%s.tres" % expected[model]:
					matched = true
		assert_true(matched, "%s has its mapped planet material" % model)
		scene.free()
