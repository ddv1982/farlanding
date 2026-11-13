class_name CarryCommand
extends Command
## Pick up a carriable prop (`target_entity`, an artefact; ADR 0014). The receiver
## nearest the prop that can carry is sent to lift it; the other receivers walk
## along to it as an escort. Nothing happens when nobody can lift it (somebody
## carries it already).

const KIND: StringName = Carrier.KIND

## The unit sent to lift the prop, or null.
var carrier: Unit = null


func _init(
	p_issuer_faction: int = 0,
	p_entities: Array[Node3D] = [],
	p_prop: Node3D = null,
	p_queued: bool = false,
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	target_entity = p_prop
	queued = p_queued
	if p_prop != null:
		target_position = p_prop.position


func execute() -> void:
	var prop: Prop = target_entity as Prop
	if prop == null or not prop.is_carriable() or prop.is_carried():
		return
	var escort: Array[Node3D] = []
	var best_distance: float = INF
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if unit == null or unit.faction != issuer_faction or unit.orders == null:
			continue
		escort.append(unit)
		if unit.carrier == null or not unit.carrier.can_lift(prop):
			continue
		var at: Vector3 = unit.sim_position()
		var distance: float = Vector2(at.x - prop.position.x, at.z - prop.position.z).length()
		if distance < best_distance:
			carrier = unit
			best_distance = distance
	if carrier == null:
		return
	escort.erase(carrier)
	var order: Order = Order.new(KIND, prop.position)
	order.target_entity = prop
	carrier.orders.give(order, queued)
	if not escort.is_empty():
		var walk: MoveCommand = MoveCommand.new(
			MoveCommand.KIND_MOVE, issuer_faction, escort, prop.position, queued
		)
		walk.execute()
