extends GutTest
## Phase 8b, the Holdout mission's survival timer: HoldoutCues and the
## HoldoutSound node with stubs (the holdout layer, the one-minute cue, the
## approaching engine, the arrival), and the MissionSoundRouter leaving
## survival timers alone (its storm cues are for deadlines that fail).
## Sim ticks are emitted by hand at SimClock.TICK_RATE.

const EVENTS_DIR: String = "res://data/sounds"


class FakeObjective:
	extends RefCounted
	var id: StringName = &"hold"
	var title: String = "Hold the landing site"
	var kind: StringName = &"primary"
	var state: StringName = &"active"
	var progress_text: String = ""
	var countdown_tick: int = -1
	var countdown_fails: bool = false


var _sound: HoldoutSound
var _played: Array[StringName] = []
var _gains: Array[float] = []


func before_each() -> void:
	_played.clear()
	_gains.clear()
	_sound = HoldoutSound.new()
	_sound.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		_played.append(ids[0])
		return ids[0]
	_sound.resolve_event = func(id: StringName) -> SoundEvent:
		var path: String = "%s/sting/%s.tres" % [EVENTS_DIR, id]
		return load(path) as SoundEvent if ResourceLoader.exists(path) else null
	_sound.set_music_gain = func(db: float) -> void: _gains.append(db)
	add_child_autofree(_sound)
	_sound.set_process(false)


func after_each() -> void:
	_sound.handle_mission_started()
	(Audio.get_node(^"Holdout") as HoldoutSound).handle_mission_started()


## A survival timer ending `seconds` after tick 0.
func _timer(seconds: float) -> FakeObjective:
	var objective: FakeObjective = FakeObjective.new()
	objective.countdown_tick = int(seconds * SimClock.TICK_RATE)
	return objective


func _tick_at(seconds: float) -> StringName:
	return _sound.handle_sim_ticked(int(seconds * SimClock.TICK_RATE))


# --- Pure rules -------------------------------------------------------------------


func test_stages_and_the_engine_approach() -> void:
	assert_eq(HoldoutCues.stage_for(INF), 0)
	assert_eq(HoldoutCues.stage_for(200.0), 0)
	assert_eq(HoldoutCues.stage_for(HoldoutCues.LAYER_SECONDS), 1)
	assert_eq(HoldoutCues.stage_for(HoldoutCues.MINUTE), 2)
	assert_eq(HoldoutCues.stage_for(HoldoutCues.FINAL), 3)
	assert_lt(HoldoutCues.engine_db(10.0), HoldoutCues.engine_db(0.0), "the engine nears")
	assert_lt(HoldoutCues.engine_pitch(10.0), HoldoutCues.engine_pitch(0.0))


func test_only_survival_timers_count() -> void:
	var survive: FakeObjective = _timer(100.0)
	assert_true(HoldoutCues.is_survival(survive))
	var deadline: FakeObjective = _timer(100.0)
	deadline.countdown_fails = true
	assert_false(HoldoutCues.is_survival(deadline), "a deadline that fails is the storm's")
	var done: FakeObjective = _timer(100.0)
	done.state = &"completed"
	assert_false(HoldoutCues.is_survival(done))
	assert_false(HoldoutCues.is_survival(FakeObjective.new()), "no countdown")


# --- The node ---------------------------------------------------------------------


func test_the_last_minutes_sound_like_help_arriving() -> void:
	var objective: FakeObjective = _timer(200.0)
	_sound.handle_objective(objective)
	assert_eq(_tick_at(0.0), &"")
	assert_eq(_gains[-1], AudioMix.SILENT_DB, "nothing yet")
	_tick_at(200.0 - 119.0)
	assert_eq(_gains[-1], HoldoutCues.LAYER_EARLY_DB, "the holdout layer comes in")
	assert_eq(_tick_at(200.0 - 59.0), HoldoutCues.MINUTE_CUE, "a minute: help on the way")
	assert_eq(_gains[-1], 0.0, "the layer at full")
	assert_eq(_tick_at(200.0 - 30.0), &"", "nothing twice")
	assert_eq(_tick_at(200.0 - 9.5), HoldoutCues.ENGINE, "the engine approaches")
	assert_true(_sound.engine_playing())
	var last: Array[float] = _sound.engine_state()
	for k: int in 80:
		_tick_at(200.0 - 9.4 + k * 0.1)
		_sound.advance(0.1)
		var now: Array[float] = _sound.engine_state()
		assert_true(now[0] >= last[0] - 0.001, "louder as it nears")
		assert_true(now[1] >= last[1] - 0.0001, "and higher")
		last = now
	assert_eq(_played.count(HoldoutCues.MINUTE_CUE), 1)
	Events.advisor_alert.emit(&"extraction_arrived")
	assert_true(_sound.has_arrived())
	assert_eq(_played[-1], HoldoutCues.ARRIVED, "the engine resolves")
	assert_eq(_gains[-1], AudioMix.SILENT_DB, "the layer goes")
	for k: int in 12:
		_sound.advance(0.1)
	assert_false(_sound.engine_playing(), "the engine fades out")
	_sound.handle_objective_completed(objective)
	assert_eq(_played.count(HoldoutCues.ARRIVED), 1, "once")


func test_the_timer_running_out_is_arrival_too() -> void:
	var objective: FakeObjective = _timer(30.0)
	_sound.handle_objective(objective)
	_tick_at(25.0)
	_sound.handle_objective_completed(objective)
	assert_eq(_played[-1], HoldoutCues.ARRIVED)
	Events.advisor_alert.emit(&"extraction_arrived")
	assert_eq(_played.count(HoldoutCues.ARRIVED), 1, "the alert after it adds nothing")


func test_a_restored_holdout_enters_the_right_stage() -> void:
	_sound.handle_mission_started()
	var objective: FakeObjective = _timer(5.0)
	_sound.handle_objective(objective)
	assert_eq(_tick_at(0.0), HoldoutCues.ENGINE, "five seconds left: straight to the engine")
	assert_false(_played.has(HoldoutCues.MINUTE_CUE), "no minute cue in the last seconds")
	assert_eq(_gains[-1], 0.0)


func test_losing_the_site_stops_without_arrival() -> void:
	var objective: FakeObjective = _timer(8.0)
	_sound.handle_objective(objective)
	_tick_at(0.0)
	assert_true(_sound.engine_playing())
	_sound.handle_objective_failed(objective)
	assert_false(_sound.engine_playing())
	assert_false(_played.has(HoldoutCues.ARRIVED))
	assert_eq(_gains[-1], AudioMix.SILENT_DB)


func test_extraction_without_a_holdout_is_silent() -> void:
	Events.advisor_alert.emit(&"extraction_arrived")
	assert_false(_played.has(HoldoutCues.ARRIVED), "an infiltration's extraction is not a holdout")


func test_mission_started_resets() -> void:
	_sound.handle_objective(_timer(50.0))
	_tick_at(0.0)
	Events.mission_started.emit()
	assert_eq(_sound.stage(), 0)
	assert_eq(_gains[-1], AudioMix.SILENT_DB)
	assert_eq(_sound.seconds_left(0), INF, "the timer is forgotten")


func test_the_mission_router_leaves_survival_timers_alone() -> void:
	var router: MissionSoundRouter = MissionSoundRouter.new()
	var cues: Array[StringName] = []
	router.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		cues.append(ids[0])
		return ids[0]
	add_child_autofree(router)
	router.set_process(false)
	var objective: FakeObjective = _timer(50.0)
	router.handle_objective_added(objective)
	assert_false(MissionSoundRouter.is_deadline(objective), "survival is not a deadline")
	for s: float in [0.0, 45.0, 49.0]:
		router.handle_sim_ticked(int(s * SimClock.TICK_RATE))
	assert_eq(router.storm_stage(), 0, "no storm minute, no countdown of doom")
	assert_false(cues.has(MissionSoundRouter.STORM_MINUTE))
	assert_false(cues.has(MissionSoundRouter.STORM_COUNTDOWN))


func test_the_real_service_carries_the_holdout_layer() -> void:
	var holdout: HoldoutSound = Audio.get_node(^"Holdout") as HoldoutSound
	assert_not_null(holdout)
	Events.mission_started.emit()
	var objective: FakeObjective = _timer(90.0)
	holdout.handle_objective(objective)
	holdout.handle_sim_ticked(0)
	assert_gt(Audio.music().layer_gain_db(&"holdout"), AudioMix.SILENT_DB)
	Events.mission_started.emit()
	assert_eq(Audio.music().layer_gain_db(&"holdout"), AudioMix.SILENT_DB)
