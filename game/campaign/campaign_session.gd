class_name CampaignSession
extends RefCounted
## One campaign in play (ADR 0012): its definition and state, the autosave, and the
## campaign's announcements on `Events`. `Main` owns one; the screens read it and call
## it, the landing flow asks it for the landing's modifiers and hands it the result.
##
## Autosave: one slot (`path`, a ConfigFile) written after every landing and every
## purchase or loadout change.

const PATH: String = "user://campaign.cfg"
const SLOT: StringName = &"autosave"
const SECTION: String = "campaign"

## Where new sessions save (tests point it elsewhere, like `Settings.path`).
static var default_path: String = PATH

var def: CampaignDef
var state: CampaignState
## Where this session saves.
var path: String = PATH
## The landing being played (its start parameters), or null.
var landing: LandingPlan = null


func _init(p_def: CampaignDef) -> void:
	def = p_def
	path = default_path
	state = CampaignState.new(def)


## True if an autosave exists at `at` (default: the default path).
static func has_save(at: String = "") -> bool:
	return FileAccess.file_exists(at if at != "" else default_path)


## Starts the campaign over and saves at once.
func start_new() -> void:
	state = CampaignState.new(def)
	landing = null
	save()


## Loads the autosave. False (state unchanged) when there is none or it cannot be read.
func load_saved() -> bool:
	if not load_quietly():
		return false
	Events.campaign_loaded.emit(SLOT)
	return true


## Reads the autosave without announcing it (to look at it, not to play it).
func load_quietly() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return false
	var value: Variant = config.get_value(SECTION, "state", {})
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	var loaded: CampaignState = CampaignState.from_dict(data, def)
	if loaded == null:
		return false
	state = loaded
	landing = null
	return true


func save() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "version", CampaignState.SAVE_VERSION)
	config.set_value(SECTION, "state", state.to_dict())
	var error: Error = config.save(path)
	if error == OK:
		Events.campaign_saved.emit(SLOT)
	else:
		Events.campaign_save_failed.emit(SLOT)
	return error


## Buys `tech_id`, announces it and saves. False if it cannot be bought.
func buy(tech_id: StringName) -> bool:
	if not state.buy(tech_id):
		return false
	Events.tech_unlocked.emit(def.tech(tech_id))
	save()
	return true


## Picks a loadout option and saves. False if it may not be picked.
func choose_loadout(slot_id: StringName, option_id: StringName) -> bool:
	if not state.choose_loadout(slot_id, option_id):
		return false
	save()
	return true


## Changes the campaign's difficulty (between landings) and saves. False when
## `level` is not a difficulty, it is already set, or a landing is in play.
func set_difficulty(level: StringName) -> bool:
	if not Difficulty.LEVELS.has(level) or level == state.difficulty or landing != null:
		return false
	state.difficulty = level
	save()
	return true


## Marks `node_id` as picked on the star map (if it is open).
func select(node_id: StringName) -> bool:
	if state.node_state(node_id) != CampaignState.NODE_OPEN:
		return false
	state.current_node = node_id
	return true


## Prepares the landing on the picked node: its plan and the mission's modifiers.
## Null when no open node is picked.
func begin_landing() -> LandingModifiers:
	if state.node_state(state.current_node) != CampaignState.NODE_OPEN:
		return null
	landing = LandingPlan.from_state(state, state.current_node)
	return LandingBuilder.build(def, landing)


## The modifiers the picked node would start with now (briefing preview), or null.
func preview() -> LandingModifiers:
	if state.current_node == &"":
		return null
	return LandingBuilder.build(def, LandingPlan.from_state(state, state.current_node))


## Writes the result of the landing in play into the campaign, announces it
## (landing resolved, Intel banked, route opened, tech now affordable) and saves.
## Returns the Intel banked (-1 when no landing was in play).
func resolve(result: MissionResult) -> int:
	if landing == null or result == null:
		return -1
	var route_node: RouteNodeDef = def.node(landing.node_id)
	var was_open: Array[StringName] = _open_nodes()
	var affordable_before: Array[StringName] = state.affordable_techs()
	var complete_before: bool = state.is_complete()
	var banked: int = state.resolve_landing(
		landing.node_id, result.won, result.intel_held, result.discoveries, result.seconds
	)
	state.current_node = &""
	landing = null
	Events.landing_resolved.emit(route_node, result.won, banked)
	if banked > 0:
		Events.advisor_alert.emit(&"campaign_intel_banked")
	for node_id: StringName in _open_nodes():
		if not was_open.has(node_id):
			Events.advisor_alert.emit(&"campaign_route_open")
			break
	for tech_id: StringName in state.affordable_techs():
		if not affordable_before.has(tech_id):
			Events.advisor_alert.emit(&"campaign_tech_available")
			break
	save()
	if state.is_complete() and not complete_before:
		Events.campaign_completed.emit()
	return banked


## Ends the landing in play without a result (quit from the pause menu).
func abandon_landing() -> void:
	landing = null


func _open_nodes() -> Array[StringName]:
	var result: Array[StringName] = []
	for route_node: RouteNodeDef in def.nodes:
		if route_node != null and state.node_state(route_node.id) == CampaignState.NODE_OPEN:
			result.append(route_node.id)
	return result
