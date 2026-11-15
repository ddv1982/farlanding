extends GutTest
## Playback-boundary checks; the integrated real-mixer suite covers audible output.

var _playback: OneShotPlayback
var _time: float = 10.0


func before_each() -> void:
	_time = 10.0
	_playback = OneShotPlayback.new()
	_playback.now = func() -> float: return _time
	add_child_autofree(_playback)


func after_each() -> void:
	_playback.stop_all()


func _event(positional: bool = false) -> SoundEvent:
	var event: SoundEvent = SoundEvent.new()
	event.id = &"fixture"
	event.positional = positional
	event.volume_db = -8.0
	for i: int in 3:
		var stream: AudioStreamWAV = AudioStreamWAV.new()
		stream.mix_rate = 44100
		var data: PackedByteArray = PackedByteArray()
		data.resize(44100)
		stream.data = data
		event.streams.append(stream)
	return event


func test_budget_rejection_consumes_draws_but_keeps_last_successful_variation() -> void:
	var event: SoundEvent = _event()
	event.pitch_variation = 2.0
	event.cooldown = 0.5
	_playback._rng.seed = 1729
	var expected: RandomNumberGenerator = RandomNumberGenerator.new()
	expected.seed = 1729
	var last: int = -1
	for attempt: int in 3:
		var index: int = SoundEvent.pick_index(3, last, expected.randf(), true)
		var pitch: float = pow(2.0, expected.randf_range(-2.0, 2.0) / 12.0)
		var state_at_allocation: int = expected.state
		_playback.now = func() -> float:
			assert_eq(_playback._rng.state, state_at_allocation, "draws precede clock sampling")
			return _time
		var started: bool = _playback.start(event.id, event, Vector3.INF, -3.0)
		assert_eq(started, attempt != 1, "cooldown rejects only the middle attempt")
		assert_eq(_playback._rng.state, expected.state, "rejection consumes both draws")
		if started:
			last = index
			var voice: int = 0 if attempt == 0 else 1
			var player: AudioStreamPlayer = _playback._flat_players[voice]
			assert_eq(player.stream, event.streams[index])
			assert_almost_eq(player.pitch_scale, pitch, 0.00001)
			assert_eq(player.volume_db, -11.0)
		assert_eq(_playback._last_variation[event.id], last)
		_time += 0.25


func test_distance_uses_ground_focus_and_culls_before_randomness() -> void:
	var event: SoundEvent = _event(true)
	event.max_distance = 5.0
	_playback.focus = Vector3(10.0, 100.0, 20.0)
	assert_true(_playback.start(event.id, event, Vector3(100.0, 0.0, 100.0)))
	_playback.stop_all()
	_playback.listener_active = true
	var state: int = _playback._rng.state
	assert_false(_playback.start(event.id, event, Vector3(16.0, 100.0, 20.0)))
	assert_eq(_playback._rng.state, state, "distance rejection takes no random draws")
	var position: Vector3 = Vector3(13.0, -100.0, 24.0)
	assert_true(_playback.start(event.id, event, position, -2.0), "inclusive horizontal cutoff")
	var player: AudioStreamPlayer3D = _playback._positional_players[0]
	assert_eq(player.global_position, position)
	assert_eq(player.max_distance, 5.0)
	assert_eq(player.volume_db, -10.0)
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
	assert_eq(player.unit_size, 10.0)


func test_flat_fallback_finished_release_and_stop_scopes() -> void:
	var event: SoundEvent = _event(true)
	assert_eq(_playback._flat_players.size(), 16)
	assert_eq(_playback._positional_players.size(), 32)
	assert_true(_playback.start(event.id, event, Vector3.INF))
	assert_true(_playback.start(event.id, event, Vector3.ZERO))
	assert_eq(_playback.active_voices(), 2)
	_playback.stop_world()
	assert_eq(_playback.active_voices(), 1, "world stop leaves flat fallback alone")
	assert_true(_playback._flat_players[0].playing)
	assert_false(_playback._positional_players[0].playing)
	_playback._flat_players[0].finished.emit()
	assert_eq(_playback.active_voices(), 0, "flat finished releases allocation")
	assert_true(_playback.start(event.id, event, Vector3.ZERO))
	_playback._positional_players[0].finished.emit()
	assert_eq(_playback.active_voices(), 0, "positional finished releases allocation")
	assert_true(_playback.start(event.id, event, Vector3.INF))
	assert_true(_playback.start(event.id, event, Vector3.ZERO))
	_playback.stop_all()
	assert_eq(_playback.active_voices(), 0)
	assert_false(_playback._flat_players[0].playing)
	assert_false(_playback._positional_players[0].playing)


func test_stop_preserves_cooldown_and_invalid_events_take_no_draws() -> void:
	var state: int = _playback._rng.state
	assert_false(_playback.start(&"missing", null, Vector3.INF))
	assert_false(_playback.start(&"empty", SoundEvent.new(), Vector3.INF))
	assert_eq(_playback._rng.state, state)
	var event: SoundEvent = _event()
	event.cooldown = 1.0
	assert_true(_playback.start(event.id, event, Vector3.INF))
	_playback.stop_all()
	assert_false(_playback.start(event.id, event, Vector3.INF), "stop preserves cooldown")
	_time += 1.0
	assert_true(_playback.start(event.id, event, Vector3.INF), "cooldown ends at its boundary")
