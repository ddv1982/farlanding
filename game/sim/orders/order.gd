class_name Order
extends RefCounted
## One order held by a unit: what to do and where. Commands turn into Orders when they
## execute; a unit works through its Orders one after another.

const SAVE_VERSION: int = 1

## Same vocabulary as Command.kind, e.g. &"move" or &"attack_move".
var kind: StringName = &""
var target_position: Vector3 = Vector3.ZERO
## Optional path computed with the group when the order was given; used once when
## the order starts, then dropped. Not saved: a restored order asks for a new path.
var path: PackedVector3Array = PackedVector3Array()


func _init(p_kind: StringName = &"", p_target_position: Vector3 = Vector3.ZERO) -> void:
	kind = p_kind
	target_position = p_target_position


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "kind": kind, "target": var_to_str(target_position)}


static func from_dict(data: Dictionary) -> Order:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Order save version")
	var kind_name: StringName = data.get("kind", &"")
	var target_text: String = data.get("target", "Vector3(0, 0, 0)")
	var target: Vector3 = str_to_var(target_text)
	return Order.new(kind_name, target)
