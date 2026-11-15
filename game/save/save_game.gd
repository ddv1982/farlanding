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
## The difficulty the landing is played at (Difficulty.LEVELS). Saves from before
## difficulty levels load as Normal.
var difficulty: StringName = Difficulty.NORMAL


## A save of the landing of `mission` in play: `landing` is the map's snapshot,
## `played` its game seconds, `session` the campaign in play (null: single mission),
## `level` the difficulty of a single mission (a campaign landing's comes from its plan).
static func capture(
	mission: MissionDef,
	landing_data: Dictionary,
	played: float,
	session: CampaignSession,
	level: StringName = Difficulty.NORMAL,
) -> SaveGame:
	var game: SaveGame = SaveGame.new()
	game.mission_path = mission.resource_path
	game.mission_id = mission.id
	game.title = mission.title
	game.seconds = played
	game.saved_at = int(Time.get_unix_time_from_system())
	game.landing = landing_data
	game.difficulty = Difficulty.sanitize(level)
	if session != null and session.landing != null:
		game.kind = KIND_CAMPAIGN
		game.campaign_path = session.def.resource_path
		game.plan = session.landing
		game.campaign = session.state.to_dict()
		game.difficulty = Difficulty.sanitize(session.landing.difficulty)
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
		"difficulty": String(difficulty),
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
	game.difficulty = Difficulty.sanitize(data.get("difficulty", Difficulty.NORMAL))
	return game


## Why `data` cannot be loaded, or "" when it can: a newer or unknown format, a
## missing mission, campaign or world, or any resource it names that this build does
## not have (a missing unit, building or weapon definition).
static func check(data: Dictionary) -> String:
	if not _containers(data, ["plan", "campaign", "landing"]):
		return "The save has malformed containers."
	for key: String in ["kind", "mission", "mission_id", "title", "campaign_def", "difficulty"]:
		if data.has(key) and not (data[key] is String or data[key] is StringName):
			return "The save has a malformed %s." % key
	for key: String in ["format", "saved_at"]:
		if data.has(key) and not data[key] is int:
			return "The save has a malformed %s." % key
	if data.has("seconds") and not (data.seconds is int or data.seconds is float):
		return "The save has malformed seconds."
	var version: int = data.get("format", 0)
	if version > FORMAT_VERSION:
		return "This save is from a newer version of the game (format %d)." % version
	if version < 1:
		return "This is not a Farlanding save."
	var path: String = data.get("mission", "")
	if not _resource_is(path, MissionDef):
		return "The mission of this save is missing (%s)." % path
	var kind_text: String = data.get("kind", String(KIND_MISSION))
	if kind_text not in [String(KIND_MISSION), String(KIND_CAMPAIGN)]:
		return "The kind of this save cannot be read."
	var plan_data: Dictionary = data.get("plan", {})
	if not _campaign_containers(plan_data, false):
		return "The landing plan of this save cannot be read."
	if kind_text == String(KIND_CAMPAIGN):
		var campaign_path: String = data.get("campaign_def", "")
		if not _resource_is(campaign_path, CampaignDef):
			return "The campaign of this save is missing (%s)." % campaign_path
		var campaign_data: Dictionary = data.get("campaign", {})
		if not _campaign_containers(campaign_data, true):
			return "The campaign state of this save cannot be read."
		if LandingPlan.from_dict(plan_data) == null:
			return "The landing plan of this save cannot be read."
	var landing_data: Dictionary = data.get("landing", {})
	if not _containers(landing_data, ["clock", "world", "mission", "groups"]):
		return "The landing in this save has malformed containers."
	if not _versions(landing_data, {"clock": SimClock.SAVE_VERSION}):
		return "The clock in this save cannot be read."
	var groups: Dictionary = landing_data.get("groups", {})
	for value: Variant in groups.values():
		if not value is Array:
			return "The control groups in this save cannot be read."
	if not _positions(landing_data, ["camera"], true):
		return "The camera in this save cannot be read."
	var world_data: Dictionary = landing_data.get("world", {})
	if not world_data.get("version", 0) is int:
		return "The world in this save has a malformed version."
	var world_version: int = world_data.get("version", 0)
	if world_version < 1 or world_version > SimWorld.SAVE_VERSION:
		return "The world in this save cannot be read (version %d)." % world_version
	var missing: String = _missing_resource(data)
	if missing != "":
		return "Something this save needs is missing: %s" % missing
	if not _world_containers(world_data):
		return "The world in this save has malformed data."
	var mission_data: Dictionary = landing_data.get("mission", {})
	if not _mission_containers(mission_data):
		return "The mission state in this save has malformed containers."
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


## Validate the containers the restore readers consume, keeping their defaults for
## omitted fields (including older world versions). Unknown metadata is ignored.
static func _containers(data: Dictionary, dictionaries: Array, arrays: Array = []) -> bool:
	for key: String in dictionaries:
		if data.has(key) and not data[key] is Dictionary:
			return false
	for key: String in arrays:
		if data.has(key) and not data[key] is Array:
			return false
	return true


static func _resource_is(path: Variant, expected: GDScript) -> bool:
	if not path is String:
		return false
	var text: String = path
	return text != "" and ResourceLoader.exists(text) and is_instance_of(load(text), expected)


static func _positions(
	data: Dictionary, keys: Array, allow_empty: bool = false, allow_unset: bool = false
) -> bool:
	for key: String in keys:
		if not data.has(key):
			continue
		if not data[key] is String:
			return false
		if allow_empty and data[key] == "":
			continue
		var serialized: String = data[key]
		var text: String = serialized.strip_edges()
		if allow_unset and text == var_to_str(Vector3.INF):
			continue
		# Check the serialized vector without asking str_to_var to parse broken
		# syntax (that would itself emit an engine error during preflight).
		if not text.begins_with("Vector3(") or not text.ends_with(")"):
			return false
		var parts: PackedStringArray = text.substr(8, text.length() - 9).split(",")
		if parts.size() != 3:
			return false
		for part: String in parts:
			if not part.strip_edges().is_valid_float() or not is_finite(part.to_float()):
				return false
	return true


static func _campaign_containers(data: Dictionary, state: bool) -> bool:
	if not _containers(
		data,
		["loadout", "results"] if state else ["loadout"],
		["techs", "discoveries", "opened", "won", "closed"]
	):
		return false
	if data.has("version") and not data.version is int:
		return false
	for key: String in ["node", "campaign", "current_node", "difficulty"]:
		if data.has(key) and not (data[key] is String or data[key] is StringName):
			return false
	if data.has("intel") and not data.intel is int:
		return false
	if state:
		var results: Dictionary = data.get("results", {})
		for entry: Variant in results.values():
			if not entry is Dictionary:
				return false
	return true


static func _world_containers(world: Dictionary) -> bool:
	if not _containers(
		world,
		["economy", "discovery", "vision", "stealth", "combat", "planet", "props"],
		["resource_nodes", "sites", "buildings", "units"]
	):
		return false
	if not _versions(
		world,
		{
			"economy": Economy.SAVE_VERSION,
			"discovery": Discovery.SAVE_VERSION,
			"vision": VisionSystem.SAVE_VERSION,
			"stealth": StealthSystem.SAVE_VERSION,
			"combat": Combat.SAVE_VERSION,
			"planet": 1,
			"props": 1
		}
	):
		return false
	if not _world_services(world):
		return false
	var classes: Dictionary = {
		"resource_nodes": ResourceNodeDef,
		"sites": DiscoveryDef,
		"buildings": BuildingDef,
		"units": UnitDef,
	}
	for collection: String in classes:
		for entry: Variant in world.get(collection, []):
			if not entry is Dictionary:
				return false
			var entity_data: Dictionary = entry
			var expected: GDScript = classes[collection]
			if not _entity_data(entity_data, expected):
				return false
	var props: Dictionary = world.get("props", {})
	if not _containers(props, [], ["props"]):
		return false
	for entry: Variant in props.get("props", []):
		if not entry is Dictionary:
			return false
		var prop_data: Dictionary = entry
		if not _entity_data(prop_data, PropDef):
			return false
	return true


static func _entity_data(data: Dictionary, expected: GDScript) -> bool:
	var maximum: int = {
		UnitDef: Unit.SAVE_VERSION,
		BuildingDef: Building.SAVE_VERSION,
		ResourceNodeDef: ResourceNode.SAVE_VERSION,
		DiscoveryDef: DiscoverySite.SAVE_VERSION,
		PropDef: Prop.SAVE_VERSION
	}[expected]
	if not _version(data, maximum):
		return false
	if not _resource_is(data.get("def", ""), expected) or not _positions(data, ["position"]):
		return false
	if not _containers(
		data,
		[
			"locomotion",
			"orders",
			"handlers",
			"health",
			"weapon",
			"dormancy",
			"watcher",
			"cloak",
			"construction",
			"producer",
			"flux",
			"machine"
		]
	):
		return false
	if not _versions(
		data,
		{
			"locomotion": Locomotion.SAVE_VERSION,
			"orders": UnitOrders.SAVE_VERSION,
			"health": Health.SAVE_VERSION,
			"weapon": Weapon.SAVE_VERSION,
			"dormancy": Dormancy.SAVE_VERSION,
			"watcher": Watcher.SAVE_VERSION,
			"cloak": Cloak.SAVE_VERSION,
			"construction": Construction.SAVE_VERSION,
			"producer": Producer.SAVE_VERSION,
			"flux": FluxExtractor.SAVE_VERSION,
			"machine": Machine.SAVE_VERSION
		}
	):
		return false
	var watcher: Dictionary = data.get("watcher", {})
	if not _positions(watcher, ["last_noticed"]):
		return false
	var handlers: Dictionary = data.get("handlers", {})
	for handler: Variant in handlers.values():
		if not handler is Dictionary:
			return false
	var locomotion: Dictionary = data.get("locomotion", {})
	if not _containers(locomotion, ["mover"]) or not _positions(locomotion, ["destination"]):
		return false
	if not _positions(locomotion, ["post", "wanted"], true, true):
		return false
	if not _versions(locomotion, {"mover": Mover.SAVE_VERSION}):
		return false
	var mover: Dictionary = locomotion.get("mover", {})
	if not _positions(mover, ["position"]):
		return false
	if mover.has("path"):
		if not mover.path is String:
			return false
		var path_text: String = mover.path
		if not path_text.begins_with("PackedVector3Array(") or not path_text.ends_with(")"):
			return false
		var coordinates: String = path_text.substr(19, path_text.length() - 20)
		if coordinates != "":
			var parts: PackedStringArray = coordinates.split(",")
			if parts.size() % 3 != 0:
				return false
			for part: String in parts:
				if not part.strip_edges().is_valid_float() or not is_finite(part.to_float()):
					return false
	var orders: Dictionary = data.get("orders", {})
	if not _containers(orders, ["current"], ["queue"]):
		return false
	var queued: Array = orders.get("queue", [])
	var all: Array = queued.duplicate()
	all.append(orders.get("current", {}))
	for order: Variant in all:
		if not order is Dictionary:
			return false
		var order_data: Dictionary = order
		if not order_data.is_empty() and not _version(order_data, Order.SAVE_VERSION):
			return false
		if not _positions(order_data, ["target", "offset", "guard"]):
			return false
	var producer: Dictionary = data.get("producer", {})
	if not _containers(producer, [], ["queue"]) or not _positions(producer, ["rally_point"]):
		return false
	for path: Variant in producer.get("queue", []):
		if not _resource_is(path, UnitDef):
			return false
	return true


static func _mission_containers(data: Dictionary) -> bool:
	if not _containers(
		data, ["commander", "guards", "script"], ["warned", "objectives", "triggers"]
	):
		return false
	for key: String in ["objectives", "triggers"]:
		for entry: Variant in data.get(key, []):
			if not entry is Dictionary:
				return false
	var objectives: Array = data.get("objectives", [])
	for objective: Dictionary in objectives:
		if not _version(objective, Objective.SAVE_VERSION) or not _positions(objective, ["area"]):
			return false
	var commander: Dictionary = data.get("commander", {})
	if not _positions(commander, ["home", "staging"]):
		return false
	if not _versions(commander, {"memory": CommanderMemory.SAVE_VERSION}):
		return false
	return _containers(
		commander,
		[
			"memory",
			"knowledge",
			"last_ordered",
			"attack",
			"defence",
			"scout",
			"survey",
			"retrieval",
			"machines"
		],
		["wave_sizes", "refused"]
	)


## Nonempty state dictionaries are passed to readers that assert their version.
## Keep each reader's historical range; the outer format stays unchanged.
static func _version(data: Dictionary, maximum: int) -> bool:
	var value: Variant = data.get("version", 0)
	return value is int and value >= 1 and value <= maximum


static func _versions(data: Dictionary, maxima: Dictionary[String, int]) -> bool:
	for key: String in maxima:
		if not data.has(key):
			continue
		if not data[key] is Dictionary:
			return false
		var state: Dictionary = data[key]
		if not state.is_empty() and not _version(state, maxima[key]):
			return false
	return true


static func _world_services(world: Dictionary) -> bool:
	var economy: Dictionary = world.get("economy", {})
	if not _containers(economy, ["stockpiles"]):
		return false
	var piles: Dictionary = economy.get("stockpiles", {})
	for entry: Variant in piles.values():
		if not entry is Dictionary:
			return false
		var pile: Dictionary = entry
		if not _version(pile, Stockpile.SAVE_VERSION):
			return false
	var discovery: Dictionary = world.get("discovery", {})
	if not _containers(discovery, ["codex", "field_options"], ["heal_fields"]):
		return false
	if not _versions(discovery, {"field_options": FieldOptions.SAVE_VERSION}):
		return false
	var vision: Dictionary = world.get("vision", {})
	if not _containers(vision, ["grid", "area_reveals"], ["factions"]):
		return false
	if not _versions(vision, {"grid": VisionGrid.SAVE_VERSION}):
		return false
	var grid: Dictionary = vision.get("grid", {})
	if not _containers(grid, ["explored"]):
		return false
	var stealth: Dictionary = world.get("stealth", {})
	if not _containers(stealth, ["levels", "noticed", "positions"], ["guard_factions"]):
		return false
	var combat: Dictionary = world.get("combat", {})
	if not _containers(combat, [], ["projectiles"]):
		return false
	for entry: Variant in combat.get("projectiles", []):
		if not entry is Dictionary:
			return false
		var shot: Dictionary = entry
		if not _version(shot, Projectile.SAVE_VERSION):
			return false
		if not _resource_is(shot.get("weapon", ""), WeaponDef):
			return false
		if not _positions(shot, ["start", "goal"]):
			return false
	return true
