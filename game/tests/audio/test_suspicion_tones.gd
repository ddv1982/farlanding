extends GutTest
## SuspicionTones: which watchers get the rising tone (pure ranking and the
## node with stub watchers), its caps, level and pitch, and the reset.

const EVENT_PATH: String = "res://data/sounds/stealth/stealth_suspicion.tres"


class FakeWatcher:
	extends Node3D
	var suspicion: float = 0.0
	var is_alerted: bool = false
	var is_visible_to_player: bool = true


var _tones: SuspicionTones
var _event: SoundEvent


func before_each() -> void:
	_event = load(EVENT_PATH) as SoundEvent
	_tones = SuspicionTones.new()
	_tones.resolve_event = func(id: StringName) -> SoundEvent:
		return _event if id == StealthCues.SUSPICION_LOOP else null
	add_child_autofree(_tones)
	_tones.set_process(false)


func _watcher(suspicion: float, at: Vector3) -> FakeWatcher:
	var watcher: FakeWatcher = FakeWatcher.new()
	watcher.suspicion = suspicion
	watcher.position = at
	add_child_autofree(watcher)
	_tones.track(watcher)
	return watcher


func _all(count: int, value: bool) -> Array[bool]:
	var out: Array[bool] = []
	for i: int in count:
		out.append(value)
	return out


func test_event_is_a_positional_stealth_loop() -> void:
	assert_not_null(_event)
	assert_true(_event.positional)
	assert_eq(_event.bus, &"Stealth")
	var wav: AudioStreamWAV = _event.streams[0] as AudioStreamWAV
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)


func test_pick_ranks_by_suspicion_and_distance() -> void:
	var suspicion: PackedFloat32Array = [0.3, 0.9, 0.6, 0.9]
	var distance: PackedFloat32Array = [5.0, 60.0, 10.0, 10.0]
	var picked: PackedInt32Array = StealthCues.pick_tones(
		suspicion, distance, _all(4, true), 2, 70.0
	)
	assert_eq(Array(picked), [3, 2], "0.9 near, then 0.6 near beats 0.9 far")


func test_pick_ties_go_to_the_nearer() -> void:
	var suspicion: PackedFloat32Array = [0.5, 0.5]
	var distance: PackedFloat32Array = [0.0, 0.0]
	var picked: PackedInt32Array = StealthCues.pick_tones(
		suspicion, distance, _all(2, true), 1, 70.0
	)
	assert_eq(picked.size(), 1)


func test_pick_skips_ineligible_quiet_and_far() -> void:
	var suspicion: PackedFloat32Array = [0.8, 0.01, 0.8, 0.7]
	var distance: PackedFloat32Array = [5.0, 5.0, 80.0, 20.0]
	var eligible: Array[bool] = [false, true, true, true]
	var picked: PackedInt32Array = StealthCues.pick_tones(suspicion, distance, eligible, 3, 70.0)
	assert_eq(Array(picked), [3])


func test_level_and_pitch_tighten_with_suspicion() -> void:
	assert_lt(StealthCues.tone_db(0.1), StealthCues.tone_db(0.9))
	assert_lt(StealthCues.tone_pitch(0.1), StealthCues.tone_pitch(0.9))
	assert_almost_eq(StealthCues.tone_pitch(1.0), StealthCues.TONE_PITCH.y, 0.001)
	assert_almost_eq(StealthCues.tone_db(2.0), StealthCues.TONE_DB.y, 0.001, "clamped")


func test_highest_suspicion_watchers_get_the_tones_capped() -> void:
	var low: FakeWatcher = _watcher(0.2, Vector3(2, 0, 0))
	var high: FakeWatcher = _watcher(0.9, Vector3(10, 0, 0))
	var mid: FakeWatcher = _watcher(0.6, Vector3(4, 0, 0))
	_tones.rescan()
	var chosen: Array[Node3D] = _tones.chosen_watchers()
	assert_eq(chosen.size(), SuspicionTones.MAX_TONES)
	assert_eq(chosen[0], high)
	assert_eq(chosen[1], mid)
	assert_false(low in chosen)
	assert_eq(_tones.playing_count(), 2)


func test_hidden_alerted_and_far_watchers_are_silent() -> void:
	var hidden: FakeWatcher = _watcher(0.9, Vector3(1, 0, 0))
	hidden.is_visible_to_player = false
	var alerted: FakeWatcher = _watcher(0.9, Vector3(1, 0, 0))
	alerted.is_alerted = true
	_watcher(0.9, Vector3(_event.max_distance + 5.0, 0, 0))
	_tones.rescan()
	assert_eq(_tones.chosen_watchers().size(), 0)


func test_the_events_bus_teaches_watchers() -> void:
	var watcher: FakeWatcher = FakeWatcher.new()
	watcher.suspicion = 0.5
	add_child_autofree(watcher)
	var target: Node3D = Node3D.new()
	add_child_autofree(target)
	Events.suspicion_raised.emit(watcher, target)
	assert_eq(_tones.tracked_count(), 1)
	_tones.rescan()
	assert_eq(_tones.chosen_watchers(), [watcher] as Array[Node3D])


func test_a_calm_watcher_is_forgotten() -> void:
	var watcher: FakeWatcher = _watcher(0.4, Vector3.ZERO)
	_tones.rescan()
	watcher.suspicion = 0.0
	_tones.rescan()
	assert_eq(_tones.tracked_count(), 0)
	assert_eq(_tones.chosen_watchers().size(), 0)


func test_pitch_follows_suspicion_as_it_rises() -> void:
	var watcher: FakeWatcher = _watcher(0.2, Vector3.ZERO)
	_tones.rescan()
	_tones.step(0.05)
	var before: float = _tones.tone_pitch_of(watcher)
	assert_gt(before, 0.0)
	watcher.suspicion = 0.95
	for i: int in 30:
		_tones.step(0.05)
	assert_gt(_tones.tone_pitch_of(watcher), before + 0.2)


func test_mission_start_silences_and_forgets() -> void:
	_watcher(0.8, Vector3.ZERO)
	_tones.rescan()
	assert_eq(_tones.playing_count(), 1)
	Events.mission_started.emit()
	assert_eq(_tones.tracked_count(), 0)
	assert_eq(_tones.playing_count(), 0)
	assert_eq(_tones.chosen_watchers().size(), 0)
