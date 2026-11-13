class_name ScanCommand
extends Command
## Send scanners (Surveyors) to scan a discovery site (`target_entity`). Receivers
## that cannot scan ignore it; so does a site that is resolved or not yet charted.

const KIND: StringName = Scanner.KIND


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
		target_position = p_site.position


func execute() -> void:
	var site: DiscoverySite = target_entity as DiscoverySite
	if site == null or not site.can_be_scanned():
		return
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if unit == null or unit.faction != issuer_faction or unit.orders == null:
			continue
		if not unit.orders.can_do(KIND):
			continue
		# Clicking the site again must not throw the progress away.
		if not queued and unit.scanner != null and unit.scanner.site == site:
			continue
		var order: Order = Order.new(KIND, site.position)
		order.target_entity = site
		unit.orders.give(order, queued)
