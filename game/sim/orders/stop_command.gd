class_name StopCommand
extends Command
## Halts the receivers and clears their queued orders.

const KIND: StringName = &"stop"


func _init(p_issuer_faction: int = 0, p_entities: Array[Node3D] = []) -> void:
	super(KIND, p_issuer_faction, p_entities)


func execute() -> void:
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if unit != null and unit.orders != null and unit.faction == issuer_faction:
			unit.orders.stop()
