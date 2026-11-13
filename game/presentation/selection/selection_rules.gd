class_name SelectionRules
extends RefCounted
## Pure selection rules: who may be selected, how clicks and boxes change a
## selection, and what a mouse click means. Only living units of the player's faction
## are selectable; units of other factions are enemies, and only enemies the player
## can see now may be targeted (a click on one out of sight means the ground).
##
## What a click means is decided in two steps, the same for both control schemes:
## `command_target()` says what a command on a target asks of the selected units
## (attack, harvest, scan, help build, move), and `resolve()` says which button
## gives a command and when a click selects or deselects instead:
##
## - classic (Settings.SCHEME_CLASSIC, the default, as in Command & Conquer): left
##   click commands by context, but on an own unit or finished building it selects;
##   with a producer building selected it sets the rally point; right click deselects.
## - modern: left click selects (and attacks a visible enemy), right click commands
##   (with a producer building selected: the rally point).

## What a click does.
const CLICK_NONE: StringName = &"none"
const CLICK_SELECT: StringName = &"select"
const CLICK_ATTACK: StringName = &"attack"
const CLICK_MOVE: StringName = &"move"
## A command on one of these with units selected.
const CLICK_HARVEST: StringName = &"harvest"
const CLICK_ASSIST: StringName = &"assist"
const CLICK_SCAN: StringName = &"scan"
## Sabotage an enemy building (Wisps, which carry no weapon).
const CLICK_SABOTAGE: StringName = &"sabotage"
## Pick up a carriable prop (an artefact) nobody carries.
const CLICK_CARRY: StringName = &"carry"
## Sets the selected producer building's rally point.
const CLICK_RALLY: StringName = &"rally"
## Clears the selection (classic right click).
const CLICK_DESELECT: StringName = &"deselect"


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
## of the selected units (see `command_target()`).
static func right_click_target(
	current: Array[Unit], target: Node3D, player_faction: int
) -> StringName:
	return command_target(current, target, player_faction)


## What a command on `target` asks of the selected units: attack a visible enemy unit
## or building (sabotage a working enemy building when every selected unit able to
## act on it is a saboteur, i.e. a squad of Wisps), harvest a deposit (if any can
## harvest), scan an unresolved site (if any can scan), help build an own site (if
## any can build), pick up an artefact nobody carries (if any can carry), or move
## there. Null = the ground. Nothing without a selection.
## The one place these rules live.
static func command_target(current: Array[Unit], target: Node3D, player_faction: int) -> StringName:
	var units: Array[Unit] = selectable(current, player_faction)
	if units.is_empty():
		return CLICK_NONE
	if target is Unit:
		var clicked: Unit = target
		return CLICK_ATTACK if is_enemy(clicked, player_faction) else CLICK_MOVE
	var site: DiscoverySite = target as DiscoverySite
	if site != null and site.can_be_scanned() and _any_can(units, Scanner.KIND):
		return CLICK_SCAN
	var node: ResourceNode = target as ResourceNode
	if node != null and node.is_minable() and _any_can(units, Harvester.KIND):
		return CLICK_HARVEST
	var prop: Prop = target as Prop
	if prop != null and prop.is_carriable() and not prop.is_carried():
		if _any_can(units, Carrier.KIND):
			return CLICK_CARRY
	var building: Building = target as Building
	if building != null and is_instance_valid(building) and building.is_inside_tree():
		if building.faction != player_faction:
			if not building.is_visible_to_player:
				return CLICK_MOVE
			if _prefers_sabotage(units, building, player_faction):
				return CLICK_SABOTAGE
			return CLICK_ATTACK
		if building.is_under_construction and _any_can(units, Builder.KIND):
			return CLICK_ASSIST
	return CLICK_MOVE


## What a click of `button` (MOUSE_BUTTON_LEFT or _RIGHT) on `target` means under
## `scheme`, given the selected units (`current`) or selected building. `target` is
## the unit, building, site or resource node under the cursor, or null for ground.
static func resolve(
	scheme: StringName,
	button: MouseButton,
	current: Array[Unit],
	building: Building,
	target: Node3D,
	player_faction: int,
) -> StringName:
	var has_units: bool = not selectable(current, player_faction).is_empty()
	var rally: bool = (
		not has_units
		and building != null
		and is_instance_valid(building)
		and building.producer != null
		and building.is_operational()
	)
	if scheme == Settings.SCHEME_MODERN:
		if button == MOUSE_BUTTON_RIGHT:
			if rally:
				return CLICK_RALLY
			return command_target(current, target, player_faction)
		if _is_visible_enemy(target, player_faction):
			return CLICK_ATTACK if has_units else CLICK_NONE
		return CLICK_SELECT
	if button == MOUSE_BUTTON_RIGHT:
		return CLICK_DESELECT
	if has_units:
		var action: StringName = command_target(current, target, player_faction)
		if action != CLICK_MOVE:
			return action
	if _is_own(target, player_faction):
		return CLICK_SELECT
	if has_units:
		return CLICK_MOVE
	if rally:
		return CLICK_RALLY
	return CLICK_SELECT


## The button that gives commands under `scheme`.
static func command_button(scheme: StringName) -> MouseButton:
	return MOUSE_BUTTON_RIGHT if scheme == Settings.SCHEME_MODERN else MOUSE_BUTTON_LEFT


## The units in `units` that can carry out orders of `kind`.
static func able(units: Array[Unit], kind: StringName) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in units:
		if unit.orders != null and unit.orders.can_do(kind):
			result.append(unit)
	return result


## True for a living enemy unit, or an enemy building, that the player sees now.
static func _is_visible_enemy(target: Node3D, player_faction: int) -> bool:
	if target is Unit:
		return is_enemy(target, player_faction)
	var building: Building = target as Building
	return (
		building != null
		and is_instance_valid(building)
		and building.faction != player_faction
		and building.is_visible_to_player
		and not building.is_dead
	)


## True for an own unit or building (a click on it selects in the classic scheme).
static func _is_own(target: Node3D, player_faction: int) -> bool:
	if target is Unit:
		return is_selectable(target, player_faction)
	var building: Building = target as Building
	return building != null and is_instance_valid(building) and building.faction == player_faction


## True when the selection should sabotage `building` rather than attack it: some
## selected units can sabotage it and none of the others carries a weapon.
static func _prefers_sabotage(units: Array[Unit], building: Building, player_faction: int) -> bool:
	if not Saboteur.can_sabotage(building, player_faction):
		return false
	if not _any_can(units, Saboteur.KIND):
		return false
	for unit: Unit in units:
		if unit.weapon != null:
			return false
	return true


static func _any_can(units: Array[Unit], kind: StringName) -> bool:
	return not able(units, kind).is_empty()
