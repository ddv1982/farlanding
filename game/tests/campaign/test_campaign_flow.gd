extends GutTest
## The Phase 7 flow on the real campaign and maps: the title first; New campaign
## opens the star map; launching a node briefs it and lands with the campaign's
## modifiers; the result is banked, saved and announced as the mission ends, and the
## debrief returns to the star map with the route opened. The second landing starts
## changed by what the first one bought; Continue loads the autosave; the pause
## menu quits to the star map.

const SAVE: String = "user://test_campaign_flow.cfg"
const SETTINGS: String = "user://test_campaign_flow_settings.cfg"
const SAVES: String = "user://test_campaign_flow_saves/"

var _main: Main
var _saved_dir: String
var _saved_default: String
var _saved_settings: String
var _saved_seen: PackedStringArray
var _screens: Array[StringName] = []
var _resolved: Array[Array] = []
var _alerts: Array[StringName] = []
var _feedback: Array[StringName] = []
var _saved: int = 0


func before_each() -> void:
	# Landing autosaves and quicksaves must not land in the real profile either.
	_saved_dir = SaveSlots.default_dir
	SaveSlots.default_dir = SAVES
	_saved_default = CampaignSession.default_path
	CampaignSession.default_path = SAVE
	_remove(SAVE)
	_saved_settings = Settings.path
	_saved_seen = Settings.hints_seen
	Settings.path = SETTINGS
	_screens.clear()
	_resolved.clear()
	_alerts.clear()
	_feedback.clear()
	_saved = 0
	Events.campaign_screen_changed.connect(_on_screen)
	Events.landing_resolved.connect(_on_resolved)
	Events.advisor_alert.connect(_on_alert)
	Events.ui_feedback.connect(_on_feedback)
	Events.campaign_saved.connect(_on_saved)
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Main
	add_child(_main)


func after_each() -> void:
	_main.queue_free()
	await wait_frames(2)
	for slot: StringName in SaveSlots.slots():
		SaveSlots.remove(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES))
	SaveSlots.default_dir = _saved_dir
	Events.campaign_screen_changed.disconnect(_on_screen)
	Events.landing_resolved.disconnect(_on_resolved)
	Events.advisor_alert.disconnect(_on_alert)
	Events.ui_feedback.disconnect(_on_feedback)
	Events.campaign_saved.disconnect(_on_saved)
	CampaignSession.default_path = _saved_default
	Settings.path = _saved_settings
	Settings.hints_seen = _saved_seen
	_remove(SAVE)
	_remove(SETTINGS)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _on_screen(screen: StringName) -> void:
	_screens.append(screen)


func _on_resolved(node: Resource, won: bool, banked: int) -> void:
	_resolved.append([(node as RouteNodeDef).id, won, banked])


func _on_alert(kind: StringName) -> void:
	_alerts.append(kind)


func _on_feedback(kind: StringName) -> void:
	_feedback.append(kind)


func _on_saved(_slot: StringName) -> void:
	_saved += 1


## Launches `node_id` from the star map and lands it.
func _land(node_id: StringName) -> void:
	_main.launch(node_id)
	assert_true(_main._briefing.visible, "briefed")
	_main._briefing._on_start()
	await wait_frames(3)
	assert_not_null(_main.runner, "landed")


func test_the_title_comes_first() -> void:
	assert_true(_main._title.visible)
	assert_eq(_main.screen, &"title")
	assert_false(_main._title._continue.visible, "nothing to continue yet")
	_main._title.missions_pressed.emit()
	assert_true(_main._select.visible, "single missions")
	assert_null(_main.campaign)
	_main._select.back_pressed.emit()
	assert_true(_main._title.visible)
	assert_true(_feedback.has(&"title_open"))


func test_new_campaign_launch_resolve_and_back_to_the_map() -> void:
	_main._title.new_campaign_pressed.emit()
	assert_not_null(_main.campaign)
	assert_true(_main._star_map.visible)
	assert_eq(_main.screen, &"star_map")
	assert_true(FileAccess.file_exists(SAVE), "a new campaign saves at once")
	assert_true(_feedback.has(&"map_open"))
	assert_false(_main._star_map.pick(&"kessel_storm"), "locked nodes cannot be picked")
	assert_true(_main._star_map.pick(&"kessel_proving"))
	assert_false(_main._star_map._launch.disabled)
	await _land(&"kessel_proving")
	var last_screen: StringName = _screens.back()
	assert_eq(last_screen, &"", "the landing has the screen")
	var world: SimWorld = _main.runner.world
	assert_true(FactionPerks.of(world.perks, 0).is_locked(&"concord_survey_lab"))
	world.economy.add_intel(0, 160)
	var held: int = world.economy.stockpile(0).intel
	_main.runner.finish(true)
	assert_eq(_resolved.size(), 1, "resolved as the mission ends")
	assert_eq(_resolved[0], [&"kessel_proving", true, held])
	assert_eq(_main.campaign.state.intel, held)
	assert_true(_alerts.has(&"campaign_intel_banked"))
	assert_true(_alerts.has(&"campaign_route_open"))
	assert_true(_alerts.has(&"campaign_tech_available"))
	var saved: CampaignSession = CampaignSession.new(_main.campaign_def)
	assert_true(saved.load_saved(), "the autosave has the result")
	assert_eq(saved.state.intel, held)
	await wait_seconds(Main.DEBRIEF_DELAY + 0.3)
	assert_true(_main._debrief.visible)
	assert_eq(_main._debrief._back.text, "BACK TO STAR MAP")
	assert_false(_main._debrief._retry.visible, "a won landing is not replayed")
	_main._debrief._on_back()
	assert_null(_main.map)
	assert_true(_main._star_map.visible)
	assert_eq(_main.campaign.state.node_state(&"kessel_storm"), CampaignState.NODE_OPEN)


func test_the_second_landing_is_changed_by_the_first() -> void:
	_main.new_campaign()
	var session: CampaignSession = _main.campaign
	session.state.resolve_landing(
		&"kessel_proving", true, 400, [&"kessel_trail_beacon"] as Array[StringName], 600.0
	)
	_main.show_meridian()
	assert_eq(_main.screen, &"meridian")
	_main._meridian.show_tab(MeridianScreen.TAB_TECH)
	assert_eq(_main.screen, &"tech_web")
	var web: TechWebView = _main._meridian.tech_web()
	assert_false(web.buy(&"deep_scan"), "needs the lab first")
	assert_true(_feedback.has(&"tech_denied"))
	assert_true(web.buy(&"survey_lab"))
	assert_true(web.buy(&"hauler_racks"))
	assert_true(_feedback.has(&"tech_buy"))
	_main._meridian.show_tab(MeridianScreen.TAB_LOADOUT)
	assert_eq(_main.screen, &"loadout")
	assert_true(_main._meridian.loadout().choose(&"escort", &"escort_rangers"))
	assert_true(_feedback.has(&"loadout_change"))
	assert_eq(_main.campaign.state.intel, 400 - 90 - 130, "the lab and racks (ADR 0018 costs)")
	var reloaded: CampaignSession = CampaignSession.new(_main.campaign_def)
	assert_true(reloaded.load_saved(), "purchases autosave")
	assert_eq(reloaded.state.techs, [&"survey_lab", &"hauler_racks"] as Array[StringName])
	_main._meridian.star_map_pressed.emit()
	assert_eq(_main.screen, &"star_map")
	await _land(&"kessel_storm")
	var world: SimWorld = _main.runner.world
	var perks: FactionPerks = FactionPerks.of(world.perks, 0)
	assert_false(perks.is_locked(&"concord_survey_lab"), "the lab is cleared")
	assert_true(perks.is_locked(&"concord_lancer"), "the Lancer is not")
	var rangers: int = 0
	for unit: Unit in world.units_of(0):
		if unit.def.id == &"concord_ranger":
			rangers += 1
		if unit.def.id == &"concord_hauler":
			assert_eq(unit.carry_capacity, roundi(unit.def.carry_capacity * 1.25))
	assert_eq(rangers, 2, "the escort landed")
	var ruin: DiscoverySite = world.discovery.site_of(&"kessel_trail_ruin")
	assert_not_null(ruin)
	assert_true(ruin.charted, "the beacon found on the first landing charted the ruin")


func test_continue_loads_the_autosave() -> void:
	_main.new_campaign()
	_main.campaign.state.intel = 77
	_main.campaign.save()
	_main.show_title()
	assert_null(_main.campaign)
	assert_true(_main._title._continue.visible)
	_main._title.continue_pressed.emit()
	assert_not_null(_main.campaign)
	assert_eq(_main.campaign.state.intel, 77)
	assert_true(_main._star_map.visible)


func test_pause_quit_returns_to_the_star_map_without_a_result() -> void:
	_main.new_campaign()
	await _land(&"kessel_proving")
	_main.open_pause()
	assert_eq(_main._pause._quit.text, "QUIT TO STAR MAP")
	_main._pause.quit_pressed.emit()
	assert_null(_main.map)
	assert_true(_main._star_map.visible)
	assert_eq(_main.campaign.state.won.size(), 0, "nothing was resolved")
	assert_true(_resolved.is_empty())
