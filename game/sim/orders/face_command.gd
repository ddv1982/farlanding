class_name FaceCommand
extends Command
## Turns standing receivers to look toward `target_position` (a guard looking around
## at a patrol stop). Units that are moving or busy with an order ignore it.

const KIND: StringName = &"face"


func _init(
	p_issuer_faction: int = 0, p_entities: Array[Node3D] = [], p_point: Vector3 = Vector3.ZERO
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	target_position = p_point


func execute() -> void:
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if unit == null or unit.faction != issuer_faction or unit.locomotion == null:
			continue
		if unit.orders != null and not unit.orders.is_idle():
			continue
		unit.locomotion.face(target_position)
