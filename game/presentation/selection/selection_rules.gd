class_name SelectionRules
extends RefCounted
## Pure selection rules: who may be selected and how clicks and boxes change a
## selection. Only living units of the player's faction are selectable.


static func is_selectable(unit: Variant, player_faction: int) -> bool:
	if not is_instance_valid(unit) or not unit is Unit:
		return false
	var node: Unit = unit
	return node.is_inside_tree() and node.faction == player_faction


## The selectable subset of `units`, order kept, duplicates removed.
static func selectable(units: Array[Unit], player_faction: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Variant in units:
		if is_selectable(unit, player_faction):
			var node: Unit = unit
			if not result.has(node):
				result.append(node)
	return result


## Selection after clicking `clicked` (null = empty ground). Shift (`additive`) toggles
## the clicked unit; a plain click selects only it. Clicking ground clears the
## selection unless additive.
static func click(
	current: Array[Unit], clicked: Unit, additive: bool, player_faction: int
) -> Array[Unit]:
	var kept: Array[Unit] = selectable(current, player_faction)
	if not is_selectable(clicked, player_faction):
		return kept if additive else ([] as Array[Unit])
	if not additive:
		return [clicked] as Array[Unit]
	if kept.has(clicked):
		kept.erase(clicked)
	else:
		kept.append(clicked)
	return kept


## Selection after a drag box over `boxed`. Shift adds to the selection; a plain box
## replaces it (an empty box clears it).
static func box(
	current: Array[Unit], boxed: Array[Unit], additive: bool, player_faction: int
) -> Array[Unit]:
	var picked: Array[Unit] = selectable(boxed, player_faction)
	if not additive:
		return picked
	var result: Array[Unit] = selectable(current, player_faction)
	for unit: Unit in picked:
		if not result.has(unit):
			result.append(unit)
	return result


## Units in `candidates` of the same type as `like` (double-click).
static func same_type(candidates: Array[Unit], like: Unit, player_faction: int) -> Array[Unit]:
	if not is_selectable(like, player_faction):
		return []
	var result: Array[Unit] = []
	for unit: Unit in selectable(candidates, player_faction):
		if unit.def == like.def:
			result.append(unit)
	return result
