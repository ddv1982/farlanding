extends GutTest
## MissionSoundRouter: briefing and debrief beds, the launch phrase and the
## Survey storm cues.


class FakeObjective:
	extends RefCounted
	var id: StringName = &""
	var title: String = ""
	var kind: StringName = &"primary"
	var state: StringName = &"active"
	var progress_text: String = ""
	var countdown_tick: int = -1
	var countdown_fails: bool = true


var _router: MissionSoundRouter
var _played: Array[StringName] = []
var _offered: Array[StringName] = []
var _beds: Array[StringName] = []
var _bed_ducks: Array[float] = []
var _bed_stops: int = 0
var _storm_gain: Array[float] = []


func before_each() -> void:
	_played.clear()
	_offered.clear()
	_beds.clear()
	_bed_ducks.clear()
	_bed_stops = 0
	_storm_gain.clear()
	_router = MissionSoundRouter.new()
	_router.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		for id: StringName in ids:
			if _exists(id):
				_played.append(id)
				return id
		return &""
	_router.offer_alert = func(kind: StringName) -> void: _offered.append(kind)
	_router.play_bed = func(id: StringName, duck_db: float) -> void:
		_beds.append(id)
		_bed_ducks.append(duck_db)
	_router.stop_bed = func() -> void: _bed_stops += 1
	_router.set_layer_gain = func(layer: StringName, db: float) -> void:
		if layer == MissionSoundRouter.STORM_LAYER:
			_storm_gain.append(db)
	add_child_autofree(_router)
	_router.set_process(false)


func _exists(id: StringName) -> bool:
	for group: String in ["ui", "sting", "advisor", "bed"]:
		if ResourceLoader.exists("res://data/sounds/%s/%s.tres" % [group, id]):
			return true
	return false


func _objective(id: StringName, kind: StringName = &"primary") -> FakeObjective:
	var objective: FakeObjective = FakeObjective.new()
	objective.id = id
	objective.kind = kind
	return objective


# --- Briefing, debrief, launch -----------------------------------------------


func test_briefing_bed_under_the_panel() -> void:
	_router.handle_ui_feedback(&"briefing_open", 0.0)
	assert_eq(_beds, [&"mus_briefing_bed"] as Array[StringName])
	assert_lt(_bed_ducks[0], 0.0, "the score dips")
	assert_true(_router.is_briefing_open())
	_router.handle_ui_feedback(&"briefing_close", 1.0)
	assert_eq(_bed_stops, 1)
	assert_false(_router.is_briefing_open())


func test_launch_after_mission_start_without_a_briefing() -> void:
	_router.handle_mission_started(10.0)
	assert_false(_router.update_launch(10.0 + MissionSoundRouter.LAUNCH_DELAY - 0.05))
	assert_true(_router.update_launch(10.0 + MissionSoundRouter.LAUNCH_DELAY))
	assert_eq(_played, [&"mus_sting_launch"] as Array[StringName])
	assert_false(_router.update_launch(20.0), "once per mission")


func test_launch_waits_for_a_briefing_opened_before_the_mission() -> void:
	_router.handle_ui_feedback(&"briefing_open", 0.0)
	_router.handle_mission_started(0.1)
	assert_false(_router.update_launch(5.0))
	_router.handle_ui_feedback(&"briefing_close", 30.0)
	assert_eq(_played, [&"mus_sting_launch"] as Array[StringName])


func test_launch_waits_for_a_briefing_opened_just_after() -> void:
	_router.handle_mission_started(0.0)
	_router.handle_ui_feedback(&"briefing_open", 0.1)
	assert_false(_router.update_launch(1.0))
	_router.handle_ui_feedback(&"briefing_close", 12.0)
	assert_eq(_played, [&"mus_sting_launch"] as Array[StringName])


func test_debrief_bed() -> void:
	_router.handle_ui_feedback(&"debrief_open", 0.0)
	assert_eq(_beds, [&"mus_debrief_bed"] as Array[StringName])
	_router.handle_mission_started(5.0)
	assert_eq(_bed_stops, 1, "a new mission stops it")


func test_the_beds_and_cues_exist() -> void:
	for id: StringName in [
		&"mus_briefing_bed",
		&"mus_debrief_bed",
		&"mus_sting_launch",
		&"mus_storm_minute",
		&"mus_storm_countdown",
		&"ui_briefing_tick",
		&"ui_briefing_open",
		&"ui_briefing_close",
		&"ui_debrief_open",
		&"ui_mission_select",
		&"ui_objective_tick",
	]:
		assert_true(_exists(id), String(id))
	var bed: SoundEvent = load("res://data/sounds/bed/mus_briefing_bed.tres") as SoundEvent
	var ogg: AudioStreamOggVorbis = bed.streams[0] as AudioStreamOggVorbis
	assert_true(ogg.loop, "the bed loops")
	assert_eq(
		AudioCueSelector.feedback_event(&"briefing_tick"),
		[&"ui_briefing_tick"] as Array[StringName]
	)


# --- Storm ----------------------------------------------------------------------


func test_storm_follows_the_deadline() -> void:
	var survey: FakeObjective = _objective(&"bank_intel")
	survey.countdown_tick = 1000
	_router.handle_objective_added(survey)
	var rate: int = SimClock.TICK_RATE
	assert_eq(_router.handle_sim_ticked(1000 - 61 * rate), &"")
	assert_eq(_router.handle_sim_ticked(1000 - 60 * rate), &"mus_storm_minute")
	assert_eq(_storm_gain[-1], 0.0, "the storm layer comes in")
	assert_eq(_router.handle_sim_ticked(1000 - 30 * rate), &"")
	assert_eq(_router.handle_sim_ticked(1000 - 10 * rate), &"mus_storm_countdown")
	assert_eq(_router.handle_sim_ticked(1000 - 5 * rate), &"", "once")
	assert_eq(_played, [&"mus_storm_minute", &"mus_storm_countdown"] as Array[StringName])


func test_a_survive_timer_is_not_a_storm() -> void:
	var hold: FakeObjective = _objective(&"hold")
	hold.countdown_tick = 100
	hold.countdown_fails = false
	_router.handle_objective_added(hold)
	assert_eq(_router.handle_sim_ticked(95), &"")


func test_beating_the_deadline_clears_the_storm() -> void:
	var survey: FakeObjective = _objective(&"bank_intel")
	survey.countdown_tick = 600
	_router.handle_objective_added(survey)
	_router.handle_sim_ticked(10)
	survey.state = &"done"
	_router.handle_objective_completed(survey)
	assert_eq(_storm_gain[-1], AudioMix.SILENT_DB)
	assert_eq(_router.handle_sim_ticked(599), &"")


func test_storm_alerts_as_a_fallback() -> void:
	assert_eq(_router.handle_advisor_alert(&"objective_time_low", 0.0), &"mus_storm_minute")
	assert_eq(
		_router.handle_advisor_alert(&"objective_time_low", 5.0), &"", "too soon to be the final"
	)
	assert_eq(_router.handle_advisor_alert(&"objective_time_low", 50.0), &"mus_storm_countdown")
	assert_eq(_router.handle_advisor_alert(&"storm_final", 55.0), &"")


func test_weather_storm_warning_is_not_a_deadline() -> void:
	# Phase 6: storm_warning is the weather's (StormSound); the Advisor voices
	# it, but it must not start the Survey deadline stages.
	assert_eq(_router.handle_advisor_alert(&"storm_warning", 0.0), &"")
	assert_eq(_router.storm_stage(), 0)
	assert_true(_storm_gain.is_empty() or _storm_gain[-1] == AudioMix.SILENT_DB)


func test_menu_theme_under_the_mission_select() -> void:
	_router.handle_ui_feedback(&"menu_open", 0.0)
	assert_eq(_beds[-1], MissionSoundRouter.MENU_THEME)
	assert_lt(_bed_ducks[-1], -30.0, "the score all but stops under the theme")
	assert_true(_router.is_menu_open())
	_router.handle_ui_feedback(&"menu_close", 1.0)
	assert_eq(_bed_stops, 1)
	_router.handle_ui_feedback(&"menu_close", 2.0)
	assert_eq(_bed_stops, 1, "a second close does not stop someone else's bed")


func test_mission_start_ends_the_menu_theme() -> void:
	_router.handle_ui_feedback(&"menu_open", 0.0)
	_router.handle_mission_started(1.0)
	assert_false(_router.is_menu_open())
	assert_eq(_bed_stops, 1)


func test_storm_final_alert() -> void:
	assert_eq(_router.handle_advisor_alert(&"storm_final", 0.0), &"mus_storm_countdown")
	assert_eq(_router.storm_stage(), 2)
