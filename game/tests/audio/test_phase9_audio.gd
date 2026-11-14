extends GutTest
## Phase 9 (polish): the Advisor's subtitles, the Advisor and ambience volume
## settings, the engine-claim tick (MachineClaimSound), the awakening as the one
## moment the Advisor does not duck the music, and the settings-page sounds.

const ADVISOR_DIR: String = "res://data/sounds/advisor"
const SETTINGS_UI_EVENTS: Array[StringName] = [
	&"ui_tab_changed",
	&"ui_rebind_listen",
	&"ui_rebind_done",
	&"ui_rebind_conflict",
	&"ui_credits_open",
]


## A machine component double: only the signal the sim's Machine has.
class FakeMachine:
	extends Node
	signal progress_changed(progress: float, claimant: int)


## A building carrying a machine, as the sim's Building does.
class FakeEngine:
	extends Node3D
	var machine: FakeMachine


var _speakers: Array[StringName] = []
var _texts: Array[String] = []
var _lengths: Array[float] = []


func before_each() -> void:
	_speakers.clear()
	_texts.clear()
	_lengths.clear()
	Events.subtitle.connect(_on_subtitle)


func after_each() -> void:
	Events.subtitle.disconnect(_on_subtitle)


func _on_subtitle(speaker: StringName, text: String, seconds: float) -> void:
	_speakers.append(speaker)
	_texts.append(text)
	_lengths.append(seconds)


# --- Subtitles ---------------------------------------------------------------------


func _advisor_events() -> Array[SoundEvent]:
	var events: Array[SoundEvent] = []
	for entry: String in ResourceLoader.list_directory(ADVISOR_DIR):
		if entry.ends_with(".tres"):
			var event: SoundEvent = load(ADVISOR_DIR.path_join(entry)) as SoundEvent
			if event != null:
				events.append(event)
	return events


func test_every_advisor_line_has_a_subtitle() -> void:
	var events: Array[SoundEvent] = _advisor_events()
	assert_gt(events.size(), 40, "the Advisor's lines were found")
	for event: SoundEvent in events:
		assert_eq(event.bus, &"Advisor", "%s is on the Advisor bus" % event.id)
		assert_false(event.subtitle.strip_edges().is_empty(), "%s has a subtitle" % event.id)
		assert_lte(event.subtitle.length(), 64, "%s: a subtitle is one short line" % event.id)


func test_every_sound_on_the_advisor_bus_is_an_advisor_line() -> void:
	# Anything else the Advisor says would go unsubtitled.
	var ids: Array[StringName] = []
	for event: SoundEvent in _advisor_events():
		ids.append(event.id)
	for kind: StringName in AdvisorQueue.PRIORITY:
		var id: StringName = StringName("advisor_%s" % kind)
		assert_true(Audio.has_event(id), "alert kind %s has its own line (%s)" % [kind, id])
		assert_true(ids.has(id), "%s lives with the Advisor's lines" % id)


func _router(seconds: float, heard: bool) -> AudioEventRouter:
	var router: AudioEventRouter = AudioEventRouter.new()
	router.play_line = func(ids: Array[StringName]) -> StringName: return ids[0] if heard else &""
	router.event_seconds = func(_id: StringName) -> float: return seconds
	router.subtitle_of = func(id: StringName) -> String:
		var event: SoundEvent = Audio.get_event(id)
		return event.subtitle if event != null else ""
	autofree(router)
	return router


func test_a_line_is_subtitled_when_it_starts_with_its_length() -> void:
	var router: AudioEventRouter = _router(1.25, true)
	assert_true(router.offer_advisor_alert(&"engine_online", 100.0))
	assert_eq(_texts.size(), 1, "one subtitle")
	assert_eq(_speakers[0], &"advisor")
	assert_eq(_texts[0], "Engine online.")
	assert_almost_eq(_lengths[0], 1.25, 0.001, "the line's real length")


func test_a_waiting_line_is_subtitled_only_when_it_plays() -> void:
	var router: AudioEventRouter = _router(1.0, true)
	router.offer_advisor_alert(&"construction_complete", 100.0)
	router.offer_advisor_alert(&"unit_ready", 100.2)  # waits behind the first
	assert_eq(_texts.size(), 1, "queued, not yet heard")
	router.pump_advisor(101.0)
	assert_eq(_texts.size(), 1, "still sounding (plus the gap)")
	router.pump_advisor(101.5)
	assert_eq(_texts.size(), 2)
	assert_eq(_texts[1], "Unit ready.")


func test_dropped_superseded_and_throttled_lines_are_never_subtitled() -> void:
	var router: AudioEventRouter = _router(1.0, true)
	router.offer_advisor_alert(&"construction_complete", 100.0)
	router.offer_advisor_alert(&"low_power", 100.1)
	router.offer_advisor_alert(&"power_restored", 100.2)  # cancels the unheard warning
	router.offer_advisor_alert(&"construction_complete", 100.3)  # throttled
	router.offer_advisor_alert(&"deposit_depleted", 100.4)
	router.pump_advisor(106.0)  # the depleted alert waited too long: dropped
	assert_eq(_texts.size(), 1, "only the line that was heard")
	assert_eq(_texts[0], "Construction complete.")


func test_a_line_refused_a_voice_is_not_subtitled() -> void:
	var router: AudioEventRouter = _router(1.0, false)
	router.offer_advisor_alert(&"engine_online", 100.0)
	assert_eq(_texts.size(), 0)


func test_the_real_service_subtitles_what_it_plays() -> void:
	var router: AudioEventRouter = Audio.get_node(^"EventRouter") as AudioEventRouter
	var now: float = Time.get_ticks_msec() / 1000.0 + 1000.0  # clear of earlier tests
	router.offer_advisor_alert(&"core_charging", now)
	assert_eq(_texts.size(), 1)
	assert_eq(_texts[0], "The Core is charging.")
	var seconds: float = Audio.get_event(&"advisor_core_charging").longest_seconds()
	assert_almost_eq(_lengths[0], seconds, 0.001)
	Audio.stop_all_voices()


# --- Volume settings -----------------------------------------------------------------


func test_the_advisor_and_the_ambience_have_their_own_settings() -> void:
	assert_eq(AudioMix.SETTING_FOR_BUS[&"Advisor"], &"voice_volume")
	assert_eq(AudioMix.SETTING_FOR_BUS[&"Ambience"], &"ambience_volume")
	assert_eq(AudioMix.SETTING_FOR_BUS[&"Barks"], &"sfx_volume", "unit replies stay effects")
	assert_false(AudioMix.SETTING_FOR_BUS.has(&"Voice"), "the Advisor is not scaled twice")
	for bus: StringName in [&"Advisor", &"Ambience", &"Barks"]:
		assert_ne(AudioServer.get_bus_index(bus), -1, "bus %s" % bus)
	assert_eq(
		AudioServer.get_bus_send(AudioServer.get_bus_index(&"Advisor")), &"Voice", "sidechain"
	)


# --- The engine claim --------------------------------------------------------------


func _claims() -> MachineClaimSound:
	var claims: MachineClaimSound = MachineClaimSound.new()
	claims.resolve_event = Audio.get_event
	add_child_autofree(claims)
	claims.set_process(false)
	return claims


func _engine(at: Vector3) -> FakeEngine:
	var engine: FakeEngine = FakeEngine.new()
	engine.machine = FakeMachine.new()
	engine.add_child(engine.machine)
	engine.add_to_group(MachineClaimSound.BUILDINGS_GROUP)
	add_child_autofree(engine)
	engine.global_position = at
	return engine


func test_a_claim_ticks_rising_while_our_workers_work() -> void:
	var claims: MachineClaimSound = _claims()
	var engine: FakeEngine = _engine(Vector3(10.0, 0.0, 0.0))
	claims.scan()
	claims.scan()  # listening once only
	assert_eq(engine.machine.progress_changed.get_connections().size(), 1)
	engine.machine.progress_changed.emit(0.2, 0)
	claims.advance(0.1)
	assert_eq(claims.active_count(), 1, "the claim is heard")
	var low: float = claims.pitch_of(engine)
	engine.machine.progress_changed.emit(0.8, 0)
	claims.advance(0.1)
	assert_gt(claims.pitch_of(engine), low, "it rises with the work")
	assert_almost_eq(claims.pitch_of(engine), MachineClaimSound.pitch_for(0.8), 0.001)
	for k: int in 10:  # the workers left: the sim reports the progress decaying
		engine.machine.progress_changed.emit(0.8 - 0.02 * (k + 1), 0)
		claims.advance(0.1)
	assert_eq(claims.active_count(), 0, "it fades out")


func test_no_claim_for_the_enemy_far_away_or_finished() -> void:
	var claims: MachineClaimSound = _claims()
	var near: FakeEngine = _engine(Vector3(5.0, 0.0, 0.0))
	var far: FakeEngine = _engine(Vector3(MachineClaimSound.RANGE + 20.0, 0.0, 0.0))
	claims.scan()
	near.machine.progress_changed.emit(0.4, 1)
	far.machine.progress_changed.emit(0.4, 0)
	claims.advance(0.1)
	assert_eq(claims.active_count(), 0, "enemy work and far work are not heard")
	near.machine.progress_changed.emit(1.0, 0)
	claims.advance(0.1)
	assert_eq(claims.active_count(), 0, "done: the spin-up speaks")
	near.machine.progress_changed.emit(0.5, 0)
	claims.advance(0.1)
	claims.handle_mission_started()
	assert_eq(claims.active_count(), 0, "a new mission resets it")


# --- The finale --------------------------------------------------------------------


func test_the_awakening_is_the_one_moment_the_music_is_not_ducked() -> void:
	var core: CoreSound = CoreSound.new()
	core.resolve_event = Audio.get_event
	add_child_autofree(core)
	assert_true(CoreSound.music_ducks(), "the Advisor ducks the music")
	assert_true(core.handle_awakened(null, 30.0))
	assert_false(CoreSound.music_ducks(), "not under the awakening")
	core.handle_mission_started()
	assert_true(CoreSound.music_ducks(), "back after it")


func test_the_duck_returns_when_the_awakening_ends() -> void:
	var core: CoreSound = CoreSound.new()
	core.resolve_event = Audio.get_event
	add_child_autofree(core)
	var length: float = Audio.get_event(CoreCues.AWAKENED).longest_seconds()
	core.handle_awakened(null, length - 0.3)
	assert_false(CoreSound.music_ducks())
	await wait_until(func() -> bool: return not core.is_peaking(), 3.0)
	assert_true(CoreSound.music_ducks(), "the cue ended: the duck is back")


# --- Settings-page sounds ------------------------------------------------------------


func test_settings_page_sounds_exist_by_the_naming_rule() -> void:
	for kind: StringName in [
		&"tab_changed", &"rebind_listen", &"rebind_done", &"rebind_conflict", &"credits_open"
	]:
		var candidates: Array[StringName] = AudioCueSelector.feedback_event(kind)
		assert_eq(candidates[0], StringName("ui_%s" % kind))
		assert_true(Audio.has_event(candidates[0]), "%s plays %s" % [kind, candidates[0]])
	for id: StringName in SETTINGS_UI_EVENTS:
		var event: SoundEvent = Audio.get_event(id)
		assert_eq(event.bus, &"UI", "%s on the UI bus" % id)


func test_the_credits_screen_plays_the_ending_theme() -> void:
	var music: ScreenMusic = ScreenMusic.find(&"credits")
	assert_not_null(music)
	assert_eq(music.score.id, &"ending")
