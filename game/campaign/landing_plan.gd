class_name LandingPlan
extends RefCounted
## The start parameters of one campaign landing, as plain data (ADR 0012): which route
## node, the techs owned, the loadout picked, and the discoveries already made when
## it launched. LandingBuilder turns it into the mission's LandingModifiers, so a
## mid-mission save only needs to store this to start the landing the same way.

const SAVE_VERSION: int = 1

var node_id: StringName = &""
var techs: Array[StringName] = []
## Slot id -> option id.
var loadout: Dictionary[StringName, StringName] = {}
var discoveries: Array[StringName] = []
## The campaign's difficulty when the landing launched (Difficulty.LEVELS).
var difficulty: StringName = Difficulty.NORMAL


## The plan for launching `node_id` from `state` now.
static func from_state(state: CampaignState, p_node_id: StringName) -> LandingPlan:
	var plan: LandingPlan = LandingPlan.new()
	plan.node_id = p_node_id
	plan.techs = state.techs.duplicate()
	plan.discoveries = state.discoveries.duplicate()
	plan.difficulty = state.difficulty
	if state.def != null:
		for slot: LoadoutSlotDef in state.def.loadout_slots:
			var option: LoadoutOptionDef = state.loadout_option(slot.id) if slot != null else null
			if option != null:
				plan.loadout[slot.id] = option.id
	return plan


func to_dict() -> Dictionary:
	var loadout_data: Dictionary = {}
	for slot_id: StringName in loadout:
		loadout_data[String(slot_id)] = String(loadout[slot_id])
	return {
		"version": SAVE_VERSION,
		"node": String(node_id),
		"techs": CampaignState._strings(techs),
		"loadout": loadout_data,
		"discoveries": CampaignState._strings(discoveries),
		"difficulty": String(difficulty),
	}


## The plan saved in `data`, or null for another save version.
static func from_dict(data: Dictionary) -> LandingPlan:
	var version: int = data.get("version", 0)
	if version != SAVE_VERSION:
		return null
	var plan: LandingPlan = LandingPlan.new()
	var node_name: String = data.get("node", "")
	plan.node_id = StringName(node_name)
	plan.techs = CampaignState._names(data.get("techs", []))
	plan.discoveries = CampaignState._names(data.get("discoveries", []))
	plan.difficulty = Difficulty.sanitize(data.get("difficulty", Difficulty.NORMAL))
	var loadout_data: Dictionary = data.get("loadout", {})
	for key: Variant in loadout_data:
		plan.loadout[StringName(str(key))] = StringName(str(loadout_data[key]))
	return plan
