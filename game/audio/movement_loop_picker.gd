class_name MovementLoopPicker
extends RefCounted
## Pure choice of which moving units get an audible movement loop: the nearest
## to the listener focus, within range, at most `max_count` in total and at most
## `caps[event]` per loop type (identical loops stacked sound phasey, not bigger).


## Returns candidate indices, nearest first.
static func pick(
	positions: PackedVector3Array,
	events: Array[StringName],
	caps: Dictionary[StringName, int],
	focus: Vector3,
	max_count: int,
	max_distance: float,
) -> PackedInt32Array:
	var order: Array[int] = []
	var distances: PackedFloat32Array = []
	distances.resize(positions.size())
	for i: int in positions.size():
		distances[i] = _ground_distance(positions[i], focus)
		if max_distance <= 0.0 or distances[i] <= max_distance:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return distances[a] < distances[b])
	var used: Dictionary[StringName, int] = {}
	var chosen: PackedInt32Array = []
	for i: int in order:
		if chosen.size() >= max_count:
			break
		var event: StringName = events[i]
		var count: int = used.get(event, 0)
		var cap: int = caps.get(event, max_count)
		if count >= cap:
			continue
		used[event] = count + 1
		chosen.append(i)
	return chosen


static func _ground_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
