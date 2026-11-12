extends GutTest

var _clock: SimClock


func before_each() -> void:
	_clock = SimClock.new()
	add_child_autofree(_clock)
	# Drive the clock by hand so tests are deterministic.
	_clock.set_physics_process(false)


func test_runs_at_ten_hertz() -> void:
	assert_eq(SimClock.TICK_RATE, 10)
	assert_almost_eq(_clock.get_tick_delta(), 0.1, 1e-9)


func test_one_second_of_sixty_hertz_frames_is_ten_ticks() -> void:
	for i: int in 60:
		_clock.advance(1.0 / 60.0)
	assert_eq(_clock.get_tick(), 10)


func test_no_tick_before_tick_delta() -> void:
	assert_eq(_clock.advance(0.05), 0)
	assert_eq(_clock.get_tick(), 0)


func test_interpolation_fraction_tracks_progress() -> void:
	_clock.advance(0.025)
	assert_almost_eq(_clock.get_interpolation_fraction(), 0.25, 1e-6)
	_clock.advance(0.1)
	assert_eq(_clock.get_tick(), 1)
	assert_almost_eq(_clock.get_interpolation_fraction(), 0.25, 1e-6)


func test_paused_clock_does_not_tick() -> void:
	_clock.paused = true
	assert_eq(_clock.advance(1.0), 0)
	assert_eq(_clock.get_tick(), 0)
	assert_eq(_clock.get_interpolation_fraction(), 0.0)


func test_long_hitch_is_capped() -> void:
	assert_eq(_clock.advance(10.0), SimClock.MAX_TICKS_PER_STEP)
	assert_lt(_clock.get_interpolation_fraction(), 1.0)


func test_emits_local_and_global_tick_signals() -> void:
	watch_signals(_clock)
	watch_signals(Events)
	_clock.advance(0.1)
	assert_signal_emitted_with_parameters(_clock, "ticked", [1])
	assert_signal_emitted_with_parameters(Events, "sim_ticked", [1])


func test_runs_from_physics_process() -> void:
	_clock.set_physics_process(true)
	await wait_physics_frames(12)
	assert_gt(_clock.get_tick(), 0)


func test_save_round_trip() -> void:
	_clock.advance(0.35)
	_clock.paused = true
	var data: Dictionary = _clock.to_dict()
	var version: int = data["version"]
	assert_eq(version, SimClock.SAVE_VERSION)
	var restored: SimClock = SimClock.new()
	autofree(restored)
	restored.from_dict(data)
	assert_eq(restored.get_tick(), 3)
	assert_true(restored.paused)
