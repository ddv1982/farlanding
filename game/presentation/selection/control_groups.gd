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
