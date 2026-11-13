extends Node3D
## Showcase only: sight cones at three levels of suspicion, objective markers and
## a cloaked unit, so their look can be checked without playing a mission.

@export var unit_scene: PackedScene


func _ready() -> void:
	var levels: Array[float] = [0.0, 0.5, 1.0]
	for index: int in levels.size():
		var guard := Node3D.new()
		add_child(guard)
		guard.position = Vector3(-16.0 + index * 14.0, 0.4, 4.0)
		guard.rotation.y = deg_to_rad(20.0 - index * 20.0)
		var cone := SightConeVisual.new()
		guard.add_child(cone)
		cone.set_cone(11.0, 70.0)
		cone.set_suspicion(levels[index])
		cone.set_alerted(index == 2)
	var primary := ObjectiveMarker.new()
	add_child(primary)
	primary.position = Vector3(-10, 0.4, -14)
	var secondary := ObjectiveMarker.new()
	secondary.kind = &"secondary"
	secondary.radius = 4.0
	add_child(secondary)
	secondary.position = Vector3(8, 0.4, -14)
	if unit_scene != null:
		for index: int in 2:
			var unit: Node3D = unit_scene.instantiate()
			add_child(unit)
			unit.position = Vector3(16.0 + index * 4.0, 0.4, 8.0)
			unit.scale = Vector3.ONE * 1.6
			for mesh: Node in unit.find_children("*", "MeshInstance3D", true, false):
				var instance: MeshInstance3D = mesh
				instance.set_instance_shader_parameter(&"cloak", float(index))
