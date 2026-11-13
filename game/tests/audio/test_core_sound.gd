extends GutTest
## Phase 8d, Hollow Meridian: the Beacon Core's finale (CoreSound and its pure
## rules, CoreCues). The router's outputs are captured through its callables;
## the awakening's stream comes from the real SoundEvent. Signals are emitted by
## hand: gameplay does not need to exist for any of this.

var _sound: CoreSound
## Layer -> the gain sent last.
var _gains: Dictionary[StringName, float] = {}
var _sends: int = 0
var _dips: Array[Vector2] = []


func before_each() -> void:
	_gains.clear()
	_sends = 0
	_dips.clear()
	_sound = CoreSound.new()
	_sound.resolve_event = Audio.get_event
	_sound.set_music_gain = func(layer: StringName, gain_db: float) -> void:
		_gains[layer] = gain_db
		_sends += 1
	_sound.dip_music = func(seconds: float, dip_db: float) -> void:
		_dips.append(Vector2(seconds, dip_db))
	add_child_autofree(_sound)


func after_each() -> void:
	_sound.handle_mission_started()


func _sounding() -> int:
	var count: int = 0
	for layer: StringName in CoreCues.LAYERS:
		if _gains.get(layer, AudioMix.SILENT_DB) > AudioMix.SILENT_DB:
			count += 1
	return count


# --- Pure rules -------------------------------------------------------------------


func test_layers_come_in_by_threshold() -> void:
	assert_eq(CoreCues.level_for(0.0, 0), 0)
	assert_eq(CoreCues.level_for(0.24, 0), 0)
	assert_eq(CoreCues.level_for(0.25, 0), 1)
	assert_eq(CoreCues.level_for(0.6, 0), 2, "a jump brings two layers at once")
	assert_eq(CoreCues.level_for(1.0, 0), 3)
	assert_eq(CoreCues.level_for(0.1, 3), 0, "a collapse takes them all")


func test_hysteresis_keeps_a_layer_until_well_below() -> void:
	assert_eq(CoreCues.level_for(0.48, 2), 2, "just under the threshold: stays")
	assert_eq(CoreCues.level_for(0.43, 2), 2)
	assert_eq(CoreCues.level_for(0.41, 2), 1, "well under: goes")
	assert_eq(CoreCues.level_for(0.49, 1), 1, "and only comes back at the threshold")
	assert_eq(CoreCues.level_for(NAN, 2), 2, "a bad report changes nothing")


func test_gains_and_dip() -> void:
	assert_eq(CoreCues.layer_gain_db(0, 1), 0.0)
	assert_eq(CoreCues.layer_gain_db(1, 1), AudioMix.SILENT_DB)
	assert_eq(CoreCues.dip_seconds(34.0), 34.0 - CoreCues.TAIL_SECONDS)


# --- The router -------------------------------------------------------------------


func test_starts_silent() -> void:
	assert_eq(_gains.size(), CoreCues.LAYERS.size(), "every Core layer is set at start")
	assert_eq(_sounding(), 0)


func test_charge_rising_brings_the_layers_in() -> void:
	for k: int in 11:
		_sound.handle_charge_changed(k * 0.1)
	assert_eq(_sound.level(), 3)
	assert_eq(_sounding(), 3)
	assert_eq(_gains[&"core_3"], 0.0)


func test_a_wavering_charge_does_not_flap() -> void:
	_sound.handle_charge_changed(0.52)
	var sends: int = _sends
	for k: int in 40:  # a contested Core: the charge wobbles around one half
		_sound.handle_charge_changed(0.5 + 0.05 * sin(k * 1.3))
	assert_eq(_sound.level(), 2, "still two layers")
	assert_eq(_sends, sends, "no layer was touched while it wobbled")
	_sound.handle_charge_changed(0.3)
	assert_eq(_sound.level(), 1, "a real fall takes one away")


func test_awakening_plays_once_dips_the_score_and_silences_the_layers() -> void:
	_sound.handle_charge_changed(0.95)
	assert_true(_sound.handle_awakened(null))
	assert_true(_sound.is_peaking())
	assert_eq(_sounding(), 0, "the Core layers give way to the peak")
	assert_eq(_dips.size(), 1)
	var length: float = Audio.get_event(CoreCues.AWAKENED).longest_seconds()
	assert_almost_eq(_dips[0].x, length - CoreCues.TAIL_SECONDS, 0.01, "until the calm tail")
	assert_eq(_dips[0].y, CoreCues.PEAK_DIP_DB)
	assert_false(_sound.handle_awakened(null), "once")
	_sound.handle_charge_changed(0.2)
	assert_eq(_sounding(), 0, "charge reports after the awakening change nothing")


func test_the_awakening_is_the_campaigns_peak() -> void:
	var event: SoundEvent = Audio.get_event(CoreCues.AWAKENED)
	assert_not_null(event)
	assert_eq(event.bus, &"Music")
	assert_between(event.longest_seconds(), 28.0, 36.0, "20-30 s of peak and a calm tail")


func test_mission_started_resets() -> void:
	_sound.handle_charge_changed(0.8)
	_sound.handle_awakened(null)
	Events.mission_started.emit()
	assert_false(_sound.is_peaking())
	assert_false(_sound.is_awakened())
	assert_eq(_sound.level(), 0)
	_sound.handle_charge_changed(0.3)
	assert_eq(_sound.level(), 1, "a new mission charges again")


func test_signals_reach_the_router() -> void:
	Events.core_charge_changed.emit(0.55)
	assert_eq(_sound.level(), 2)
	(Audio.get_node(^"Core") as CoreSound).handle_mission_started()  # the real one heard it too
	# Not emitted here: the real Audio would play the whole peak under later tests.
	assert_true(Events.core_awakened.is_connected(_sound.handle_awakened))


# --- Through the real Audio autoload --------------------------------------------------


func _victory_sting_playing() -> bool:
	var streams: Array[AudioStream] = []
	for id: StringName in [&"mus_sting_victory", &"mus_sting_victory_hollow_meridian"]:
		var event: SoundEvent = Audio.get_event(id)
		if event != null:
			streams.append_array(event.streams)
	for child: Node in Audio.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.playing and streams.has(player.stream):
			return true
	return false


func test_no_victory_sting_over_the_awakening() -> void:
	var core: CoreSound = Audio.get_node(^"Core") as CoreSound
	var combat: CombatSoundRouter = Audio.get_node(^"CombatRouter") as CombatSoundRouter
	assert_not_null(core)
	var dip: Callable = core.dip_music
	core.dip_music = func(_seconds: float, _db: float) -> void: pass  # leave the score alone
	combat.handle_mission_started()
	assert_true(core.handle_awakened(null))
	combat.handle_mission_ended(true)
	assert_false(_victory_sting_playing(), "the awakening is the victory")
	assert_eq(Audio.music_state(), &"victory", "the score still settles")
	core.handle_mission_started()
	core.dip_music = dip
	combat.handle_mission_started()
	Audio.music().force_state(&"explore")
