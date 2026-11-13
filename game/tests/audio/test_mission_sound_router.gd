extends GutTest
## MissionSoundRouter: objective phrases (and their merge with gameplay's
## Advisor alerts), briefing and debrief beds, the launch phrase, the storm
## cues, and the reset on mission start.


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


# --- Objectives ---------------------------------------------------------------


func test_every_objective_phrase_exists() -> void:
	for kind: StringName in [
		&"objective_new",
		&"objective_hidden",
		&"objective_done",
		&"objective_done_secondary",
		&"objective_failed",
		&"objective_time_low",
		&"storm_warning",
		&"detected",
	]:
		assert_true(_exists(StringName("advisor_%s" % kind)), String(kind))


func test_added_objectives_speak_new_or_hidden() -> void:
	_router.handle_objective_added(_objective(&"a"))
	assert_eq(_router.flush_objectives(), &"objective_new")
	_router.handle_objective_added(_objective(&"b", &"secondary"))
	assert_eq(_router.flush_objectives(), &"objective_new")
	_router.handle_objective_added(_objective(&"c", &"hidden"))
	assert_eq(_router.flush_objectives(), &"objective_hidden")


func test_completion_differs_for_primary_and_secondary() -> void:
	_router.handle_objective_completed(_objective(&"a"))
	assert_eq(_router.flush_objectives(), &"objective_done")
	_router.handle_objective_completed(_objective(&"b", &"secondary"))
	assert_eq(_router.flush_objectives(), &"objective_done_secondary")
	_router.handle_objective_completed(_objective(&"c", &"hidden"))
	assert_eq(_router.flush_objectives(), &"objective_done_secondary")


func test_failure() -> void:
	_router.handle_objective_failed(_objective(&"a", &"secondary"))
	assert_eq(_router.flush_objectives(), &"objective_failed")


func test_one_phrase_per_frame_the_most_important() -> void:
	_router.handle_objective_added(_objective(&"a"))
	_router.handle_objective_added(_objective(&"b", &"secondary"))
	_router.handle_objective_completed(_objective(&"c", &"secondary"))
	_router.handle_objective_completed(_objective(&"d"))
	assert_eq(_router.flush_objectives(), &"objective_done")
	assert_eq(_offered, [&"objective_done"] as Array[StringName])
	assert_eq(_router.flush_objectives(), &"", "nothing left")


func test_signals_reach_it_through_the_events_bus() -> void:
	Events.objective_added.emit(_objective(&"bus"))
	assert_eq(_router.flush_objectives(), &"objective_new")


func test_gameplay_alerts_join_the_frame() -> void:
	_router.handle_advisor_alert(&"objective_new", 1.0)
	_router.handle_objective_added(_objective(&"h", &"hidden"))
	assert_eq(_router.flush_objectives(), &"objective_hidden", "the specific phrase wins")


func test_the_event_router_leaves_objective_alerts_to_this_router() -> void:
	var router: AudioEventRouter = AudioEventRouter.new()
	var heard: Array[StringName] = []
	router.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		heard.append(ids[0])
		return ids[0]
	add_child_autofree(router)
	router.set_process(false)
	Events.advisor_alert.emit(&"objective_new")
	Events.advisor_alert.emit(&"objective_done")
	assert_eq(heard.size(), 0)
	Events.advisor_alert.emit(&"detected")
	assert_eq(heard, [&"advisor_detected"] as Array[StringName])


func test_family_throttle_merges_signal_and_alert() -> void:
	var queue: AdvisorQueue = AdvisorQueue.new()
	assert_true(queue.push(&"objective_done", 1.0))
	assert_false(queue.push(&"objective_done_secondary", 1.5), "same family, same moment")
	assert_true(queue.push(&"objective_new", 1.5), "another family")
	assert_false(queue.push(&"objective_hidden", 2.0))
	assert_true(
		queue.push(&"objective_done_secondary", 1.0 + AdvisorQueue.throttle_of(&"objective_done"))
	)
	assert_gt(
		AdvisorQueue.priority_of(&"objective_failed"), AdvisorQueue.priority_of(&"objective_done")
	)
	assert_gt(
		AdvisorQueue.priority_of(&"objective_done"), AdvisorQueue.priority_of(&"objective_new")
	)


func test_progress_ticks_only_for_known_objectives() -> void:
	_router.handle_objective_updated(_objective(&"secret", &"hidden"))
	assert_eq(_played.size(), 0, "an unrevealed hidden objective stays secret")
	_router.handle_objective_added(_objective(&"secret", &"hidden"))
	_router.handle_objective_updated(_objective(&"secret", &"hidden"))
	assert_eq(_played, [&"ui_objective_tick"] as Array[StringName])
	_router.handle_objective_updated(_objective(&"plain"))
	assert_eq(_played.size(), 2, "primary and secondary updates always tick")


# --- Reset ----------------------------------------------------------------------


func test_mission_start_resets_mission_state() -> void:
	var survey: FakeObjective = _objective(&"bank_intel")
	survey.countdown_tick = 100
	_router.handle_objective_added(survey)
	_router.handle_sim_ticked(95)
	assert_eq(_router.storm_stage(), 2)
	_router.handle_objective_completed(_objective(&"x"))
	_storm_gain.clear()
	Events.mission_started.emit()
	assert_eq(_router.storm_stage(), 0)
	assert_eq(_storm_gain, [AudioMix.SILENT_DB] as Array[float], "storm layer silenced")
	assert_eq(_router.flush_objectives(), &"", "pending phrases dropped")
	assert_eq(_router.handle_sim_ticked(96), &"", "deadlines forgotten")
	_router.handle_objective_updated(_objective(&"bank_intel", &"hidden"))
	assert_false(&"ui_objective_tick" in _played, "known objectives forgotten")
