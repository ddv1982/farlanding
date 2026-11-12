class_name Producer
extends Node
## A building's production queue. Units are built one at a time in queue order; the
## caller pays when queueing and refunds when cancelling (see ProduceCommand), so this
## class only keeps the queue, the work done and the rally point.

const SAVE_VERSION: int = 1
## Why a unit could not be queued.
const OK: StringName = &""
const QUEUE_FULL: StringName = &"queue_full"
const NOT_PRODUCIBLE: StringName = &"not_producible"

## Unit types this producer may make.
var options: Array[UnitDef] = []
## Most units in the queue, including the one in progress.
var limit: int = 5
## Waiting units, the first is in progress.
var queue: Array[UnitDef] = []
## Seconds of work done on the first unit.
var elapsed: float = 0.0
## Where finished units go, once set.
var rally_point: Vector3 = Vector3.ZERO
var has_rally_point: bool = false


func setup(p_options: Array[UnitDef], p_limit: int) -> void:
	options = p_options
	limit = p_limit


## Why `def` cannot be queued now (ignoring cost), or OK.
func check(def: UnitDef) -> StringName:
	if def == null or not options.has(def):
		return NOT_PRODUCIBLE
	if queue.size() >= limit:
		return QUEUE_FULL
	return OK


## Appends `def` (already paid for). Returns true if it is the only unit, i.e. its
## production starts now.
func push(def: UnitDef) -> bool:
	queue.append(def)
	return queue.size() == 1


## Removes the last queued unit of type `def` (any type when null). Returns the
## removed type, or null if there was none. Cancelling the unit in progress
## discards its work.
func cancel_last(def: UnitDef = null) -> UnitDef:
	for i: int in range(queue.size() - 1, -1, -1):
		if def == null or queue[i] == def:
			var removed: UnitDef = queue[i]
			queue.remove_at(i)
			if i == 0:
				elapsed = 0.0
			return removed
	return null


func is_busy() -> bool:
	return not queue.is_empty()


## The unit in progress, or null.
func current() -> UnitDef:
	return queue[0] if not queue.is_empty() else null


## Units of type `def` in the queue.
func count_of(def: UnitDef) -> int:
	return queue.count(def)


## Progress of the unit in progress, in [0, 1].
func progress() -> float:
	if queue.is_empty():
		return 0.0
	return clampf(elapsed / queue[0].build_time, 0.0, 1.0)


## Advances work by `dt` seconds already scaled by the power rate. Returns the type
## that finished this tick (removed from the queue), or null.
func tick(dt: float) -> UnitDef:
	if queue.is_empty():
		return null
	elapsed += dt
	if elapsed < queue[0].build_time:
		return null
	elapsed = 0.0
	return queue.pop_front()


func set_rally_point(point: Vector3) -> void:
	rally_point = point
	has_rally_point = true


func to_dict() -> Dictionary:
	var queued: Array[String] = []
	for def: UnitDef in queue:
		queued.append(def.resource_path)
	return {
		"version": SAVE_VERSION,
		"queue": queued,
		"elapsed": elapsed,
		"rally_point": var_to_str(rally_point),
		"has_rally_point": has_rally_point,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Producer save version")
	queue.clear()
	var queued: Array = data.get("queue", [])
	for entry: Variant in queued:
		var path: String = entry
		if path == "" or not ResourceLoader.exists(path):
			continue
		var def: UnitDef = load(path) as UnitDef
		if def != null:
			queue.append(def)
	elapsed = data.get("elapsed", 0.0)
	var rally_text: String = data.get("rally_point", "Vector3(0, 0, 0)")
	rally_point = str_to_var(rally_text)
	has_rally_point = data.get("has_rally_point", false)
