class_name Order
extends RefCounted
## One order held by a unit: what to do and where. Commands turn into Orders when they
## execute; a unit works through its Orders one after another.

const SAVE_VERSION: int = 2

## Same vocabulary as Command.kind, e.g. &"move" or &"attack".
var kind: StringName = &""
var target_position: Vector3 = Vector3.ZERO
## Entity the order is about (the unit to attack, the deposit to mine, the site to
## build), or null. Saved by its `entity_id`; a restored order keeps the id in
## `target_id` until the world resolves it.
var target_entity: Node3D = null
## Save id of `target_entity` after a restore, or -1.
var target_id: int = -1
## Attack orders: where to stand relative to the target; its length is the
## engagement distance.
var engage_offset: Vector3 = Vector3.ZERO
## Attack orders a unit gave itself (auto-engage, return fire): it may walk at most
## `leash` metres beyond its reach from `guard`, where it stood, and walks back
## there afterwards. 0 for orders given by a command.
var leash: float = 0.0
var guard: Vector3 = Vector3.ZERO
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
		"target_id": entity_id_of(target_entity),
		"leash": leash,
		"guard": var_to_str(guard),
	}


static func from_dict(data: Dictionary) -> Order:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported Order save version")
	var kind_name: StringName = data.get("kind", &"")
	var target_text: String = data.get("target", "Vector3(0, 0, 0)")
	var target: Vector3 = str_to_var(target_text)
	var order: Order = Order.new(kind_name, target)
	var offset_text: String = data.get("offset", "Vector3(0, 0, 0)")
	order.engage_offset = str_to_var(offset_text)
	order.target_id = data.get("target_id", -1)
	order.leash = data.get("leash", 0.0)
	var guard_text: String = data.get("guard", "Vector3(0, 0, 0)")
	order.guard = str_to_var(guard_text)
	return order


## The save id of an entity (its `entity_id` property), or -1.
static func entity_id_of(entity: Variant) -> int:
	if not is_instance_valid(entity):
		return -1
	var node: Node = entity
	var value: Variant = node.get(&"entity_id")
	if value is int:
		var id: int = value
		return id
	return -1
