class_name CancelProductionCommand
extends Command
## Remove the last queued unit of `unit_def` (any type when null) from a producer
## (the single receiver) and refund `rules.cancel_refund` of its cost.

const KIND: StringName = &"cancel_production"

var unit_def: UnitDef
## The type removed when the command ran, or null.
var cancelled: UnitDef = null


func _init(p_issuer_faction: int = 0, p_building: Node3D = null, p_def: UnitDef = null) -> void:
	var receivers: Array[Node3D] = []
	if p_building != null:
		receivers.append(p_building)
	super(KIND, p_issuer_faction, receivers)
	unit_def = p_def


func execute() -> void:
	var building: Building = entities[0] as Building
	if building == null or building.faction != issuer_faction or building.producer == null:
		return
	cancelled = building.producer.cancel_last(unit_def)
	if cancelled != null and building.world != null:
		var share: float = building.world.rules.cancel_refund
		building.world.economy.refund(issuer_faction, cancelled, share)
