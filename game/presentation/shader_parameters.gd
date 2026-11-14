class_name ShaderParameters
extends RefCounted

const LOCAL_MATERIALS: StringName = &"fl_local_shader_materials"


static func set_value(mesh: MeshInstance3D, key: StringName, value: Variant) -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		mesh.set_instance_shader_parameter(key, value)
		return
	# WebGL's uniform buffer cannot hold the instance data of an RTS army.
	if not mesh.has_meta(LOCAL_MATERIALS):
		if mesh.material_override is ShaderMaterial:
			mesh.material_override = mesh.material_override.duplicate() as ShaderMaterial
		elif mesh.mesh != null:
			for index: int in mesh.mesh.get_surface_count():
				var material: ShaderMaterial = mesh.get_active_material(index) as ShaderMaterial
				if material != null:
					mesh.set_surface_override_material(
						index, material.duplicate() as ShaderMaterial
					)
		mesh.set_meta(LOCAL_MATERIALS, true)
	var override: ShaderMaterial = mesh.material_override as ShaderMaterial
	if override != null:
		override.set_shader_parameter(key, value)
	elif mesh.mesh != null:
		for index: int in mesh.mesh.get_surface_count():
			var material: ShaderMaterial = (
				mesh.get_surface_override_material(index) as ShaderMaterial
			)
			if material != null:
				material.set_shader_parameter(key, value)
