class_name SabotageCommand
extends Command
## Send saboteurs (Wisps) to sabotage an enemy building (`target_entity`). Receivers
## that cannot sabotage ignore it, as does a building that no longer works. The
## issuing faction must see the building now, as for an attack.

const KIND: StringName = Saboteur.KIND


func _init(
	p_issuer_faction: int = 0,
	p_entities: Array[Node3D] = [],
	p_building: Node3D = null,
	p_queued: bool = false,
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	target_entity = p_building
	queued = p_queued
	if p_building != null:
		target_position = p_building.position


func execute() -> void:
	var building: Building = target_entity as Building
	if not Saboteur.can_sabotage(building, issuer_faction):
		return
	if building.world != null and building.world.vision != null:
		if not building.world.vision.can_see(issuer_faction, building):
			return
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if unit == null or unit.faction != issuer_faction or unit.orders == null:
			continue
		if not unit.orders.can_do(KIND):
			continue
		if not queued and unit.saboteur != null and unit.saboteur.target == building:
			continue
		var order: Order = Order.new(KIND, building.position)
		order.target_entity = building
		unit.orders.give(order, queued)
