class_name Command
extends RefCounted
## One order to one or more entities. Every order — player, AI or mission script —
## is a Command pushed through the mission's CommandQueue.
##
## Subclasses override `execute()`. The base class does nothing when executed.

## What kind of order this is, e.g. &"move", &"stop", &"attack".
var kind: StringName = &""
## The faction that issued the order.
var issuer_faction: int = 0
## The entities that receive the order.
var entities: Array[Node3D] = []
## Ground target, if the order has one.
var target_position: Vector3 = Vector3.ZERO
## Entity target, if the order has one.
var target_entity: Node3D = null
## Queue after the entities' current orders instead of replacing them (shift-click).
var queued: bool = false


func _init(
	p_kind: StringName = &"",
	p_issuer_faction: int = 0,
	p_entities: Array[Node3D] = [],
) -> void:
	kind = p_kind
	issuer_faction = p_issuer_faction
	entities = p_entities.duplicate()


## Applies the order. Called by CommandQueue on the sim tick after it was pushed.
func execute() -> void:
	pass


## Drops entities that were freed or left the tree since the order was given.
## Returns true if any receiver is left.
func prune_entities() -> bool:
	var alive: Array[Node3D] = []
	for entity: Variant in entities:
		if _is_alive(entity):
			var node: Node3D = entity
			alive.append(node)
	entities = alive
	if not _is_alive(target_entity):
		target_entity = null
	return not entities.is_empty()


# Takes a Variant: a freed object cannot be passed through a typed parameter.
static func _is_alive(entity: Variant) -> bool:
	if not is_instance_valid(entity):
		return false
	var node: Node = entity
	return node.is_inside_tree()
