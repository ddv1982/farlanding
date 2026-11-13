extends GutTest
## Phase 8a, Thalassa's tide: TideCues (water crossfade, rush and pull, the
## score's tide layer, arrival) and the TideSound node driven with stubs.
## Time is advanced by hand; the tide is reported the way gameplay will, a
## few times a second.

const EVENTS_DIR: String = "res://data/sounds"
## Reports per second, as gameplay emits tide_changed.
const REPORTS_PER_SECOND: int = 4

var _tide: TideSound
var _played: Array[StringName] = []
var _music_gains: Array[float] = []
var _ambience_levels: Array[float] = []


func before_each() -> void:
	_played.clear()
	_music_gains.clear()
	_ambience_levels.clear()
	_tide = TideSound.new()
	_tide.resolve_event = func(id: StringName) -> SoundEvent:
		var path: String = "%s/weather/%s.tres" % [EVENTS_DIR, id]
		return load(path) as SoundEvent if ResourceLoader.exists(path) else null
	_tide.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		_played.append(ids[0])
		return ids[0]
	_tide.set_music_gain = func(db: float) -> void: _music_gains.append(db)
	_tide.set_ambience_tide = func(level: float) -> void: _ambience_levels.append(level)
	add_child_autofree(_tide)
	_tide.set_process(false)
	_tide.seed_rng(8)


func after_each() -> void:
	_tide.handle_mission_started()


## Moves the reported tide from `from` to `to` over `seconds`, reporting
## REPORTS_PER_SECOND times a second and advancing the sound in between.
func _sweep(from: float, to: float, seconds: float) -> void:
	var steps: int = int(seconds * REPORTS_PER_SECOND)
	for i: int in steps:
		_tide.handle_tide_changed(lerpf(from, to, float(i + 1) / steps))
		_tide.advance(1.0 / REPORTS_PER_SECOND)


## Holds the tide at `level` for `seconds` (reports keep coming, unchanged).
func _hold(level: float, seconds: float) -> void:
	_sweep(level, level, seconds)


# --- Pure mapping ---------------------------------------------------------------


func test_the_water_bed_darkens_and_quietens_toward_low_water() -> void:
	assert_almost_eq(TideCues.water_db(TideCues.LOW, 0.0), TideCues.WATER_DB.x, 0.01)
	assert_eq(TideCues.water_db(TideCues.HIGH, 0.0), AudioMix.SILENT_DB, "no bright water at low")
	assert_eq(TideCues.water_db(TideCues.LOW, 1.0), AudioMix.SILENT_DB, "no dark water at high")
	assert_almost_eq(TideCues.water_db(TideCues.HIGH, 1.0), TideCues.WATER_DB.y, 0.01)
	var last_total: float = 0.0
	for step: int in 11:
		var v: float = step / 10.0
		var total: float = 0.0
		for layer: StringName in [TideCues.LOW, TideCues.HIGH]:
			total += db_to_linear(TideCues.water_db(layer, v)) ** 2
		assert_true(total >= last_total * 0.999, "the bed only grows as the water rises")
		last_total = total


func test_rush_only_while_rising_and_pull_only_while_falling() -> void:
	var full: float = TideCues.MOTION_FULL
	assert_eq(TideCues.motion_db(TideCues.RUSH, 0.0), AudioMix.SILENT_DB, "slack water is still")
	assert_eq(TideCues.motion_db(TideCues.PULL, 0.0), AudioMix.SILENT_DB)
	assert_almost_eq(TideCues.motion_db(TideCues.RUSH, full), TideCues.MOTION_TOP_DB, 0.01)
	assert_eq(TideCues.motion_db(TideCues.PULL, full), AudioMix.SILENT_DB)
	assert_almost_eq(TideCues.motion_db(TideCues.PULL, -full), TideCues.MOTION_TOP_DB, 0.01)
	assert_eq(TideCues.motion_db(TideCues.RUSH, -full), AudioMix.SILENT_DB)


func test_the_score_layer_comes_in_as_the_water_rises() -> void:
	assert_eq(TideCues.music_gain_db(0.0), AudioMix.SILENT_DB)
	assert_eq(TideCues.music_gain_db(0.1), AudioMix.SILENT_DB)
	var last: float = AudioMix.SILENT_DB
	for step: int in range(2, 11):
		var db: float = TideCues.music_gain_db(step / 10.0)
		assert_true(db >= last, "never falls as the water rises")
		last = db
	assert_almost_eq(TideCues.music_gain_db(1.0), TideCues.MUSIC_TOP_DB, 0.01)


func test_the_two_warnings_differ() -> void:
	assert_eq(TideCues.turn_cue(true), TideCues.TURN_RISING)
	assert_eq(TideCues.turn_cue(false), TideCues.TURN_FALLING)
	assert_ne(TideCues.TURN_RISING, TideCues.TURN_FALLING)


# --- The node ---------------------------------------------------------------------


func test_tide_turning_plays_its_warning() -> void:
	Events.tide_turning.emit(30.0, true)
	Events.tide_turning.emit(30.0, false)
	assert_eq(_played, [TideCues.TURN_RISING, TideCues.TURN_FALLING] as Array[StringName])


func test_silent_until_the_tide_is_reported() -> void:
	for i: int in 50:
		_tide.advance(0.1)
	for layer: StringName in TideCues.LAYERS:
		assert_false(_tide.layer_playing(layer), "%s silent on a planet without a tide" % layer)
	assert_false(_music_gains.any(func(db: float) -> bool: return db > AudioMix.SILENT_DB))


func test_a_rising_tide_rushes_and_raises_the_score_layer() -> void:
	_hold(0.0, 4.0)
	assert_true(_tide.layer_playing(TideCues.LOW), "low water is heard")
	assert_false(_tide.layer_playing(TideCues.RUSH), "slack water: no rush yet")
	_sweep(0.0, 0.6, 40.0)  # 0.015 per second
	assert_true(_tide.layer_playing(TideCues.RUSH), "the rush while it climbs")
	assert_false(_tide.layer_playing(TideCues.PULL), "no pull while it climbs")
	assert_gt(_tide.layer_volume_db(TideCues.HIGH), _tide.layer_volume_db(TideCues.LOW))
	assert_gt(_music_gains[-1], AudioMix.SILENT_DB, "the score's tide layer is in")
	assert_almost_eq(_ambience_levels[-1], 0.6, 0.02, "the ambience knows the water level")
	_hold(0.6, 8.0)
	assert_false(_tide.layer_playing(TideCues.RUSH), "high slack water is still")


func test_a_falling_tide_pulls() -> void:
	_hold(0.9, 4.0)
	_sweep(0.9, 0.3, 40.0)
	assert_true(_tide.layer_playing(TideCues.PULL), "the pull while it drains")
	assert_false(_tide.layer_playing(TideCues.RUSH))
	assert_lt(_music_gains[-1], TideCues.music_gain_db(0.9), "the score's layer recedes")


func test_a_restored_mission_picks_up_mid_level_without_a_jump() -> void:
	_hold(0.2, 2.0)
	Events.mission_started.emit()  # a loaded save starts a mission ...
	assert_false(_tide.layer_playing(TideCues.LOW), "mission_started stops the tide")
	_tide.handle_tide_changed(0.75)  # ... and re-emits the sea's level
	assert_almost_eq(_tide.level(), 0.75, 0.0001, "the level is taken at once")
	var last: float = AudioMix.SILENT_DB
	for i: int in int(TideCues.ARRIVE * 10.0) + 5:
		_tide.handle_tide_changed(0.75)
		_tide.advance(0.1)
		var now: float = _tide.layer_volume_db(TideCues.HIGH)
		assert_true(now >= last - 0.001, "the bed fades in, never jumps down")
		if last > -40.0:
			assert_lt(now - last, 7.0, "and only fades up")
		last = now
		assert_false(_tide.layer_playing(TideCues.RUSH), "no false rush from 0 to 0.75")
	assert_almost_eq(last, TideCues.water_db(TideCues.HIGH, 0.75), 0.1, "settled at the level")


func test_reports_never_start_a_second_bed() -> void:
	_sweep(0.0, 0.5, 20.0)
	var playing: int = 0
	for child: Node in _tide.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.playing:
			playing += 1
	assert_eq(_tide.get_child_count(), TideCues.LAYERS.size(), "one player per layer, ever")
	assert_lte(playing, TideCues.LAYERS.size())


func test_mission_started_resets_everything() -> void:
	_sweep(0.0, 0.8, 30.0)
	_tide.handle_mission_started()
	assert_eq(_tide.level(), 0.0)
	assert_eq(_music_gains[-1], AudioMix.SILENT_DB, "the score's tide layer goes")
	for layer: StringName in TideCues.LAYERS:
		assert_false(_tide.layer_playing(layer))
