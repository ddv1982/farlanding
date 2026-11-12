class_name SelectionRules
extends RefCounted
## Pure selection rules: who may be selected, how clicks and boxes change a
## selection, and what a mouse click means. Only living units of the player's faction
## are selectable; units of other factions are enemies, and only enemies the player
## can see now may be targeted (a click on one out of sight means the ground).

## What a click does.
const CLICK_NONE: StringName = &"none"
const CLICK_SELECT: StringName = &"select"
const CLICK_ATTACK: StringName = &"attack"
const CLICK_MOVE: StringName = &"move"
## Right click on one of these with units selected.
const CLICK_HARVEST: StringName = &"harvest"
const CLICK_ASSIST: StringName = &"assist"


static func is_selectable(unit: Variant, player_faction: int) -> bool:
	if not is_instance_valid(unit) or not unit is Unit:
		return false
	var node: Unit = unit
	return node.is_inside_tree() and node.faction == player_faction


## True for a living unit of another faction that the player can see now.
static func is_enemy(unit: Variant, player_faction: int) -> bool:
	if not is_instance_valid(unit) or not unit is Unit:
		return false
	var node: Unit = unit
	return (
		node.is_inside_tree()
		and node.faction != player_faction
		and node.is_visible_to_player
		and not node.is_dead
	)


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


## What a right click on `target` (a building or resource node; null = ground) asks
## of the selected units: harvest a deposit (if any can harvest), help build an own
## site (if any can build), attack an enemy building, or move there.
static func right_click_target(
	current: Array[Unit], target: Node3D, player_faction: int
) -> StringName:
	var units: Array[Unit] = selectable(current, player_faction)
	if units.is_empty():
		return CLICK_NONE
	var node: ResourceNode = target as ResourceNode
	if node != null and node.is_minable() and _any_can(units, Harvester.KIND):
		return CLICK_HARVEST
	var building: Building = target as Building
	if building != null and is_instance_valid(building) and building.is_inside_tree():
		if building.faction != player_faction:
			return CLICK_ATTACK if building.is_visible_to_player else CLICK_MOVE
		if building.is_under_construction and _any_can(units, Builder.KIND):
			return CLICK_ASSIST
	return CLICK_MOVE


## The units in `units` that can carry out orders of `kind`.
static func able(units: Array[Unit], kind: StringName) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in units:
		if unit.orders != null and unit.orders.can_do(kind):
			result.append(unit)
	return result


static func _any_can(units: Array[Unit], kind: StringName) -> bool:
	return not able(units, kind).is_empty()
