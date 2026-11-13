extends GutTest
## Saves written before mid-mission saving (ADR 0013) still load: the campaign's
## autosave as Phase 7 first wrote it, and the per-system dictionaries whose version
## went up for it (discovery sites, objectives, the commander's memory, buildings).
## A save file's text survives a round trip through SaveSlots unchanged.

const PATH: String = "user://test_save_versions_campaign.cfg"
const SAVES: String = "user://test_save_versions_saves/"
## A campaign autosave as `CampaignSession.save()` wrote it before this change.
const OLD_AUTOSAVE: String = """[campaign]

version=1
state={
"campaign": "kessel_trail",
"closed": [],
"current_node": "",
"discoveries": ["kessel_trail_beacon"],
"intel": 180,
"loadout": {
"cargo": "cargo_alloy"
},
"opened": ["kessel_proving", "kessel_storm", "kessel_uplink"],
"results": {
"kessel_proving": {
"attempts": 1,
"intel": 220,
"seconds": 640.0,
"won": true
}
},
"techs": ["survey_lab"],
"version": 1,
"won": ["kessel_proving"]
}
"""

var _saved_dir: String


func before_each() -> void:
	_saved_dir = SaveSlots.default_dir
	SaveSlots.default_dir = SAVES


func after_each() -> void:
	for slot: StringName in SaveSlots.slots():
		SaveSlots.remove(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES))
	SaveSlots.default_dir = _saved_dir
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_an_old_campaign_autosave_still_loads() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(OLD_AUTOSAVE)
	file.close()
	var session: CampaignSession = CampaignSession.new(load(SaveFixture.CAMPAIGN) as CampaignDef)
	session.path = PATH
	assert_true(session.load_saved())
	assert_eq(session.state.intel, 180)
	assert_eq(session.state.won, [&"kessel_proving"] as Array[StringName])
	assert_eq(session.state.techs, [&"survey_lab"] as Array[StringName])
	assert_eq(session.state.node_state(&"kessel_storm"), CampaignState.NODE_OPEN)


func test_a_version_1_discovery_site_loads_without_scan_progress() -> void:
	var site: DiscoverySite = DiscoverySite.new()
	(
		site
		. from_dict(
			{
				"version": 1,
				"entity_id": 7,
				"position": "Vector3(1, 0, 2)",
				"charted": true,
				"resolved_by": -1,
			}
		)
	)
	assert_eq(site.entity_id, 7)
	assert_eq(site.scan_progress, 0.0)
	site.from_dict({"version": 1, "entity_id": 7, "charted": true, "resolved_by": 0})
	assert_eq(site.scan_progress, 1.0, "resolved")
	site.free()


func test_a_scan_in_progress_survives_on_the_site() -> void:
	var site: DiscoverySite = DiscoverySite.new()
	site.set_scan_progress(0.4)
	var copy: DiscoverySite = DiscoverySite.new()
	copy.from_dict(site.to_dict())
	assert_almost_eq(copy.scan_progress, 0.4, 0.001)
	site.free()
	copy.free()


func test_a_version_1_objective_loads() -> void:
	var objective: Objective = Objective.new()
	(
		objective
		. from_dict(
			{
				"version": 1,
				"id": &"destroy_base",
				"state": &"done",
				"known": true,
				"progress": "2 known structures standing",
				"countdown": 300,
				"started": 10,
				"area": "Vector3(3, 0, 4)",
			}
		)
	)
	assert_eq(objective.state, Objective.STATE_DONE)
	assert_eq(objective.countdown_tick, 300)
	assert_eq(objective.area_center, Vector3(3, 0, 4))
	assert_eq(objective.progress_ratio, -1.0, "no bar saved: none")


func test_a_version_1_commander_memory_loads() -> void:
	var memory: CommanderMemory = CommanderMemory.new()
	(
		memory
		. from_dict(
			{
				"version": 1,
				"opening_index": 4,
				"waves_launched": 2,
				"last_attack_tick": 900,
				"last_scout_tick": 300,
				"attacks_on_base": 1,
			}
		)
	)
	assert_eq(memory.opening_index, 4)
	assert_eq(memory.waves_launched, 2)
	assert_false(memory.recalled)
	assert_true(memory.build_backoff.is_empty())


func test_the_commander_memory_keeps_everything_now() -> void:
	var memory: CommanderMemory = CommanderMemory.new()
	memory.threatened = true
	memory.storm_recalled = true
	memory.wave_rolled = 3
	memory.wave_premature = true
	memory.build_backoff[&"combine_forge"] = 1200
	var copy: CommanderMemory = CommanderMemory.new()
	copy.from_dict(memory.to_dict())
	assert_eq(copy.to_dict(), memory.to_dict())


func test_a_version_3_building_loads_and_shows_as_before() -> void:
	var building: Building = Building.new()
	building.def = load("res://data/buildings/concord_reactor.tres") as BuildingDef
	building.setup(false)
	(
		building
		. from_dict(
			{
				"version": 3,
				"entity_id": 12,
				"construction": {"version": 1, "build_time": 20.0, "work": 5.0},
				"health": {"version": 1, "current": 300.0, "max": 600.0},
				"sabotage": 0.25,
				"sabotaged": false,
			}
		)
	)
	assert_eq(building.entity_id, 12)
	assert_almost_eq(building.construction.progress(), 0.25, 0.001)
	assert_true(building.seen_by_player, "unchanged when not saved")
	assert_almost_eq(building.sabotage_progress, 0.25, 0.001)
	building.free()


func test_a_save_file_round_trips_its_text() -> void:
	var game: SaveGame = SaveGame.new()
	game.mission_path = "res://data/missions/conquest.tres"
	game.mission_id = &"conquest"
	game.title = "Proving Ground"
	game.seconds = 61.5
	game.saved_at = 1700000000
	game.landing = {"world": {"version": SimWorld.SAVE_VERSION, "units": []}, "n": 3}
	assert_eq(SaveSlots.write(SaveSlots.MANUAL[0], game), "")
	assert_false(FileAccess.file_exists(SaveSlots.path_of(SaveSlots.MANUAL[0]) + ".tmp"))
	var read: SaveGame = SaveSlots.read(SaveSlots.MANUAL[0])
	assert_not_null(read, SaveSlots.last_error)
	assert_eq(read.to_dict(), game.to_dict())
	assert_eq(read.kind, SaveGame.KIND_MISSION)
	var landing_count: int = read.landing["n"]
	assert_eq(landing_count, 3, "ints stay ints")
	assert_eq(SaveLoadPanel.format_played(61.5), "1:01")
	assert_eq(SaveLoadPanel.format_played(3725.0), "1:02:05")
