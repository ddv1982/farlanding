extends GutTest

const DT: float = 0.1


func _run(mover: Mover, ticks: int) -> int:
	for tick: int in ticks:
		mover.integrate(mover.velocity, DT)
		if mover.plan(DT):
			return tick
	return -1


func test_reaches_target_and_stops_exactly() -> void:
	var mover: Mover = Mover.new(5.0, 10.0, TAU)
	mover.set_path([Vector3(0, 0, -20)])
	var arrived_at: int = _run(mover, 200)
	assert_gt(arrived_at, 0, "should arrive")
	assert_almost_eq(mover.position, Vector3(0, 0, -20), Vector3.ONE * 1e-4)
	assert_eq(mover.speed, 0.0)
	assert_false(mover.has_path())


func test_never_exceeds_max_speed() -> void:
	var mover: Mover = Mover.new(4.0, 50.0, TAU)
	mover.set_path([Vector3(0, 0, -100)])
	for tick: int in 50:
		mover.integrate(mover.velocity, DT)
		mover.plan(DT)
		assert_lte(mover.speed, 4.0 + 1e-4)


func test_accelerates_smoothly() -> void:
	var mover: Mover = Mover.new(10.0, 5.0, TAU)
	mover.set_path([Vector3(0, 0, -100)])
	mover.plan(DT)
	assert_almost_eq(mover.speed, 0.5, 1e-4, "one tick of acceleration")
	mover.integrate(mover.velocity, DT)
	mover.plan(DT)
	assert_almost_eq(mover.speed, 1.0, 1e-4)


func test_follows_corners_in_order() -> void:
	var mover: Mover = Mover.new(5.0, 20.0, TAU * 2.0)
	mover.set_path([Vector3(0, 0, -10), Vector3(10, 0, -10)])
	var passed_first: bool = false
	for tick: int in 200:
		mover.integrate(mover.velocity, DT)
		var done: bool = mover.plan(DT)
		if mover.path_index == 1:
			passed_first = true
		if done:
			break
	assert_true(passed_first)
	assert_almost_eq(mover.position, Vector3(10, 0, -10), Vector3.ONE * 1e-4)


func test_turns_at_turn_speed() -> void:
	var mover: Mover = Mover.new(5.0, 10.0, deg_to_rad(90.0))
	mover.yaw = 0.0
	# Target straight behind: needs a 180° turn.
	mover.set_path([Vector3(0, 0, 20)])
	mover.plan(DT)
	assert_almost_eq(absf(mover.yaw), deg_to_rad(9.0), 1e-4)
	assert_eq(mover.speed, 0.0, "turns in place when facing away")


func test_faces_travel_direction_after_moving() -> void:
	var mover: Mover = Mover.new(5.0, 10.0, TAU)
	mover.set_path([Vector3(30, 0, 0)])
	_run(mover, 20)
	assert_almost_eq(mover.yaw, Mover.yaw_for(Vector3.RIGHT), 0.01)


func test_clear_path_brakes_to_halt() -> void:
	var mover: Mover = Mover.new(5.0, 10.0, TAU)
	mover.set_path([Vector3(0, 0, -100)])
	_run(mover, 20)
	assert_gt(mover.speed, 4.0)
	mover.clear_path()
	mover.plan(DT)
	assert_almost_eq(mover.speed, 4.0, 1e-3, "brakes, does not stop instantly")
	_run(mover, 10)
	assert_eq(mover.speed, 0.0)


func test_save_round_trip() -> void:
	var mover: Mover = Mover.new()
	mover.set_path([Vector3(1, 0, 2), Vector3(3, 0, 4)])
	mover.position = Vector3(5, 1, 6)
	mover.yaw = 0.5
	var copy: Mover = Mover.new()
	copy.from_dict(mover.to_dict())
	assert_eq(copy.position, mover.position)
	assert_eq(copy.path, mover.path)
	assert_almost_eq(copy.yaw, 0.5, 1e-6)
