class_name BuildCommand
extends Command
## Send builders to work on a construction site (`target_entity`), e.g. to help
## another builder. Receivers that cannot build ignore it.

const KIND: StringName = Builder.KIND


func _init(
	p_issuer_faction: int = 0,
	p_entities: Array[Node3D] = [],
	p_site: Node3D = null,
	p_queued: bool = false,
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	target_entity = p_site
	queued = p_queued
	if p_site != null:
		target_position = p_site.global_position if p_site.is_inside_tree() else p_site.position


func execute() -> void:
	var site: Building = target_entity as Building
	if site == null or not site.is_under_construction or site.faction != issuer_faction:
		return
	give_build_orders(entities, issuer_faction, site, queued)


## Gives every receiver of `faction` that can build a build order on `site`.
static func give_build_orders(
	receivers: Array[Node3D], faction: int, site: Building, p_queued: bool
) -> void:
	for entity: Node3D in receivers:
		var unit: Unit = entity as Unit
		if unit == null or unit.faction != faction or unit.orders == null:
			continue
		if not unit.orders.can_do(KIND):
			continue
		var order: Order = Order.new(KIND, site.position)
		order.target_entity = site
		unit.orders.give(order, p_queued)
