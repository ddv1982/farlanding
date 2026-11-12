class_name SelectionRules
extends RefCounted
## Pure selection rules: who may be selected, how clicks and boxes change a
## selection, and what a mouse click means. Only living units of the player's faction
## are selectable; units of other factions are enemies.

## What a click does.
const CLICK_NONE: StringName = &"none"
const CLICK_SELECT: StringName = &"select"
const CLICK_ATTACK: StringName = &"attack"
const CLICK_MOVE: StringName = &"move"


static func is_selectable(unit: Variant, player_faction: int) -> bool:
	if not is_instance_valid(unit) or not unit is Unit:
		return false
	var node: Unit = unit
	return node.is_inside_tree() and node.faction == player_faction


## True for a living unit of another faction.
static func is_enemy(unit: Variant, player_faction: int) -> bool:
	if not is_instance_valid(unit) or not unit is Unit:
		return false
	var node: Unit = unit
	return node.is_inside_tree() and node.faction != player_faction


## Left click on `clicked` (null = ground): an enemy is attacked when units are
## selected and ignored otherwise; anything else selects (see `click()`).
static func left_click(current: Array[Unit], clicked: Unit, player_faction: int) -> StringName:
	if is_enemy(clicked, player_faction):
		return CLICK_NONE if selectable(current, player_faction).is_empty() else CLICK_ATTACK
	return CLICK_SELECT


## Right click on `clicked` (null = ground): nothing without a selection, attack on an
## enemy, otherwise move to the ground point.
static func right_click(current: Array[Unit], clicked: Unit, player_faction: int) -> StringName:
	if selectable(current, player_faction).is_empty():
		return CLICK_NONE
	return CLICK_ATTACK if is_enemy(clicked, player_faction) else CLICK_MOVE


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
