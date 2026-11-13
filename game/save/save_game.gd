class_name SaveGame
extends RefCounted
## One saved landing (ADR 0013): enough to build the same mission on its map again
## and put it back exactly where it was. A campaign landing also carries its
## LandingPlan (so the map gets the same modifiers) and the campaign state at save
## time; a single mission only its MissionDef. The landing itself is the map's
## `snapshot()`: sim clock, world, mission runner and AI, camera, control groups.
##
## `check()` decides whether a save can be loaded at all (its format version, every
## resource it names) before anything in the running game is touched.

## Bump when anything in a save changes shape (any SAVE_VERSION below it), so an
## older build refuses a newer save instead of misreading it. 2: the tide, carried
## artefacts and units waiting for the sea (ADR 0014); format 1 saves still load.
const FORMAT_VERSION: int = 2
const KIND_CAMPAIGN: StringName = &"campaign"
const KIND_MISSION: StringName = &"mission"

var format: int = FORMAT_VERSION
## &"campaign" (a landing of the campaign in play) or &"mission" (a single mission).
var kind: StringName = KIND_MISSION
## The MissionDef played (its resource path) and, for the slot list, its id and title.
var mission_path: String = ""
var mission_id: StringName = &""
var title: String = ""
## Game seconds since the landing began, and when it was saved (Unix time, seconds).
var seconds: float = 0.0
var saved_at: int = 0
## Campaign landings: the CampaignDef, the plan the landing started with and the
## campaign state (CampaignState.to_dict()) when it was saved.
var campaign_path: String = ""
var plan: LandingPlan = null
var campaign: Dictionary = {}
## The map's snapshot of the landing.
var landing: Dictionary = {}


## A save of the landing of `mission` in play: `landing` is the map's snapshot,
## `played` its game seconds, `session` the campaign in play (null: single mission).
static func capture(
	mission: MissionDef, landing_data: Dictionary, played: float, session: CampaignSession
) -> SaveGame:
	var game: SaveGame = SaveGame.new()
	game.mission_path = mission.resource_path
	game.mission_id = mission.id
	game.title = mission.title
	game.seconds = played
	game.saved_at = int(Time.get_unix_time_from_system())
	game.landing = landing_data
	if session != null and session.landing != null:
		game.kind = KIND_CAMPAIGN
		game.campaign_path = session.def.resource_path
		game.plan = session.landing
		game.campaign = session.state.to_dict()
	return game


func to_dict() -> Dictionary:
	return {
		"format": format,
		"kind": String(kind),
		"mission": mission_path,
		"mission_id": String(mission_id),
		"title": title,
		"seconds": seconds,
		"saved_at": saved_at,
		"campaign_def": campaign_path,
		"plan": plan.to_dict() if plan != null else {},
		"campaign": campaign,
		"landing": landing,
	}


## The save in `data`, or null when `check(data)` finds it unusable.
static func from_dict(data: Dictionary) -> SaveGame:
	if check(data) != "":
		return null
	var game: SaveGame = SaveGame.new()
	game.format = data.get("format", FORMAT_VERSION)
	var kind_text: String = data.get("kind", String(KIND_MISSION))
	game.kind = StringName(kind_text)
	game.mission_path = data.get("mission", "")
	var id_text: String = data.get("mission_id", "")
	game.mission_id = StringName(id_text)
	game.title = data.get("title", "")
	game.seconds = data.get("seconds", 0.0)
	game.saved_at = data.get("saved_at", 0)
	game.campaign_path = data.get("campaign_def", "")
	var plan_data: Dictionary = data.get("plan", {})
	game.plan = LandingPlan.from_dict(plan_data) if not plan_data.is_empty() else null
	game.campaign = data.get("campaign", {})
	game.landing = data.get("landing", {})
	return game


## Why `data` cannot be loaded, or "" when it can: a newer or unknown format, a
## missing mission, campaign or world, or any resource it names that this build does
## not have (a missing unit, building or weapon definition).
static func check(data: Dictionary) -> String:
	var version: int = data.get("format", 0)
	if version > FORMAT_VERSION:
		return "This save is from a newer version of the game (format %d)." % version
	if version < 1:
		return "This is not a Farlanding save."
	var path: String = data.get("mission", "")
	if path == "" or not ResourceLoader.exists(path):
		return "The mission of this save is missing (%s)." % path
	var kind_text: String = data.get("kind", "")
	if kind_text == String(KIND_CAMPAIGN):
		var campaign_path: String = data.get("campaign_def", "")
		var plan_data: Dictionary = data.get("plan", {})
		if campaign_path == "" or not ResourceLoader.exists(campaign_path):
			return "The campaign of this save is missing (%s)." % campaign_path
		if LandingPlan.from_dict(plan_data) == null:
			return "The landing plan of this save cannot be read."
	var landing_data: Dictionary = data.get("landing", {})
	var world_data: Dictionary = landing_data.get("world", {})
	var world_version: int = world_data.get("version", 0)
	if world_version < 1 or world_version > SimWorld.SAVE_VERSION:
		return "The world in this save cannot be read (version %d)." % world_version
	var missing: String = _missing_resource(data)
	if missing != "":
		return "Something this save needs is missing: %s" % missing
	return ""


## The MissionDef played, or null.
func mission_def() -> MissionDef:
	if mission_path == "" or not ResourceLoader.exists(mission_path):
		return null
	return load(mission_path) as MissionDef


## The CampaignDef of a campaign landing, or null.
func campaign_def() -> CampaignDef:
	if campaign_path == "" or not ResourceLoader.exists(campaign_path):
		return null
	return load(campaign_path) as CampaignDef


## The first resource path in `value` (nested dictionaries and arrays) that does not
## exist, or "".
static func _missing_resource(value: Variant) -> String:
	if value is String:
		var text: String = value
		if text.begins_with("res://") and not ResourceLoader.exists(text):
			return text
		return ""
	if value is Dictionary:
		var dictionary: Dictionary = value
		for entry: Variant in dictionary.values():
			var found: String = _missing_resource(entry)
			if found != "":
				return found
		return ""
	if value is Array:
		var array: Array = value
		for entry: Variant in array:
			var found: String = _missing_resource(entry)
			if found != "":
				return found
	return ""
