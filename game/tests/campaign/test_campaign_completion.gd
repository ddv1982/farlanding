extends GutTest
## The end of the campaign (ADR 0017): the route runs from Verdance to Hollow
## Meridian's two landings, the second of which is final; winning it marks the campaign
## complete (saved, announced once), the debrief's Back opens the ending screen (the
## story and the campaign's numbers) which returns to the title, and Continue on a
## finished campaign opens the ending again instead of an empty star map.

const CAMPAIGN: String = "res://data/campaign/kessel_trail.tres"
const SAVE: String = "user://test_campaign_completion.cfg"
const SETTINGS: String = "user://test_campaign_completion_settings.cfg"
const SAVES: String = "user://test_campaign_completion_saves/"
const HOLLOW_TECHS: Array[StringName] = [&"resonance_keys", &"engine_bracing", &"custodian_hush"]

var _main: Main = null
var _saved_dir: String
var _saved_default: String
var _saved_settings: String
var _saved_seen: PackedStringArray
var _completed: int = 0
var _screens: Array[StringName] = []


func before_each() -> void:
	_saved_dir = SaveSlots.default_dir
	SaveSlots.default_dir = SAVES
	_saved_default = CampaignSession.default_path
	CampaignSession.default_path = SAVE
	_remove(SAVE)
	_saved_settings = Settings.path
	_saved_seen = Settings.hints_seen
	Settings.path = SETTINGS
	_completed = 0
	_screens.clear()
	Events.campaign_completed.connect(_on_completed)
	Events.campaign_screen_changed.connect(_on_screen)


func after_each() -> void:
	if _main != null:
		_main.queue_free()
		_main = null
		await wait_frames(2)
	for slot: StringName in SaveSlots.slots():
		SaveSlots.remove(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES))
	SaveSlots.default_dir = _saved_dir
	Events.campaign_completed.disconnect(_on_completed)
	Events.campaign_screen_changed.disconnect(_on_screen)
	CampaignSession.default_path = _saved_default
	Settings.path = _saved_settings
	Settings.hints_seen = _saved_seen
	_remove(SAVE)
	_remove(SETTINGS)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _on_completed() -> void:
	_completed += 1


func _on_screen(screen: StringName) -> void:
	_screens.append(screen)


func _def() -> CampaignDef:
	return load(CAMPAIGN) as CampaignDef


func _main_scene() -> Main:
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Main
	add_child(_main)
	return _main


## A campaign that has won everything up to the finale.
func _at_the_finale(session: CampaignSession) -> void:
	var state: CampaignState = session.state
	for node_id: StringName in [
		&"kessel_proving",
		&"kessel_storm",
		&"thalassa_shallows",
		&"thalassa_recovery",
		&"emberfall_conquest",
		&"emberfall_holdout",
		&"verdance_conquest",
		&"verdance_infiltration",
		&"hollow_power",
	]:
		state.resolve_landing(node_id, true, 50, [] as Array[StringName], 600.0)


func test_the_route_ends_on_hollow_meridian() -> void:
	var def: CampaignDef = load(CAMPAIGN)
	assert_eq(def.final_node, &"hollow_finale")
	assert_true(def.node(&"verdance_infiltration").leads_to.has(&"hollow_power"))
	assert_true(def.node(&"hollow_power").leads_to.has(&"hollow_finale"))
	assert_true(def.node(&"hollow_finale").leads_to.is_empty(), "nothing after the Core")
	assert_eq(def.node(&"hollow_power").planet.id, &"hollow_meridian")
	assert_eq(def.node(&"hollow_finale").mission.id, &"hollow_finale")
	for tech_id: StringName in HOLLOW_TECHS:
		var tech: TechDef = def.tech(tech_id)
		assert_not_null(tech, String(tech_id))
		assert_true(
			tech.requires_discovery.begins_with("hollow_"), "%s needs a Hollow find" % tech_id
		)
	var carried: Dictionary[StringName, bool] = {}
	for carryover: CarryoverDef in def.carryovers:
		carried[carryover.discovery] = true
	assert_true(carried.has(&"verdance_trail_root"), "the trail leads on to the last beacon")
	assert_true(carried.has(&"hollow_trail_terminus"), "the last beacon charts the annal")


func test_winning_the_finale_completes_the_campaign_once() -> void:
	var session: CampaignSession = CampaignSession.new(_def())
	session.start_new()
	_at_the_finale(session)
	assert_false(session.state.is_complete())
	assert_eq(session.state.node_state(&"hollow_finale"), CampaignState.NODE_OPEN)
	assert_true(session.select(&"hollow_finale"))
	assert_not_null(session.begin_landing())
	var result: MissionResult = MissionResult.new()
	result.won = true
	result.intel_held = 120
	result.discoveries = [&"hollow_core_annal"] as Array[StringName]
	session.resolve(result)
	assert_true(session.state.is_complete(), "the Trail is complete")
	assert_eq(_completed, 1, "announced")
	var reread: CampaignSession = CampaignSession.new(_def())
	assert_true(reread.load_quietly())
	assert_true(reread.state.is_complete(), "and saved")
	var stats: Dictionary[StringName, int] = reread.state.statistics()
	assert_eq(stats[&"landings_won"], 10)
	assert_eq(stats[&"landings_made"], 10)
	assert_eq(stats[&"intel_banked"], 9 * 50 + 120)
	assert_eq(stats[&"discoveries"], 1)
	assert_eq(stats[&"techs"], 0)
	assert_string_contains(EndingScreen.stats_text(reread.state), "10 won of 10 made")


func test_a_lost_finale_does_not_complete_it() -> void:
	var session: CampaignSession = CampaignSession.new(_def())
	session.start_new()
	_at_the_finale(session)
	session.select(&"hollow_finale")
	session.begin_landing()
	var result: MissionResult = MissionResult.new()
	result.won = false
	session.resolve(result)
	assert_false(session.state.is_complete())
	assert_eq(_completed, 0)
	assert_eq(session.state.node_state(&"hollow_finale"), CampaignState.NODE_OPEN, "retry")


func test_the_debrief_leads_to_the_ending_and_back_to_the_title() -> void:
	var main: Main = _main_scene()
	main.new_campaign()
	_at_the_finale(main.campaign)
	main.campaign.save()
	main.launch(&"hollow_finale")
	assert_true(main._briefing.visible, "the finale is briefed")
	main._briefing._on_start()
	await wait_frames(3)
	assert_not_null(main.runner, "landed on the deck")
	assert_true(main.runner.script_instance is CoreScript)
	main.runner.finish(true)
	assert_eq(_completed, 1)
	await wait_seconds(Main.DEBRIEF_DELAY + 0.3)
	assert_true(main._debrief.visible)
	assert_eq(main._debrief._back.text, "THE END OF THE TRAIL")
	main._debrief._on_back()
	assert_null(main.map, "the landing is closed")
	assert_true(main._ending.visible, "the ending")
	assert_false(main._star_map.visible)
	assert_eq(main.screen, &"ending")
	assert_true(_screens.has(&"ending"))
	assert_string_contains(main._ending._stats.text, "Landings")
	main._ending.title_pressed.emit()
	assert_true(main._title.visible, "back to the title")
	assert_null(main.campaign)
	assert_true(main._title._continue.visible, "a finished campaign can still be opened")


func test_continue_on_a_finished_campaign_opens_the_ending() -> void:
	var session: CampaignSession = CampaignSession.new(_def())
	session.start_new()
	_at_the_finale(session)
	session.state.resolve_landing(&"hollow_finale", true, 10, [] as Array[StringName], 900.0)
	session.save()
	var main: Main = _main_scene()
	main.continue_campaign()
	assert_not_null(main.campaign)
	assert_true(main.campaign.state.is_complete())
	assert_true(main._ending.visible, "the ending, not an empty star map")
	assert_false(main._star_map.visible)
	assert_eq(main.screen, &"ending")
