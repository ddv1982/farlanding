class_name HarvestCommand
extends Command
## Send harvesters to mine a deposit (`target_entity`). They keep mining and
## delivering until it runs out, then move on to the next one nearby. Receivers that
## cannot harvest ignore it.

const KIND: StringName = Harvester.KIND


func _init(
	p_issuer_faction: int = 0,
	p_entities: Array[Node3D] = [],
	p_deposit: Node3D = null,
	p_queued: bool = false,
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	target_entity = p_deposit
	queued = p_queued
	if p_deposit != null:
		target_position = p_deposit.position


func execute() -> void:
	var deposit: ResourceNode = target_entity as ResourceNode
	if deposit == null or not deposit.is_minable():
		return
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if unit == null or unit.faction != issuer_faction or unit.orders == null:
			continue
		if not unit.orders.can_do(KIND):
			continue
		var order: Order = Order.new(KIND, deposit.position)
		order.target_entity = deposit
		unit.orders.give(order, queued)
