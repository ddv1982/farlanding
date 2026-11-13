class_name ReactivateCommand
extends Command
## Send units that can build or scan to reactivate an Antecedent engine
## (`target_entity`), or to take over one running for another faction (Hollow
## Meridian, ADR 0017). Receivers that cannot do it ignore it, as does an engine that
## already runs for the issuer. The issuing faction must have explored the engine's
## ground (engines are landmarks; who runs one is seen once there).

const KIND: StringName = Reactivator.KIND


func _init(
	p_issuer_faction: int = 0,
	p_entities: Array[Node3D] = [],
	p_engine: Node3D = null,
	p_queued: bool = false,
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	target_entity = p_engine
	queued = p_queued
	if p_engine != null:
		target_position = p_engine.position


func execute() -> void:
	var engine: Building = target_entity as Building
	if not Reactivator.can_reactivate(engine, issuer_faction):
		return
	if engine.world.vision != null:
		if not engine.world.vision.grid.is_explored(issuer_faction, engine.position):
			return
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if unit == null or unit.faction != issuer_faction or unit.orders == null:
			continue
		if not unit.orders.can_do(KIND):
			continue
		if not queued and unit.reactivator != null and unit.reactivator.target == engine:
			continue
		var order: Order = Order.new(KIND, engine.position)
		order.target_entity = engine
		unit.orders.give(order, queued)
