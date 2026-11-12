class_name Order
extends RefCounted
## One order held by a unit: what to do and where. Commands turn into Orders when they
## execute; a unit works through its Orders one after another.

const SAVE_VERSION: int = 1

## Same vocabulary as Command.kind, e.g. &"move" or &"attack".
var kind: StringName = &""
var target_position: Vector3 = Vector3.ZERO
## Entity the order is about (the unit to attack), or null. Not saved yet: entities
## have no save ids, so a restored attack order has no target and ends at once.
var target_entity: Node3D = null
## Attack orders: where to stand relative to the target; its length is the
## engagement distance.
var engage_offset: Vector3 = Vector3.ZERO
## Optional path computed with the group when the order was given; used once when
## the order starts, then dropped. Not saved: a restored order asks for a new path.
var path: PackedVector3Array = PackedVector3Array()


func _init(p_kind: StringName = &"", p_target_position: Vector3 = Vector3.ZERO) -> void:
	kind = p_kind
	target_position = p_target_position


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"kind": kind,
		"target": var_to_str(target_position),
		"offset": var_to_str(engage_offset),
	}


static func from_dict(data: Dictionary) -> Order:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Order save version")
	var kind_name: StringName = data.get("kind", &"")
	var target_text: String = data.get("target", "Vector3(0, 0, 0)")
	var target: Vector3 = str_to_var(target_text)
	var order: Order = Order.new(kind_name, target)
	var offset_text: String = data.get("offset", "Vector3(0, 0, 0)")
	order.engage_offset = str_to_var(offset_text)
	return order
