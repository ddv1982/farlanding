class_name ResourceNode
extends Node3D
## A resource node on the map: an Alloy deposit (mined by Haulers, runs out) or a
## Flux vent (tapped by a Flux Tap built on it, never runs out). Neutral: it belongs
## to no faction. Spawned by SimWorld.

## Share of the deposit left changed, in [0, 1]. The visual shrinks with it.
signal remaining_changed(fraction: float)

const SAVE_VERSION: int = 1
const GROUP: StringName = &"resource_nodes"

var def: ResourceNodeDef
## Save id, unique within the mission; -1 until spawned.
var entity_id: int = -1
## Units of resource left (deposits).
var remaining: int = 0
## The Flux Tap standing on this vent, or null.
var tap: Building = null


func _enter_tree() -> void:
	add_to_group(GROUP)


func setup(p_def: ResourceNodeDef) -> void:
	def = p_def
	remaining = def.amount


func _ready() -> void:
	remaining_changed.emit(fraction_left())


func resource() -> StringName:
	return def.resource if def != null else &""


## True for an Alloy deposit that still holds something.
func is_minable() -> bool:
	return def != null and def.resource == &"alloy" and remaining > 0


func is_depleted() -> bool:
	return def != null and def.amount > 0 and remaining <= 0


## True for a vent without a Flux Tap on it.
func is_free_vent() -> bool:
	return def != null and def.resource == &"flux" and not is_instance_valid(tap)


## Share left in [0, 1] (always 1 for endless nodes).
func fraction_left() -> float:
	if def == null or def.amount <= 0:
		return 1.0
	return clampf(float(remaining) / def.amount, 0.0, 1.0)


## Takes up to `amount` from the deposit; returns what was taken.
func take(amount: int) -> int:
	var taken: int = mini(maxi(amount, 0), remaining)
	if taken <= 0:
		return 0
	remaining -= taken
	remaining_changed.emit(fraction_left())
	return taken


## Ground area kept clear of buildings and blocked for movement (world X/Z).
func blocked_area() -> Rect2:
	var half: float = def.radius * 0.8
	return Rect2(position.x - half, position.z - half, half * 2.0, half * 2.0)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"def": def.resource_path if def != null else "",
		"entity_id": entity_id,
		"position": var_to_str(position),
		"remaining": remaining,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported ResourceNode save version")
	entity_id = data.get("entity_id", entity_id)
	remaining = data.get("remaining", remaining)
	remaining_changed.emit(fraction_left())
