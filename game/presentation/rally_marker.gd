class_name RallyMarker
extends Node3D
## A small flag showing where a building sends the units it produces.
## Use RallyMarker.create(color); show it only while its building is selected.

const POLE_HEIGHT := 2.6


static func create(color: Color) -> RallyMarker:
	var marker := RallyMarker.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color.lightened(0.2)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.06
	pole.height = POLE_HEIGHT
	marker.add_child(_part(pole, material, Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)))
	var flag := PrismMesh.new()
	flag.size = Vector3(0.9, 1.1, 0.04)
	var cloth := _part(flag, material, Vector3(0.55, POLE_HEIGHT - 0.45, 0.0))
	cloth.rotation.z = -PI * 0.5
	marker.add_child(cloth)
	var base := CylinderMesh.new()
	base.top_radius = 0.5
	base.bottom_radius = 0.5
	base.height = 0.06
	marker.add_child(_part(base, material, Vector3(0.0, 0.06, 0.0)))
	return marker


static func _part(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part
