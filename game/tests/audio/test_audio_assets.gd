extends GutTest
## Integration checks on the real data and assets, decoded by Godot itself.

const EVENTS_DIR: String = "res://data/sounds"
const SCORE: String = "res://data/sounds/music/kessel_reach.tres"
const LOOPS: Array[String] = [
	"res://assets/audio/movement/move_rover.wav",
	"res://assets/audio/movement/move_walker.wav",
	"res://assets/audio/movement/move_tracks.wav",
	"res://assets/audio/movement/move_hover.wav",
	"res://assets/audio/movement/move_sixwheel.wav",
	"res://assets/audio/movement/move_drone.wav",
	"res://assets/audio/movement/move_skitter.wav",
	"res://assets/audio/movement/move_stinger.wav",
	"res://assets/audio/movement/move_mauler.wav",
	"res://assets/audio/base/loops/loop_construct.wav",
	"res://assets/audio/base/loops/loop_produce.wav",
	"res://assets/audio/base/loops/loop_mine.wav",
	"res://assets/audio/base/loops/loop_hum.wav",
	"res://assets/audio/ambience/amb_kessel_wind.ogg",
	"res://assets/audio/music/kessel/mus_kessel_explore_pad.ogg",
	"res://assets/audio/music/kessel/mus_kessel_explore_pulse.ogg",
	"res://assets/audio/music/kessel/mus_kessel_explore_melody.ogg",
	"res://assets/audio/music/kessel/mus_kessel_tension_drive.ogg",
	"res://assets/audio/music/kessel/mus_kessel_combat_drums.ogg",
	"res://assets/audio/music/kessel/mus_kessel_combat_brass.ogg",
	"res://assets/audio/movement/move_warden.wav",
	"res://assets/audio/movement/move_scrapper.wav",
	"res://assets/audio/movement/move_rigger.wav",
	"res://assets/audio/base/loops/loop_hum_hub.wav",
	"res://assets/audio/base/loops/loop_hum_forge.wav",
	"res://assets/audio/base/loops/loop_hum_spire.wav",
	"res://assets/audio/base/loops/loop_hum_warden.wav",
	"res://assets/audio/base/loops/loop_hum_survey_lab.wav",
	"res://assets/audio/discovery/signal_pulse.wav",
	"res://assets/audio/discovery/scan_loop.wav",
	"res://assets/audio/music/kessel/mus_kessel_explore_trail.ogg",
	"res://assets/audio/movement/move_phantom.wav",
	"res://assets/audio/movement/move_strider.wav",
	"res://assets/audio/movement/move_crawler.wav",
	"res://assets/audio/stealth/stealth_suspicion.wav",
	"res://assets/audio/music/kessel/mus_kessel_stealth_hush.ogg",
	"res://assets/audio/music/kessel/mus_kessel_stealth_watch.ogg",
	"res://assets/audio/music/kessel/mus_kessel_storm.ogg",
	"res://assets/audio/music/beds/mus_briefing_bed.ogg",
	"res://assets/audio/music/beds/mus_debrief_bed.ogg",
]
const WEAPON_SETS: Array[String] = [
	"repeater",
	"cannon",
	"light_gun",
	"sentry",
	"skitter_gun",
	"lance",
	"siege",
	"wisp",
	"lancer",
	"arc"
]
const MIX_RATE: float = 44100.0


func _sound_events(dir_path: String, out: Array[SoundEvent]) -> void:
	for entry: String in ResourceLoader.list_directory(dir_path):
		if entry.ends_with("/"):
			_sound_events(dir_path.path_join(entry).trim_suffix("/"), out)
		elif entry.ends_with(".tres"):
			var event: SoundEvent = load(dir_path.path_join(entry)) as SoundEvent
			if event != null:
				out.append(event)


func test_every_sound_event_is_playable() -> void:
	var events: Array[SoundEvent] = []
	_sound_events(EVENTS_DIR, events)
	assert_gt(events.size(), 20)
	var ids: Dictionary[StringName, bool] = {}
	for event: SoundEvent in events:
		assert_false(ids.has(event.id), "duplicate id %s" % event.id)
		ids[event.id] = true
		assert_ne(AudioServer.get_bus_index(event.bus), -1, "%s: bus %s" % [event.id, event.bus])
		assert_false(event.streams.is_empty(), "%s has streams" % event.id)
		for stream: AudioStream in event.streams:
			assert_not_null(stream, "%s stream" % event.id)
		if event.positional:
			assert_gt(event.max_distance, 0.0, "%s max_distance" % event.id)


func test_every_unit_sound_set_has_its_replies() -> void:
	for sound_set: String in [
		"surveyor", "ranger", "bulwark", "kite", "hauler", "fabricator", "wisp", "lancer", "arc"
	]:
		for kind: String in ["select", "move", "attack"]:
			var path: String = "%s/unit/unit_%s_%s.tres" % [EVENTS_DIR, sound_set, kind]
			var event: SoundEvent = load(path) as SoundEvent
			assert_not_null(event, path)
			if event != null:
				assert_eq(event.streams.size(), 3, "%s variations" % path)
				assert_eq(event.pitch_variation, 0.0, "tonal replies stay in key")
		assert_true(ResourceLoader.exists("%s/movement/move_%s.tres" % [EVENTS_DIR, sound_set]))


func test_economy_events_exist() -> void:
	var ids: Array[String] = []
	for sound_set: String in ["lander", "reactor", "refinery", "flux_tap", "muster_bay", "foundry"]:
		ids.append("building/building_%s_select" % sound_set)
	for kind: String in [
		"low_power",
		"power_restored",
		"insufficient_resources",
		"construction_complete",
		"unit_ready",
		"deposit_depleted",
		"building_placed",
	]:
		ids.append("advisor/advisor_%s" % kind)
	for id: String in ["place", "complete", "unit_ready", "unload", "depleted"]:
		ids.append("base/base_%s" % id)
	for id: String in ["construct", "produce", "mine", "hum"]:
		ids.append("baseloop/loop_%s" % id)
	for id: String in ["build_button", "queue", "rally_set", "invalid_placement"]:
		ids.append("ui/ui_%s" % id)
	ids.append("ui/ui_not_enough_resources")
	for id: String in ids:
		var event: SoundEvent = load("%s/%s.tres" % [EVENTS_DIR, id]) as SoundEvent
		assert_not_null(event, id)
		if event != null and id.begins_with("baseloop/"):
			assert_true(event.positional, "%s is positional" % id)
			var wav: AudioStreamWAV = event.streams[0] as AudioStreamWAV
			assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % id)


func test_combat_events_exist_with_their_buses() -> void:
	var expected: Dictionary[String, StringName] = {}
	for sound_set: String in WEAPON_SETS:
		expected["weapon/weapon_%s_fire" % sound_set] = &"Weapons"
	for kind: String in ["spark", "armour", "ground"]:
		expected["impact/impact_%s" % kind] = &"Weapons"
	for size: String in ["small", "medium", "large"]:
		expected["explosion/explosion_%s" % size] = &"Explosions"
	for kind: String in ["light", "heavy", "building"]:
		expected["explosion/death_%s" % kind] = &"Explosions"
	for path: String in expected:
		var event: SoundEvent = load("%s/%s.tres" % [EVENTS_DIR, path]) as SoundEvent
		assert_not_null(event, path)
		if event == null:
			continue
		assert_eq(event.bus, expected[path], "%s bus" % path)
		assert_true(event.positional, "%s is positional" % path)
		if not path.begins_with("explosion/death_building"):
			assert_eq(event.streams.size(), 3, "%s variations" % path)
	for id: String in [
		"movement/move_skitter",
		"movement/move_stinger",
		"movement/move_mauler",
		"building/building_sentry_select",
		"base/base_turret_traverse",
		"advisor/advisor_under_attack",
		"sting/mus_sting_victory",
		"sting/mus_sting_defeat",
	]:
		assert_true(ResourceLoader.exists("%s/%s.tres" % [EVENTS_DIR, id]), id)


func test_heavier_weapons_outrank_light_ones() -> void:
	var light: SoundEvent = load(EVENTS_DIR + "/weapon/weapon_repeater_fire.tres")
	var heavy: SoundEvent = load(EVENTS_DIR + "/weapon/weapon_cannon_fire.tres")
	var blast: SoundEvent = load(EVENTS_DIR + "/explosion/explosion_large.tres")
	assert_lt(light.priority, CombatMixer.LIGHT_PRIORITY, "repeater is ducked under blasts")
	assert_gte(heavy.priority, CombatMixer.LIGHT_PRIORITY, "cannon is not")
	assert_gt(blast.priority, heavy.priority)


## Plays across the loop point with Godot's own decoder and checks that the
## step at the seam is no bigger than the steps around it.
func test_loops_are_seamless_in_engine() -> void:
	for path: String in LOOPS:
		var stream: AudioStream = load(path)
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		var length: float = stream.get_length()
		assert_gt(length, 1.0, path)
		var before: float = 0.05
		playback.start(length - before)
		var frames: PackedVector2Array = playback.mix_audio(1.0, int(MIX_RATE * before * 2.0))
		var seam: int = int(MIX_RATE * before)
		var seam_step: float = _step(frames, seam)
		var largest: float = 0.002
		for i: int in range(seam - 400, seam + 400):
			if absi(i - seam) > 2:
				largest = maxf(largest, _step(frames, i))
		assert_true(playback.is_playing(), "%s keeps playing past its end" % path)
		assert_lt(
			seam_step, largest * 1.5, "%s seam step %.4f vs %.4f" % [path, seam_step, largest]
		)
		playback.stop()


func test_synchronized_layer_volume_changes_while_playing() -> void:
	var layers: AudioStreamSynchronized = AudioStreamSynchronized.new()
	layers.stream_count = 2
	var pad: AudioStream = load("res://assets/audio/music/kessel/mus_kessel_explore_pad.ogg")
	var pulse: AudioStream = load("res://assets/audio/music/kessel/mus_kessel_explore_pulse.ogg")
	layers.set_sync_stream(0, pad)
	layers.set_sync_stream(1, pulse)
	var playback: AudioStreamPlayback = layers.instantiate_playback()
	playback.start(2.0)
	var loud: float = _rms(playback.mix_audio(1.0, 22050))
	layers.set_sync_stream_volume(0, -80.0)
	layers.set_sync_stream_volume(1, -80.0)
	playback.mix_audio(1.0, 2048)
	var quiet: float = _rms(playback.mix_audio(1.0, 22050))
	assert_gt(loud, 0.01)
	assert_lt(quiet, loud * 0.01, "layers fade while the stream plays")
	playback.stop()


func test_kessel_score_states_match_its_layers() -> void:
	var score: MusicScore = load(SCORE)
	assert_not_null(score)
	assert_not_null(score.find_state(score.default_state))
	for state: MusicState in score.states:
		var clip: int = score.clip_index(state.clip)
		assert_ne(clip, -1, "state %s clip" % state.name)
		assert_eq(state.layer_volumes_db.size(), score.clips[clip].layers.size())
	assert_true(ResourceLoader.exists("%s/ambience/%s.tres" % [EVENTS_DIR, score.ambience]))


func _step(frames: PackedVector2Array, i: int) -> float:
	var d: Vector2 = frames[i] - frames[i - 1]
	return maxf(absf(d.x), absf(d.y))


func _rms(frames: PackedVector2Array) -> float:
	var total: float = 0.0
	for frame: Vector2 in frames:
		total += frame.x * frame.x + frame.y * frame.y
	return sqrt(total / maxf(frames.size() * 2.0, 1.0))


func test_discovery_events_exist_with_their_buses() -> void:
	var expected: Dictionary[String, StringName] = {
		"signal/signal_pulse": &"Discovery",
		"signal/scan_loop": &"Discovery",
		"signal/scan_interrupted": &"Discovery",
		"sting/mus_swell_antecedent": &"Discovery",
		"ui/ui_codex_open": &"UI",
		"ui/ui_codex_close": &"UI",
		"ui/ui_codex_entry": &"UI",
		"ui/ui_intel_tick": &"UI",
		"ui/ui_option_button": &"UI",
		"advisor/advisor_discovery": &"Advisor",
		"advisor/advisor_field_option_ready": &"Advisor",
		"building/building_survey_lab_select": &"Buildings",
		"baseloop/loop_hum_survey_lab": &"Buildings",
		"weapon/weapon_warden_fire": &"Weapons",
		"explosion/death_warden": &"Explosions",
		"antecedent/unit_warden_wake": &"Units",
	}
	for kind: String in ["geological", "biological", "antecedent", "enemy"]:
		expected["discovery/discovery_resolve_%s" % kind] = &"Discovery"
	for id: String in ["orbital_scan", "supply_drop", "antecedent_power"]:
		expected["field/field_%s" % id] = &"SFX"
	for id: String in ["warden", "scrapper", "rigger"]:
		expected["movement/move_%s" % id] = &"Units"
	for id: String in ["hub", "forge", "spire", "warden"]:
		expected["baseloop/loop_hum_%s" % id] = &"Buildings"
	for path: String in expected:
		var event: SoundEvent = load("%s/%s.tres" % [EVENTS_DIR, path]) as SoundEvent
		assert_not_null(event, path)
		if event != null:
			assert_eq(event.bus, expected[path], "%s bus" % path)
	for path: String in ["signal/signal_pulse", "signal/scan_loop", "baseloop/loop_hum_warden"]:
		var event: SoundEvent = load("%s/%s.tres" % [EVENTS_DIR, path]) as SoundEvent
		assert_true(event.positional, "%s is positional" % path)
		var wav: AudioStreamWAV = event.streams[0] as AudioStreamWAV
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % path)


func test_trail_layer_is_silent_until_discoveries_raise_it() -> void:
	var score: MusicScore = load(SCORE)
	var clip: MusicClip = score.clips[0]
	var trail: int = Array(clip.layer_names).find("trail")
	assert_ne(trail, -1, "explore clip has a trail layer")
	assert_eq(clip.layers[trail].get_length(), clip.layers[0].get_length(), "same grid")
	var director: MusicDirector = MusicDirector.new()
	add_child_autofree(director)
	director.set_layer_gain(&"trail", AudioMix.SILENT_DB)
	director.play_score(score)
	assert_eq(director.layer_targets_db(&"explore")[trail], AudioMix.SILENT_DB)
	director.set_layer_gain(&"trail", -6.0)
	assert_almost_eq(director.layer_targets_db(&"explore")[trail], -6.0, 0.001)
	assert_eq(director.layer_targets_db(&"combat")[trail], AudioMix.SILENT_DB, "combat stays dry")
	assert_almost_eq(director.layer_targets_db(&"explore")[0], 0.0, 0.001, "other layers untouched")
	director.stop()
