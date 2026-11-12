class_name RallyCommand
extends Command
## Set where producer buildings (the receivers) send the units they finish.

const KIND: StringName = &"rally"


func _init(
	p_issuer_faction: int = 0, p_entities: Array[Node3D] = [], p_point: Vector3 = Vector3.ZERO
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	target_position = p_point


func execute() -> void:
	for entity: Node3D in entities:
		var building: Building = entity as Building
		if building != null and building.faction == issuer_faction and building.producer != null:
			building.producer.set_rally_point(target_position)
