extends GutTest
## Integration checks on the real data and assets, decoded by Godot itself.

const EVENTS_DIR: String = "res://data/sounds"
const LOOPS: Array[String] = [
	"res://assets/audio/movement/move_rover.wav",
	"res://assets/audio/movement/move_walker.wav",
	"res://assets/audio/movement/move_tracks.wav",
	"res://assets/audio/movement/move_hover.wav",
	"res://assets/audio/ambience/amb_kessel_wind.ogg",
	"res://assets/audio/music/kessel/mus_kessel_explore_pad.ogg",
	"res://assets/audio/music/kessel/mus_kessel_explore_pulse.ogg",
	"res://assets/audio/music/kessel/mus_kessel_explore_melody.ogg",
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
	for sound_set: String in ["surveyor", "ranger", "bulwark", "kite"]:
		for kind: String in ["select", "move", "attack"]:
			var path: String = "%s/unit/unit_%s_%s.tres" % [EVENTS_DIR, sound_set, kind]
			var event: SoundEvent = load(path) as SoundEvent
			assert_not_null(event, path)
			if event != null:
				assert_eq(event.streams.size(), 3, "%s variations" % path)
				assert_eq(event.pitch_variation, 0.0, "tonal replies stay in key")
		assert_true(ResourceLoader.exists("%s/movement/move_%s.tres" % [EVENTS_DIR, sound_set]))


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
	var score: MusicScore = load("res://data/sounds/music/kessel_reach.tres")
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
