class_name SellBuildingCommand
extends Command
## Selling uses the normal removal cleanup, without damage or a Health.died signal.
## SimWorld unregisters immediately before notifications and a same-tick save.

const KIND: StringName = &"sell_building"

## True only when this execution sold the receiver.
var sold: bool = false


func _init(p_issuer_faction: int = 0, p_building: Node3D = null) -> void:
	var receivers: Array[Node3D] = []
	if p_building != null:
		receivers.append(p_building)
	super(KIND, p_issuer_faction, receivers)


func execute() -> void:
	sold = false
	if entities.is_empty():
		return
	var building: Building = entities[0] as Building
	if not can_sell(building, issuer_faction):
		return
	sold = building.world.sell_building(building, issuer_faction)


static func can_sell(building: Building, issuer: int) -> bool:
	return (
		is_instance_valid(building)
		and building.is_inside_tree()
		and not building.is_queued_for_deletion()
		and not building.is_dead
		and building.faction == issuer
		and building.world != null
		and building.world.buildings.has(building)
		and building.def != null
		and building.def.placeable
		and building.def.id != &"lander"
		and not building.def.machine
		and building.machine == null
	)


## Total refund, including queued units under the existing cancellation policy.
static func refund_for(building: Building) -> Vector2i:
	var rules: EconomyRules = building.world.rules
	var share: float = (
		rules.construction_cancel_refund if building.is_under_construction else rules.sell_refund
	)
	var result := Vector2i(
		floori(building.def.cost_alloy * share), floori(building.def.cost_flux * share)
	)
	if building.producer != null:
		for unit: UnitDef in building.producer.queue:
			result += Vector2i(
				floori(unit.cost_alloy * rules.cancel_refund),
				floori(unit.cost_flux * rules.cancel_refund)
			)
	return result
