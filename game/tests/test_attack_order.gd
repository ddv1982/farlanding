extends GutTest
## The attack order: approach to engagement distance, hold facing the target, end when
## the target is gone, give way to move and stop. Straight-line PathService, no terrain.

const DT: float = 0.1

var _def: UnitDef
var _queue: CommandQueue


func before_each() -> void:
	_def = UnitDef.new()
	_def.move_speed = 5.0
	_def.acceleration = 20.0
	_def.turn_speed = 360.0
	_def.radius = 0.5
	_queue = CommandQueue.new()


func _unit(at: Vector3, faction: int = 0) -> Unit:
	var unit: Unit = Unit.new()
	unit.def = _def
	unit.faction = faction
	unit.add_child(Locomotion.new())
	unit.add_child(UnitOrders.new())
	add_child_autofree(unit)
	unit.locomotion.setup(_def, at, 0.0, PathService.new(), null)
	return unit


func _tick(units: Array[Unit], ticks: int) -> void:
	for i: int in ticks:
		_queue.flush()
		for unit: Unit in units:
			unit.sim_tick(DT)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _facing_error(unit: Unit, target: Vector3) -> float:
	var wanted: float = Mover.yaw_for(target - unit.locomotion.mover.position)
	return absf(angle_difference(unit.locomotion.mover.yaw, wanted))


func test_attack_command_has_kind_and_target() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	var enemy: Unit = _unit(Vector3(0, 0, -30), 1)
	var command: AttackCommand = AttackCommand.new(0, [unit], enemy)
	assert_eq(command.kind, &"attack")
	assert_eq(command.target_entity, enemy as Node3D)


func test_group_approaches_stops_at_range_spread_and_faces_target() -> void:
	var enemy: Unit = _unit(Vector3(0, 0, -50), 1)
	var units: Array[Unit] = []
	for i: int in 4:
		units.append(_unit(Vector3(i * 2.0 - 3.0, 0, 0)))
	var entities: Array[Node3D] = []
	entities.assign(units)
	_queue.push(AttackCommand.new(0, entities, enemy))
	_tick(units, 150)
	for unit: Unit in units:
		assert_eq(unit.orders.current.kind, AttackCommand.KIND, "order still running")
		assert_true(unit.orders.is_engaged(), "holding at range")
		assert_eq(unit.locomotion.mover.speed, 0.0, "stopped")
		var distance: float = _flat_distance(unit.locomotion.mover.position, Vector3(0, 0, -50))
		assert_between(distance, AttackCommand.ENGAGE_RANGE - 1.0, AttackCommand.ENGAGE_RANGE + 2.0)
		assert_lt(_facing_error(unit, Vector3(0, 0, -50)), 0.05, "faces the target")
	for i: int in units.size():
		for j: int in range(i + 1, units.size()):
			var a: Vector3 = units[i].locomotion.mover.position
			var b: Vector3 = units[j].locomotion.mover.position
			assert_gt(a.distance_to(b), 1.5, "spread out, not piled on one point")
	assert_eq(enemy.locomotion.mover.position, Vector3(0, 0, -50), "the target was not moved")


func test_engaged_unit_aims_and_follows_a_moving_target() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	var enemy: Unit = _unit(Vector3(0, 0, -30), 1)
	watch_signals(unit.orders)
	_queue.push(AttackCommand.new(0, [unit], enemy))
	_tick([unit], 80)
	assert_true(unit.orders.is_engaged())
	assert_signal_emitted(unit.orders, "aim_changed")
	enemy.locomotion.mover.position = Vector3(30, 0, -30)
	_tick([unit], 150)
	assert_true(unit.orders.is_engaged(), "caught up again")
	var distance: float = _flat_distance(unit.locomotion.mover.position, Vector3(30, 0, -30))
	assert_lt(distance, AttackCommand.ENGAGE_RANGE + 2.0)


func test_order_ends_when_target_dies() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	var enemy: Unit = _unit(Vector3(0, 0, -40), 1)
	watch_signals(unit.orders)
	_queue.push(AttackCommand.new(0, [unit], enemy))
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(5, 0, 0), true))
	_tick([unit], 100)
	assert_true(unit.orders.is_engaged())
	enemy.free()
	_tick([unit], 1)
	assert_ne(unit.orders.current.kind if unit.orders.current != null else &"", AttackCommand.KIND)
	assert_false(unit.orders.is_engaged())
	assert_signal_emitted(unit.orders, "aim_cleared")
	_tick([unit], 100)
	assert_true(unit.orders.is_idle(), "went on to the queued move and finished it")
	assert_almost_eq(unit.locomotion.mover.position, Vector3(5, 0, 0), Vector3.ONE * 0.01)


func test_move_cancels_attack() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	var enemy: Unit = _unit(Vector3(0, 0, -40), 1)
	_queue.push(AttackCommand.new(0, [unit], enemy))
	_tick([unit], 20)
	assert_eq(unit.orders.current.kind, AttackCommand.KIND)
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(20, 0, 0)))
	_tick([unit], 80)
	assert_true(unit.orders.is_idle())
	assert_false(unit.orders.is_engaged())
	assert_almost_eq(unit.locomotion.mover.position, Vector3(20, 0, 0), Vector3.ONE * 0.01)


func test_stop_cancels_attack() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	var enemy: Unit = _unit(Vector3(0, 0, -30), 1)
	_queue.push(AttackCommand.new(0, [unit], enemy))
	_tick([unit], 80)
	assert_true(unit.orders.is_engaged())
	_queue.push(StopCommand.new(0, [unit]))
	_tick([unit], 1)
	assert_true(unit.orders.is_idle())
	assert_false(unit.orders.is_engaged())
	assert_false(unit.locomotion.is_facing())


func test_cannot_attack_own_faction_or_from_other_faction() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	var friend: Unit = _unit(Vector3(0, 0, -30))
	var enemy: Unit = _unit(Vector3(0, 0, -30), 1)
	_queue.push(AttackCommand.new(0, [unit], friend))
	_queue.push(AttackCommand.new(1, [unit], enemy))
	_queue.flush()
	assert_true(unit.orders.is_idle())


func test_engage_offsets_are_on_the_near_side_at_range() -> void:
	var starts: PackedVector3Array = PackedVector3Array(
		[Vector3(-2, 0, 30), Vector3(0, 0, 30), Vector3(2, 0, 30)]
	)
	var offsets: PackedVector3Array = AttackCommand.engage_offsets(Vector3.ZERO, starts, 10.0, 2.0)
	for i: int in offsets.size():
		assert_almost_eq(offsets[i].length(), 10.0, 1e-4)
		assert_gt(offsets[i].z, 9.0, "on the side the group comes from")
	assert_lt(offsets[0].x, offsets[1].x, "left-to-right order kept")
	assert_lt(offsets[1].x, offsets[2].x, "left-to-right order kept")


func test_fast_unit_does_not_slide_inside_engagement_distance() -> void:
	var fast: UnitDef = UnitDef.new()
	fast.move_speed = 13.0
	fast.acceleration = 18.0
	fast.turn_speed = 720.0
	fast.radius = 0.6
	var unit: Unit = Unit.new()
	unit.def = fast
	unit.add_child(Locomotion.new())
	unit.add_child(UnitOrders.new())
	add_child_autofree(unit)
	unit.locomotion.setup(fast, Vector3.ZERO, 0.0, PathService.new(), null)
	var enemy: Unit = _unit(Vector3(0, 0, -60), 1)
	_queue.push(AttackCommand.new(0, [unit], enemy))
	_tick([unit], 100)
	assert_true(unit.orders.is_engaged())
	var distance: float = _flat_distance(unit.locomotion.mover.position, Vector3(0, 0, -60))
	assert_between(distance, AttackCommand.ENGAGE_RANGE - 0.5, AttackCommand.ENGAGE_RANGE + 1.0)
