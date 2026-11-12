class_name ProduceCommand
extends Command
## Queue one unit of `unit_def` at a producer building (the single receiver). The
## cost is paid when queued; a full queue or a cost that cannot be paid queues
## nothing (the Advisor says so for the player).

const KIND: StringName = &"produce"

var unit_def: UnitDef
## Why the last execute queued nothing (Producer reasons, or &"insufficient_resources").
var failure: StringName = &""


func _init(p_issuer_faction: int = 0, p_building: Node3D = null, p_def: UnitDef = null) -> void:
	var receivers: Array[Node3D] = []
	if p_building != null:
		receivers.append(p_building)
	super(KIND, p_issuer_faction, receivers)
	unit_def = p_def


func execute() -> void:
	var building: Building = entities[0] as Building
	if building == null or building.faction != issuer_faction or building.world == null:
		return
	if not building.is_operational() or building.producer == null:
		failure = Producer.NOT_PRODUCIBLE
		return
	failure = building.producer.check(unit_def)
	if failure != Producer.OK:
		return
	if not building.world.economy.pay(issuer_faction, unit_def):
		failure = &"insufficient_resources"
		return
	if building.producer.push(unit_def):
		Events.production_started.emit(building, unit_def)
