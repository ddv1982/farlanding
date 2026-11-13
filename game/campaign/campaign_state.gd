class_name CampaignState
extends RefCounted
## Everything a campaign remembers between landings (ADR 0012): banked Intel, owned
## techs, the route's progress, discoveries made, and the loadout picked. Pure data
## and rules; it reads its CampaignDef but never touches the scene tree, so tests
## can drive it directly. `to_dict()`/`from_dict()` carry a version.

const SAVE_VERSION: int = 1
## Route node states.
const NODE_LOCKED: StringName = &"locked"
const NODE_OPEN: StringName = &"open"
const NODE_WON: StringName = &"won"
## Won on the other side of a branch: never playable.
const NODE_CLOSED: StringName = &"closed"
## Tech states.
const TECH_LOCKED: StringName = &"locked"
const TECH_AVAILABLE: StringName = &"available"
const TECH_AFFORDABLE: StringName = &"affordable"
const TECH_OWNED: StringName = &"owned"

var def: CampaignDef
## Intel banked from won landings, spent on the tech web.
var intel: int = 0
## Owned tech ids, in the order bought.
var techs: Array[StringName] = []
## Node ids opened so far (a node stays open until it is won or closed).
var opened: Array[StringName] = []
## Node ids won, in order.
var won: Array[StringName] = []
## Node ids closed by a branch taken.
var closed: Array[StringName] = []
## Per node id: { attempts, won, intel_banked, seconds }.
var results: Dictionary[StringName, Dictionary] = {}
## Discovery ids made on any landing (the campaign's codex), in order.
var discoveries: Array[StringName] = []
## Loadout: slot id -> option id.
var loadout: Dictionary[StringName, StringName] = {}
## The node picked on the star map (or being played), or &"".
var current_node: StringName = &""


func _init(p_def: CampaignDef = null) -> void:
	def = p_def
	if def != null and def.start_node != &"":
		opened.append(def.start_node)


## The state of route node `node_id`: NODE_LOCKED, NODE_OPEN, NODE_WON or NODE_CLOSED.
## An opened node whose tech or node requirements are not met yet stays locked.
func node_state(node_id: StringName) -> StringName:
	if won.has(node_id):
		return NODE_WON
	if closed.has(node_id):
		return NODE_CLOSED
	if not opened.has(node_id):
		return NODE_LOCKED
	var route_node: RouteNodeDef = def.node(node_id) if def != null else null
	return NODE_OPEN if _requirements_met(route_node) else NODE_LOCKED


## The state of tech `tech_id` on the web.
func tech_state(tech_id: StringName) -> StringName:
	if techs.has(tech_id):
		return TECH_OWNED
	var tech: TechDef = def.tech(tech_id) if def != null else null
	if tech == null:
		return TECH_LOCKED
	for needed: StringName in tech.requires:
		if not techs.has(needed):
			return TECH_LOCKED
	if tech.requires_discovery != &"" and not discoveries.has(tech.requires_discovery):
		return TECH_LOCKED
	return TECH_AFFORDABLE if intel >= tech.intel_cost else TECH_AVAILABLE


## Buys `tech_id` with banked Intel. Returns false (and changes nothing) unless it is
## affordable.
func buy(tech_id: StringName) -> bool:
	if tech_state(tech_id) != TECH_AFFORDABLE:
		return false
	intel -= def.tech(tech_id).intel_cost
	techs.append(tech_id)
	return true


## Tech ids the player could buy right now.
func affordable_techs() -> Array[StringName]:
	var result: Array[StringName] = []
	if def == null:
		return result
	for tech: TechDef in def.techs:
		if tech != null and tech_state(tech.id) == TECH_AFFORDABLE:
			result.append(tech.id)
	return result


## Writes a landing's outcome. Won: the stockpiled Intel is banked, the node is won,
## its `leads_to` open and its `excludes` close. Lost: the campaign's
## `lost_landing_share` of the Intel is banked and the node stays open. Discoveries
## count either way (the data reached orbit). Returns the Intel banked.
func resolve_landing(
	node_id: StringName, was_won: bool, intel_held: int, found: Array[StringName], seconds: float
) -> int:
	var banked: int = maxi(intel_held, 0)
	if not was_won:
		banked = floori(banked * (def.lost_landing_share if def != null else 0.0))
	intel += banked
	for discovery_id: StringName in found:
		if not discoveries.has(discovery_id):
			discoveries.append(discovery_id)
	var entry: Dictionary = results.get(node_id, {"attempts": 0, "won": false})
	var attempts: int = entry.get("attempts", 0)
	var won_before: bool = entry.get("won", false)
	var banked_before: int = entry.get("intel_banked", 0)
	entry["attempts"] = attempts + 1
	entry["won"] = won_before or was_won
	entry["intel_banked"] = banked_before + banked
	entry["seconds"] = seconds
	results[node_id] = entry
	if was_won:
		_win(node_id)
	return banked


## Picks `option_id` for loadout slot `slot_id`. False if the option is unknown or its
## techs are not owned.
func choose_loadout(slot_id: StringName, option_id: StringName) -> bool:
	if not can_choose(slot_id, option_id):
		return false
	loadout[slot_id] = option_id
	return true


## True if `option_id` of slot `slot_id` may be picked with the techs owned.
func can_choose(slot_id: StringName, option_id: StringName) -> bool:
	var slot: LoadoutSlotDef = def.slot(slot_id) if def != null else null
	var option: LoadoutOptionDef = slot.option(option_id) if slot != null else null
	if option == null:
		return false
	for tech_id: StringName in option.requires_tech:
		if not techs.has(tech_id):
			return false
	return true


## The option picked for `slot_id`: the chosen one while its techs are owned,
## otherwise the slot's first option.
func loadout_option(slot_id: StringName) -> LoadoutOptionDef:
	var slot: LoadoutSlotDef = def.slot(slot_id) if def != null else null
	if slot == null or slot.options.is_empty():
		return null
	var chosen: StringName = loadout.get(slot_id, &"")
	if chosen != &"" and can_choose(slot_id, chosen):
		return slot.option(chosen)
	return slot.options[0]


func to_dict() -> Dictionary:
	var loadout_data: Dictionary = {}
	for slot_id: StringName in loadout:
		loadout_data[String(slot_id)] = String(loadout[slot_id])
	var result_data: Dictionary = {}
	for node_id: StringName in results:
		result_data[String(node_id)] = results[node_id].duplicate()
	return {
		"version": SAVE_VERSION,
		"campaign": String(def.id) if def != null else "",
		"intel": intel,
		"techs": _strings(techs),
		"opened": _strings(opened),
		"won": _strings(won),
		"closed": _strings(closed),
		"results": result_data,
		"discoveries": _strings(discoveries),
		"loadout": loadout_data,
		"current_node": String(current_node),
	}


## A state rebuilt from `data` for `p_def`, or null when the data is from another
## save version or another campaign (the caller decides what to do then).
static func from_dict(data: Dictionary, p_def: CampaignDef) -> CampaignState:
	var version: int = data.get("version", 0)
	if version != SAVE_VERSION or p_def == null:
		return null
	var campaign: String = data.get("campaign", "")
	if campaign != String(p_def.id):
		return null
	var state: CampaignState = CampaignState.new(p_def)
	var banked: int = data.get("intel", 0)
	state.intel = maxi(banked, 0)
	state.techs = _names(data.get("techs", []))
	state.opened = _names(data.get("opened", []))
	state.won = _names(data.get("won", []))
	state.closed = _names(data.get("closed", []))
	state.discoveries = _names(data.get("discoveries", []))
	var result_data: Dictionary = data.get("results", {})
	for key: Variant in result_data:
		var entry: Dictionary = result_data[key]
		state.results[StringName(str(key))] = entry.duplicate()
	var loadout_data: Dictionary = data.get("loadout", {})
	for key: Variant in loadout_data:
		state.loadout[StringName(str(key))] = StringName(str(loadout_data[key]))
	var current: String = data.get("current_node", "")
	state.current_node = StringName(current)
	return state


func _requirements_met(route_node: RouteNodeDef) -> bool:
	if route_node == null:
		return false
	for tech_id: StringName in route_node.requires_tech:
		if not techs.has(tech_id):
			return false
	for needed: StringName in route_node.requires_nodes:
		if not won.has(needed):
			return false
	return true


func _win(node_id: StringName) -> void:
	if not won.has(node_id):
		won.append(node_id)
	opened.erase(node_id)
	var route_node: RouteNodeDef = def.node(node_id) if def != null else null
	if route_node == null:
		return
	for excluded: StringName in route_node.excludes:
		if not won.has(excluded) and not closed.has(excluded):
			closed.append(excluded)
			opened.erase(excluded)
	for next: StringName in route_node.leads_to:
		if not won.has(next) and not closed.has(next) and not opened.has(next):
			opened.append(next)


static func _strings(names: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for entry: StringName in names:
		result.append(String(entry))
	return result


static func _names(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		var list: Array = values
		for entry: Variant in list:
			result.append(StringName(str(entry)))
	return result
