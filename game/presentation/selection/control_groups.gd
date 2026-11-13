class_name ControlGroups
extends RefCounted
## Numbered control groups (1..9). Ctrl+N stores the selection, N recalls it.

const COUNT: int = 9

var _groups: Dictionary[int, Array] = {}


func assign(index: int, units: Array[Unit]) -> void:
	assert(index >= 1 and index <= COUNT, "Control group out of range: %d" % index)
	_groups[index] = units.duplicate()


## Living members of group `index`, in the order they were stored.
func recall(index: int) -> Array[Unit]:
	var result: Array[Unit] = []
	var stored: Array = _groups.get(index, [])
	for entry: Variant in stored:
		if is_instance_valid(entry):
			var unit: Unit = entry
			if unit.is_inside_tree():
				result.append(unit)
	_groups[index] = result.duplicate()
	return result


## Stored groups by unit save id (a saved game keeps the player's groups).
func to_dict() -> Dictionary:
	var saved: Dictionary = {}
	for index: int in _groups:
		var ids: Array[int] = []
		for entry: Variant in _groups[index]:
			var id: int = Order.entity_id_of(entry)
			if id >= 0:
				ids.append(id)
		if not ids.is_empty():
			saved[str(index)] = ids
	return saved


## Restores groups saved by `to_dict()`; `lookup` is `func(id: int) -> Node3D`.
func from_dict(data: Dictionary, lookup: Callable) -> void:
	_groups.clear()
	for key: Variant in data:
		var index: int = int(str(key))
		if index < 1 or index > COUNT:
			continue
		var units: Array[Unit] = []
		var ids: Array = data[key]
		for entry: Variant in ids:
			var id: int = entry
			var unit_node: Node3D = lookup.call(id)
			var unit: Unit = unit_node as Unit
			if unit != null:
				units.append(unit)
		_groups[index] = units
