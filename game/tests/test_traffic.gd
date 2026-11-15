extends GutTest
## Traffic (ADR 0022): ground units pass each other without driving through one
## another. Vehicle-like units on open ground with the straight-line PathService.

const DT: float = 0.1
## Two bodies count as overlapping when they are this much inside each other, metres.
const OVERLAP_TOLERANCE: float = 0.1


class CornerVisibility:
	extends PathService
	var clear: bool = false

	func is_segment_walkable(_from: Vector3, _to: Vector3) -> bool:
		return clear


var _def: UnitDef
var _queue: CommandQueue
var _traffic: Traffic
var _units: Array[Unit]
## The deepest overlap of any two units seen while ticking, metres.
var _deepest_overlap: float


func before_each() -> void:
	_def = _make_def(1.2, 6.0)
	_queue = CommandQueue.new()
	_traffic = Traffic.new()
	_units = []
	_deepest_overlap = 0.0


func _make_def(radius: float, speed: float) -> UnitDef:
	var def: UnitDef = UnitDef.new()
	def.move_speed = speed
	def.acceleration = 8.0
	def.turn_speed = 120.0
	def.radius = radius
	return def


func _unit(at: Vector3, facing: Vector3, faction: int = 0, def: UnitDef = null) -> Unit:
	var unit: Unit = Unit.new()
	unit.def = def if def != null else _def
	unit.faction = faction
	unit.add_child(Locomotion.new())
	unit.add_child(UnitOrders.new())
	add_child_autofree(unit)
	var traffic: Traffic = _traffic
	unit.locomotion.setup(
		unit.def, at, Mover.yaw_for(facing), PathService.new(), null, traffic, faction
	)
	_units.append(unit)
	return unit


func _move(unit: Unit, target: Vector3) -> void:
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, unit.faction, [unit], target))


func _tick(ticks: int) -> void:
	for i: int in ticks:
		_queue.flush()
		if _traffic != null:
			_traffic.solve()
		for unit: Unit in _units:
			unit.sim_tick(DT)
		_measure_overlap()


func _measure_overlap() -> void:
	for i: int in _units.size():
		for j: int in range(i + 1, _units.size()):
			var gap: float = (
				_flat(_units[i].sim_position()).distance_to(_flat(_units[j].sim_position()))
				- _units[i].def.radius
				- _units[j].def.radius
			)
			_deepest_overlap = maxf(_deepest_overlap, -gap)


static func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _assert_at(unit: Unit, target: Vector3, within: float, what: String) -> void:
	assert_lt(_flat(unit.sim_position()).distance_to(_flat(target)), within, what)


func test_without_traffic_units_drive_through_each_other() -> void:
	_traffic = null
	var north: Unit = _unit(Vector3(0, 0, 20), Vector3.FORWARD)
	var south: Unit = _unit(Vector3(0, 0, -20), Vector3.BACK)
	_move(north, Vector3(0, 0, -20))
	_move(south, Vector3(0, 0, 20))
	_tick(120)
	assert_gt(_deepest_overlap, 1.5, "the case traffic exists for")


func test_head_on_units_pass_on_the_right() -> void:
	var north: Unit = _unit(Vector3(0, 0, 20), Vector3.FORWARD)
	var south: Unit = _unit(Vector3(0, 0, -20), Vector3.BACK)
	_move(north, Vector3(0, 0, -20))
	_move(south, Vector3(0, 0, 20))
	var passed_on_right: bool = false
	for i: int in 140:
		_tick(1)
		if absf(north.sim_position().z) < 1.0:
			# Driving toward -Z, right is +X.
			passed_on_right = north.sim_position().x > 0.5
	assert_lt(_deepest_overlap, OVERLAP_TOLERANCE, "never inside each other")
	assert_true(passed_on_right, "kept right")
	_assert_at(north, Vector3(0, 0, -20), 0.5, "north arrived")
	_assert_at(south, Vector3(0, 0, 20), 0.5, "south arrived")
	assert_true(north.orders.is_idle() and south.orders.is_idle(), "orders done")


func test_two_columns_meeting_head_on_get_through() -> void:
	var targets: Array[Vector3] = []
	for i: int in 4:
		_unit(Vector3(0, 0, 20 + i * 4.0), Vector3.FORWARD)
		targets.append(Vector3(0, 0, -20 - i * 4.0))
	for i: int in 4:
		_unit(Vector3(0, 0, -20 - i * 4.0), Vector3.BACK)
		targets.append(Vector3(0, 0, 20 + i * 4.0))
	for i: int in _units.size():
		_move(_units[i], targets[i])
	_tick(250)
	assert_lt(_deepest_overlap, OVERLAP_TOLERANCE, "never inside each other")
	for i: int in _units.size():
		_assert_at(_units[i], targets[i], 0.5, "unit %d arrived" % i)


func test_crossing_units_do_not_touch() -> void:
	var north: Unit = _unit(Vector3(0, 0, 20), Vector3.FORWARD)
	var west: Unit = _unit(Vector3(-20, 0, 0), Vector3.RIGHT)
	_move(north, Vector3(0, 0, -20))
	_move(west, Vector3(20, 0, 0))
	_tick(140)
	assert_lt(_deepest_overlap, OVERLAP_TOLERANCE, "never inside each other")
	_assert_at(north, Vector3(0, 0, -20), 0.5, "north arrived")
	_assert_at(west, Vector3(20, 0, 0), 0.5, "west arrived")


func test_a_standing_friend_steps_aside_and_walks_back() -> void:
	var parked: Unit = _unit(Vector3.ZERO, Vector3.FORWARD)
	var driver: Unit = _unit(Vector3(0, 0, 20), Vector3.FORWARD)
	_move(driver, Vector3(0, 0, -20))
	var moved_away: float = 0.0
	for i: int in 140:
		_tick(1)
		moved_away = maxf(moved_away, _flat(parked.sim_position()).length())
	assert_lt(_deepest_overlap, OVERLAP_TOLERANCE, "never inside each other")
	assert_gt(moved_away, 0.5, "the parked unit stepped aside")
	_assert_at(driver, Vector3(0, 0, -20), 0.5, "the driver arrived")
	_assert_at(parked, Vector3.ZERO, Locomotion.RETURN_DISTANCE + 0.1, "and it walked back")
	assert_true(parked.orders.is_idle(), "without ever having an order")
	assert_eq(parked.locomotion.mover.speed, 0.0, "standing again")


func test_a_slow_queue_still_gets_room_from_an_idle_friend() -> void:
	var parked: Unit = _unit(Vector3.ZERO, Vector3.FORWARD)
	var driver: Unit = _unit(Vector3(0, 0, 6), Vector3.FORWARD, 0, _make_def(1.2, 0.6))
	_move(driver, Vector3(0, 0, -6))
	var moved_away: float = 0.0
	for i: int in 300:
		_tick(1)
		moved_away = maxf(moved_away, _flat(parked.sim_position()).length())
	assert_lt(_deepest_overlap, OVERLAP_TOLERANCE, "remain separated while creeping")
	assert_gt(moved_away, 0.5, "idle friends make room even for a slow queue")
	_assert_at(driver, Vector3(0, 0, -6), 0.5, "slow traffic gets through too")
	_assert_at(parked, Vector3.ZERO, Locomotion.RETURN_DISTANCE + 0.1, "idle friend returns")


func test_an_idle_friend_does_not_step_across_a_blocked_segment() -> void:
	var parked: Unit = _unit(Vector3.ZERO, Vector3.FORWARD)
	var visibility: CornerVisibility = CornerVisibility.new()
	parked.locomotion.paths = visibility
	var driver: Unit = _unit(Vector3(0, 0, 6), Vector3.FORWARD)
	_move(driver, Vector3(0, 0, -8))
	var moved_away: float = 0.0
	for i: int in 160:
		_tick(1)
		moved_away = maxf(moved_away, _flat(parked.sim_position()).length())
	assert_eq(moved_away, 0.0, "valid endpoints do not permit crossing blocked ground")
	_assert_at(driver, Vector3(0, 0, -8), 0.5, "the driver routes around the standing friend")


func test_a_unit_holding_its_ground_is_driven_around() -> void:
	var parked: Unit = _unit(Vector3.ZERO, Vector3.FORWARD)
	var driver: Unit = _unit(Vector3(0, 0, 20), Vector3.FORWARD)
	_move(driver, Vector3(0, 0, -20))
	for i: int in 140:
		parked.locomotion.holds_ground = true
		_queue.flush()
		_traffic.solve()
		driver.sim_tick(DT)
		parked.locomotion.tick(DT)
		_measure_overlap()
	assert_lt(_deepest_overlap, OVERLAP_TOLERANCE, "never inside each other")
	assert_eq(parked.sim_position(), Vector3.ZERO, "it did not move")
	_assert_at(driver, Vector3(0, 0, -20), 0.5, "the driver arrived")


func test_an_enemy_in_the_way_does_not_step_aside() -> void:
	var enemy: Unit = _unit(Vector3.ZERO, Vector3.FORWARD, 1)
	var driver: Unit = _unit(Vector3(0, 0, 20), Vector3.FORWARD)
	_move(driver, Vector3(0, 0, -20))
	_tick(140)
	assert_lt(_deepest_overlap, OVERLAP_TOLERANCE, "never inside each other")
	assert_eq(enemy.sim_position(), Vector3.ZERO, "it did not move")
	_assert_at(driver, Vector3(0, 0, -20), 0.5, "the driver arrived")


func test_a_fast_unit_does_not_ram_a_slow_one_ahead() -> void:
	var slow: Unit = _unit(Vector3(0, 0, 10), Vector3.FORWARD, 0, _make_def(1.6, 2.6))
	var fast: Unit = _unit(Vector3(0, 0, 20), Vector3.FORWARD, 0, _make_def(0.8, 11.0))
	_move(slow, Vector3(0, 0, -40))
	_move(fast, Vector3(0, 0, -60))
	_tick(250)
	assert_lt(_deepest_overlap, OVERLAP_TOLERANCE, "never inside each other")
	_assert_at(fast, Vector3(0, 0, -60), 0.5, "the fast unit got past and arrived")
	_assert_at(slow, Vector3(0, 0, -40), 0.5, "the slow unit arrived")


func test_overlapping_units_are_pushed_apart() -> void:
	var first: Unit = _unit(Vector3.ZERO, Vector3.FORWARD)
	var second: Unit = _unit(Vector3(0.4, 0, 0), Vector3.FORWARD)
	_tick(30)
	var distance: float = _flat(first.sim_position()).distance_to(_flat(second.sim_position()))
	assert_gt(distance, _def.radius * 2.0 - OVERLAP_TOLERANCE, "apart")


func test_passing_beside_a_parked_body_does_not_brake() -> void:
	var driver: TrafficBody = TrafficBody.new()
	driver.radius = 1.2
	driver.max_speed = 6.0
	driver.acceleration = 8.0
	driver.moving = true
	driver.velocity = Vector3.FORWARD * 6.0
	driver.wish = driver.velocity
	var parked: TrafficBody = TrafficBody.new()
	parked.radius = 1.2
	parked.position = Vector3(2.6, 0.0, -1.5)
	_traffic.add(driver)
	_traffic.add(parked)
	_traffic.solve()
	assert_eq(driver.speed_cap, INF, "clear of both bodies: retain forward speed")
	assert_gt(driver.steer.length(), 0.0, "still make comfortable passing room")


func test_route_shortcuts_require_a_clear_next_leg() -> void:
	for clear: bool in [false, true]:
		var driver: Unit = _unit(Vector3(-2, 0, 0), Vector3.FORWARD)
		var visibility: CornerVisibility = CornerVisibility.new()
		visibility.clear = clear
		driver.locomotion.paths = visibility
		driver.locomotion.follow_path(PackedVector3Array([Vector3(0, 0, -4), Vector3(12, 0, -4)]))
		driver.locomotion.tick(DT)
		assert_eq(
			driver.locomotion.mover.path_index,
			1 if clear else 0,
			"skip an unnecessary funnel point, but retain a corner behind a wall"
		)


func test_traffic_is_repeatable() -> void:
	var ends: Array[Vector3] = []
	for run: int in 2:
		_traffic = Traffic.new()
		_units = []
		var north: Unit = _unit(Vector3(0.3, 0, 20), Vector3.FORWARD)
		var south: Unit = _unit(Vector3(0, 0, -20), Vector3.BACK)
		var west: Unit = _unit(Vector3(-20, 0, 1), Vector3.RIGHT)
		_move(north, Vector3(0, 0, -20))
		_move(south, Vector3(0, 0, 20))
		_move(west, Vector3(20, 0, 0))
		_tick(60)
		ends.append(north.sim_position() + south.sim_position() * 3.0 + west.sim_position() * 7.0)
	assert_eq(ends[0], ends[1], "same inputs, same outcome")
