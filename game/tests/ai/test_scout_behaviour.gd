extends GutTest
## Scout behaviour: travels from waypoint to waypoint, moves on when it meets armed
## enemies, skips places it cannot reach, and ends when there is nothing left.

var _f: AiFixture
var _port: AiFixture.FakePort
var _points: Array[Vector3] = []
var _blocked: Array[Vector3] = []


func before_each() -> void:
	_f = AiFixture.new(self)
	_port = AiFixture.FakePort.new(AiFixture.AI)
	_points = [Vector3(50, 0, 0), Vector3(0, 0, 50), Vector3(-50, 0, 0)]
	_blocked = []


func after_each() -> void:
	_f.dispose()


func _scout(unit: Unit) -> ScoutBehaviour:
	var scout: ScoutBehaviour = ScoutBehaviour.new(_port, _f.profile, unit)
	scout.next_point = func(_from: Vector3) -> Vector3:
		return _points.pop_front() if not _points.is_empty() else Vector3.INF
	scout.on_unreachable = func(point: Vector3) -> void: _blocked.append(point)
	scout.start()
	return scout


func _step(scout: ScoutBehaviour) -> void:
	_port.tick += 5
	scout.tick(_port.tick)


func test_travels_on_from_waypoint_to_waypoint() -> void:
	var unit: Unit = _f.unit(_f.scout, Vector3.ZERO)
	var scout: ScoutBehaviour = _scout(unit)
	assert_eq(scout.waypoint, Vector3(50, 0, 0))
	assert_eq(_port.last_kind(), MoveCommand.KIND_MOVE)
	unit.orders.give(Order.new(MoveCommand.KIND_MOVE, Vector3(50, 0, 0)))
	_step(scout)
	assert_eq(scout.waypoint, Vector3(50, 0, 0), "still travelling")
	unit.locomotion.mover.position = Vector3(48, 0, 0)
	_step(scout)
	assert_eq(scout.waypoint, Vector3(0, 0, 50), "reached: on to the next")
	assert_eq(scout.legs, 2)


func test_moves_on_when_it_meets_armed_enemies() -> void:
	var unit: Unit = _f.unit(_f.scout, Vector3.ZERO)
	var scout: ScoutBehaviour = _scout(unit)
	unit.orders.give(Order.new(MoveCommand.KIND_MOVE, Vector3(50, 0, 0)))
	_port.enemies = [_f.unit(_f.soldier, Vector3(10, 0, 0), AiFixture.ENEMY)]
	_step(scout)
	assert_eq(scout.state(), ScoutBehaviour.EVADE)
	assert_eq(scout.encounters, 1)
	assert_eq(scout.waypoint, Vector3(0, 0, 50), "it left for somewhere else")
	_port.enemies = []
	_step(scout)
	assert_eq(scout.state(), ScoutBehaviour.TRAVEL)


func test_skips_unreachable_waypoints_and_ends_when_nothing_is_left() -> void:
	var unit: Unit = _f.unit(_f.scout, Vector3.ZERO)
	var scout: ScoutBehaviour = _scout(unit)
	# Its orders stay idle (no path): each waypoint is reported unreachable.
	for i: int in 6:
		_step(scout)
	assert_eq(_blocked.size(), 3)
	assert_true(scout.finished)
