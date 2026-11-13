extends GutTest
## Phase 6 dust storm: StormCues (layer mapping, muffle, release, the final
## storm) and the StormSound node driven with stubs.

const EVENTS_DIR: String = "res://data/sounds"

var _storm: StormSound
var _played: Array[StringName] = []
var _debris: Array[Vector3] = []
var _muffles: Array[float] = []
var _music_gains: Array[float] = []
var _covers: Array[float] = []


func before_each() -> void:
	_played.clear()
	_debris.clear()
	_muffles.clear()
	_music_gains.clear()
	_covers.clear()
	_storm = StormSound.new()
	_storm.resolve_event = func(id: StringName) -> SoundEvent:
		for group: String in ["weather", "sting"]:
			var path: String = "%s/%s/%s.tres" % [EVENTS_DIR, group, id]
			if ResourceLoader.exists(path):
				return load(path) as SoundEvent
		return null
	_storm.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		_played.append(ids[0])
		return ids[0]
	_storm.play_at = func(id: StringName, at: Vector3, _db: float) -> bool:
		if id == StormCues.DEBRIS:
			_debris.append(at)
		return true
	_storm.set_muffle = func(amount: float) -> void: _muffles.append(amount)
	_storm.set_music_gain = func(db: float) -> void: _music_gains.append(db)
	_storm.set_ambience_cover = func(amount: float) -> void: _covers.append(amount)
	add_child_autofree(_storm)
	_storm.set_process(false)


func after_each() -> void:
	_storm.handle_mission_started()


## Reports `value` and lets the heard intensity catch up.
func _settle(value: float) -> void:
	_storm.handle_storm_changed(value)
	for i: int in 40:
		_storm.advance(0.1)


# --- Pure mapping ---------------------------------------------------------------


func test_layers_enter_one_after_another_and_grow_with_intensity() -> void:
	for layer: StringName in StormCues.LAYERS:
		assert_eq(
			StormCues.layer_db(layer, 0.0), AudioMix.SILENT_DB, "%s silent in clear air" % layer
		)
		assert_almost_eq(StormCues.layer_db(layer, 1.0), 0.0, 0.01, "%s full at 1" % layer)
		var last: float = AudioMix.SILENT_DB
		for step: int in 11:
			var db: float = StormCues.layer_db(layer, step / 10.0)
			assert_true(db >= last, "%s never falls as the storm grows" % layer)
			last = db
	# The wind comes first, then the grit, then the throb.
	assert_gt(StormCues.layer_db(StormCues.WIND, 0.3), StormCues.layer_db(StormCues.GRIT, 0.3))
	assert_eq(StormCues.layer_db(StormCues.THROB, 0.45), AudioMix.SILENT_DB)
	assert_gt(StormCues.layer_db(StormCues.THROB, 0.8), AudioMix.SILENT_DB)


func test_muffle_only_at_strength_and_closes_the_filter() -> void:
	assert_eq(StormCues.muffle_amount(0.4), 0.0)
	assert_almost_eq(StormCues.muffle_amount(1.0), 1.0, 0.001)
	assert_almost_eq(StormCues.muffle_cutoff_hz(0.0), StormCues.MUFFLE_OPEN_HZ, 1.0)
	assert_almost_eq(StormCues.muffle_cutoff_hz(1.0), StormCues.MUFFLE_CLOSED_HZ, 1.0)
	assert_lt(StormCues.muffle_db(&"SFX", 1.0), 0.0)
	assert_lt(StormCues.muffle_db(&"Ambience", 1.0), StormCues.muffle_db(&"SFX", 1.0))
	for bus: StringName in [
		&"Barks", &"Advisor", &"UI", &"Voice", &"Stealth", &"Weather", &"Music"
	]:
		assert_eq(StormCues.muffle_db(bus, 1.0), 0.0, "%s stays clear" % bus)


func test_music_storm_layer_and_one_shot_gaps() -> void:
	assert_eq(StormCues.music_gain_db(0.05), AudioMix.SILENT_DB)
	assert_almost_eq(StormCues.music_gain_db(1.0), StormCues.MUSIC_TOP_DB, 0.001)
	assert_eq(StormCues.gust_gap(0.1, 0.5), INF, "no gusts in a breeze")
	assert_lt(StormCues.gust_gap(1.0, 0.5), StormCues.gust_gap(0.4, 0.5), "more gusts as it grows")
	assert_eq(StormCues.debris_gap(0.3, 0.5), INF)
	assert_lt(StormCues.debris_gap(1.0, 0.99), 3.0)


func test_ending_stings() -> void:
	assert_eq(StormCues.ending_stings(true, 1.0, true)[0], StormCues.STING_VICTORY)
	assert_eq(StormCues.ending_stings(false, 0.9, true)[0], StormCues.STING_FINAL)
	assert_eq(StormCues.ending_stings(false, 0.0, true)[0], StormCues.STING_OUTSURVEYED)
	assert_eq(
		StormCues.ending_stings(false, 0.2, false), [StormCues.STING_DEFEAT] as Array[StringName]
	)
	for id: StringName in [StormCues.STING_FINAL, StormCues.STING_OUTSURVEYED]:
		assert_true(ResourceLoader.exists("%s/sting/%s.tres" % [EVENTS_DIR, id]), String(id))


func test_cues_pass_only_after_a_real_storm() -> void:
	var cues: StormCues = StormCues.new()
	cues.report(0.3)
	for i: int in 20:
		cues.step(0.1)
	cues.report(0.0)
	var passed: int = 0
	for i: int in 30:
		if cues.step(0.1) == StormCues.PASSED:
			passed += 1
	assert_eq(passed, 0, "a gust front that never became a storm does not 'pass'")
	cues.report(1.0)
	for i: int in 30:
		cues.step(0.1)
	cues.report(0.0)
	for i: int in 30:
		if cues.step(0.1) == StormCues.PASSED:
			passed += 1
	assert_eq(passed, 1)


func test_frozen_storm_never_lifts() -> void:
	var cues: StormCues = StormCues.new()
	cues.report(0.7)
	for i: int in 20:
		cues.step(0.1)
	cues.freeze()
	cues.report(0.0)
	for i: int in 30:
		assert_ne(cues.step(0.1), StormCues.PASSED)
	assert_almost_eq(cues.intensity, 0.7, 0.001)
	assert_true(cues.is_final())
	cues.report(1.0)
	cues.step(1.0)
	assert_gt(cues.intensity, 0.7, "it may still build")
	cues.reset()
	assert_false(cues.is_final())
	assert_eq(cues.intensity, 0.0)


# --- The node -----------------------------------------------------------------


func test_incoming_plays_the_distant_front() -> void:
	_storm.handle_storm_incoming(30.0)
	assert_eq(_played, [StormCues.FRONT_RUMBLE] as Array[StringName])


func test_layers_follow_intensity_smoothly() -> void:
	_storm.handle_storm_changed(1.0)
	_storm.advance(0.1)
	assert_lt(_storm.intensity(), 0.2, "a jump in the report is followed, not copied")
	_settle(1.0)
	assert_almost_eq(_storm.intensity(), 1.0, 0.001)
	for layer: StringName in StormCues.LAYERS:
		assert_true(_storm.layer_playing(layer), "%s loops" % layer)
		assert_almost_eq(_storm.layer_volume_db(layer), 0.0, 0.05)
	assert_almost_eq(_muffles[-1], 1.0, 0.001)
	assert_almost_eq(_music_gains[-1], StormCues.MUSIC_TOP_DB, 0.001)
	assert_almost_eq(_covers[-1], 1.0, 0.001)
	_settle(0.35)
	assert_true(_storm.layer_playing(StormCues.WIND))
	assert_false(_storm.layer_playing(StormCues.THROB), "the throb stops below its range")
	assert_eq(_muffles[-1], 0.0, "the muffle lifts as the storm weakens")


func test_gusts_and_debris_in_a_storm_only() -> void:
	_settle(0.1)
	for i: int in 300:
		_storm.advance(0.1)
	assert_false(_played.has(StormCues.GUST))
	assert_true(_debris.is_empty())
	_settle(1.0)
	for i: int in 300:
		_storm.advance(0.1)
	assert_true(_played.has(StormCues.GUST))
	assert_false(_debris.is_empty())
	for at: Vector3 in _debris:
		var d: float = Vector2(at.x, at.z).length()
		assert_between(d, StormDistance.NEAR, StormDistance.FAR, "debris lands around the listener")


func test_storm_passed_release() -> void:
	_settle(1.0)
	_played.clear()
	_settle(0.0)
	assert_eq(_played.count(StormCues.PASSED), 1)
	assert_eq(_muffles[-1], 0.0, "the world is clear again")
	assert_eq(_music_gains[-1], AudioMix.SILENT_DB)
	for layer: StringName in StormCues.LAYERS:
		assert_false(_storm.layer_playing(layer))


func test_final_storm_stays_after_the_mission_ends() -> void:
	_settle(1.0)
	_storm.handle_mission_ended(false)
	assert_true(_storm.is_final())
	_played.clear()
	_settle(0.0)
	assert_false(_played.has(StormCues.PASSED), "the Survey storm does not lift")
	assert_almost_eq(_storm.intensity(), 1.0, 0.001)
	assert_almost_eq(_muffles[-1], 1.0, 0.001)


func test_mission_started_resets_everything() -> void:
	_settle(1.0)
	_storm.handle_mission_ended(false)
	_storm.handle_mission_started()
	assert_eq(_storm.intensity(), 0.0)
	assert_false(_storm.is_final())
	assert_eq(_muffles[-1], 0.0)
	assert_eq(_music_gains[-1], AudioMix.SILENT_DB)
	for layer: StringName in StormCues.LAYERS:
		assert_false(_storm.layer_playing(layer))
	_settle(0.6)
	assert_gt(_storm.intensity(), 0.5, "a new mission's storm is heard again")


class StormDistance:
	const NEAR: float = 11.9
	const FAR: float = 38.1
