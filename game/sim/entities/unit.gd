class_name Unit
extends Node3D
## A mobile unit: a thin root holding its definition and faction, composed of
## component nodes (Locomotion, UnitOrders) plus a presentation child. Spawned by
## SimWorld, which sets `def` and `faction` before adding it to the tree.

const SAVE_VERSION: int = 1
const GROUP: StringName = &"units"

## Read by audio, UI and selection (`def.sound_set`, `def.display_name`).
var def: UnitDef
var faction: int = 0
var locomotion: Locomotion = null
var orders: UnitOrders = null
## Current ground speed in m/s. Read by audio for movement loops.
var speed: float:
	get:
		return locomotion.mover.speed if locomotion != null else 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	for child: Node in get_children():
		if child is Locomotion:
			locomotion = child
		elif child is UnitOrders:
			orders = child
	if orders != null:
		orders.setup(locomotion)


## One sim tick: orders first (they may start a new path), then movement.
func sim_tick(dt: float) -> void:
	if orders != null:
		orders.tick()
	if locomotion != null:
		locomotion.tick(dt)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"def": def.resource_path if def != null else "",
		"faction": faction,
		"locomotion": locomotion.to_dict() if locomotion != null else {},
		"orders": orders.to_dict() if orders != null else {},
	}


## Restores component state; `def` and `faction` are set by the spawner.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Unit save version")
	faction = data.get("faction", faction)
	var locomotion_data: Dictionary = data.get("locomotion", {})
	if locomotion != null and not locomotion_data.is_empty():
		locomotion.from_dict(locomotion_data)
	var orders_data: Dictionary = data.get("orders", {})
	if orders != null and not orders_data.is_empty():
		orders.from_dict(orders_data)
