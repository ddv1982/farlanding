class_name ControlGroups
extends RefCounted
## Numbered control groups (1..9). Ctrl/Cmd or Alt/Option + N stores the selection,
## Shift + N adds it, N recalls it (SelectionController reads the keys; the HUD's
## GroupBar shows the groups).

## Any group's members changed (stored, added to, or restored from a save).
signal changed
## The player stored a selection in group `index` or added one to it.
signal stored(index: int)

const COUNT: int = 9

var _groups: Dictionary[int, Array] = {}


func assign(index: int, units: Array[Unit]) -> void:
	assert(index >= 1 and index <= COUNT, "Control group out of range: %d" % index)
	_groups[index] = units.duplicate()
	changed.emit()
	stored.emit(index)


## Adds `units` to group `index` after its living members (each unit once).
func add(index: int, units: Array[Unit]) -> void:
	assert(index >= 1 and index <= COUNT, "Control group out of range: %d" % index)
	var merged: Array[Unit] = _living(index)
	for unit: Unit in units:
		if not merged.has(unit):
			merged.append(unit)
	_groups[index] = merged
	changed.emit()
	stored.emit(index)


## Living members of group `index`, in the order they were stored.
func recall(index: int) -> Array[Unit]:
	var result: Array[Unit] = _living(index)
	_groups[index] = result.duplicate()
	return result


## How many living units group `index` holds now.
func count(index: int) -> int:
	return _living(index).size()


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
	changed.emit()


## Members of group `index` that still exist, are in the world and are not dying.
func _living(index: int) -> Array[Unit]:
	var result: Array[Unit] = []
	var stored_units: Array = _groups.get(index, [])
	for entry: Variant in stored_units:
		if is_instance_valid(entry):
			var unit: Unit = entry
			if unit.is_inside_tree() and not unit.is_dead:
				result.append(unit)
	return result
