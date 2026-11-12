class_name Unit
extends Node3D
## A mobile unit: a thin root holding its definition and faction, composed of
## component nodes (Locomotion, UnitOrders, and OrderHandlers such as Harvester or
## Builder) plus a presentation child. Spawned by SimWorld, which sets `def`,
## `faction`, `world` and `entity_id` before adding it to the tree.

const SAVE_VERSION: int = 2
const GROUP: StringName = &"units"

## Read by audio, UI and selection (`def.sound_set`, `def.display_name`).
var def: UnitDef
var faction: int = 0
## The world this unit lives in (null in some tests).
var world: SimWorld = null
## Save id, unique within the mission; -1 until spawned.
var entity_id: int = -1
var locomotion: Locomotion = null
var orders: UnitOrders = null
var harvester: Harvester = null
var builder: Builder = null
## Current ground speed in m/s. Read by audio for movement loops.
var speed: float:
	get:
		return locomotion.mover.speed if locomotion != null else 0.0
## True while mining at a deposit. Read by audio for the mining loop.
var is_harvesting: bool:
	get:
		return harvester != null and harvester.is_mining()

var _handlers: Array[OrderHandler] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	for child: Node in get_children():
		if child is Locomotion:
			locomotion = child
		elif child is UnitOrders:
			orders = child
		elif child is OrderHandler:
			_handlers.append(child)
			if child is Harvester:
				harvester = child
			elif child is Builder:
				builder = child
	if orders != null:
		orders.setup(locomotion)
		for handler: OrderHandler in _handlers:
			handler.setup(self)
			orders.add_handler(handler)


## One sim tick: orders first (they may start a new path), then movement.
func sim_tick(dt: float) -> void:
	if orders != null:
		orders.tick(dt)
	if locomotion != null:
		locomotion.tick(dt)


## Simulation position (leads the drawn node by up to one tick).
func sim_position() -> Vector3:
	return locomotion.mover.position if locomotion != null else global_position


func to_dict() -> Dictionary:
	var handlers: Dictionary = {}
	for handler: OrderHandler in _handlers:
		handlers[String(handler.name)] = handler.to_dict()
	return {
		"version": SAVE_VERSION,
		"def": def.resource_path if def != null else "",
		"faction": faction,
		"entity_id": entity_id,
		"locomotion": locomotion.to_dict() if locomotion != null else {},
		"orders": orders.to_dict() if orders != null else {},
		"handlers": handlers,
	}


## Restores component state; `def` and `faction` are set by the spawner.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported Unit save version")
	faction = data.get("faction", faction)
	entity_id = data.get("entity_id", entity_id)
	var locomotion_data: Dictionary = data.get("locomotion", {})
	if locomotion != null and not locomotion_data.is_empty():
		locomotion.from_dict(locomotion_data)
	var orders_data: Dictionary = data.get("orders", {})
	if orders != null and not orders_data.is_empty():
		orders.from_dict(orders_data)
	var handlers: Dictionary = data.get("handlers", {})
	for handler: OrderHandler in _handlers:
		var handler_data: Dictionary = handlers.get(String(handler.name), {})
		if not handler_data.is_empty():
			handler.from_dict(handler_data)
