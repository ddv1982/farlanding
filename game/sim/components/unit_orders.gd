class_name UnitOrders
extends Node
## Holds a unit's current order and its queue of follow-up orders (shift-queued
## waypoints) and drives Locomotion through them. Move and attack-move both travel for
## now; attack-move keeps its own kind so combat can hook in later.

## The unit started working on `order`.
signal order_started(order: Order)

const SAVE_VERSION: int = 1

## The order being carried out, or null when idle.
var current: Order = null
## Orders waiting after `current`, oldest first.
var queue: Array[Order] = []

var _locomotion: Locomotion = null


func setup(locomotion: Locomotion) -> void:
	_locomotion = locomotion


## Replaces all orders with `order`, or appends it when `queued`.
func give(order: Order, queued: bool = false) -> void:
	if queued and current != null:
		queue.append(order)
		return
	queue.clear()
	_start(order)


## Drops every order and brakes to a halt.
func stop() -> void:
	queue.clear()
	current = null
	if _locomotion != null:
		_locomotion.stop()


func is_idle() -> bool:
	return current == null


## Where the unit will be once every order is done; `fallback` when idle.
func last_destination(fallback: Vector3) -> Vector3:
	if not queue.is_empty():
		return queue[queue.size() - 1].target_position
	if current != null:
		return current.target_position
	return fallback


## Advances to the next order once the current one is done.
func tick() -> void:
	if current == null or _locomotion == null or _locomotion.is_travelling():
		return
	current = null
	if not queue.is_empty():
		var next: Order = queue.pop_front()
		_start(next)


func to_dict() -> Dictionary:
	var queued: Array[Dictionary] = []
	for order: Order in queue:
		queued.append(order.to_dict())
	return {
		"version": SAVE_VERSION,
		"current": current.to_dict() if current != null else {},
		"queue": queued,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported UnitOrders save version")
	var current_data: Dictionary = data.get("current", {})
	current = Order.from_dict(current_data) if not current_data.is_empty() else null
	queue.clear()
	var queued: Array = data.get("queue", [])
	for entry: Variant in queued:
		var order_data: Dictionary = entry
		queue.append(Order.from_dict(order_data))


func _start(order: Order) -> void:
	current = order
	order_started.emit(order)
	if _locomotion == null:
		return
	var started: bool = false
	if not order.path.is_empty():
		started = _locomotion.follow_path(order.path)
		order.path = PackedVector3Array()
	else:
		started = _locomotion.move_to(order.target_position)
	if not started:
		current = null
