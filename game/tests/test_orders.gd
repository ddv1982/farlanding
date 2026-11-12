extends GutTest
## Commands → orders → locomotion, with the straight-line PathService and no terrain.

const DT: float = 0.1

var _def: UnitDef
var _queue: CommandQueue


func before_each() -> void:
	_def = UnitDef.new()
	_def.move_speed = 5.0
	_def.acceleration = 20.0
	_def.turn_speed = 720.0
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


func test_move_command_has_kind_and_target() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	var command: MoveCommand = MoveCommand.new(
		MoveCommand.KIND_ATTACK_MOVE, 0, [unit], Vector3(1, 0, 2), true
	)
	assert_eq(command.kind, &"attack_move")
	assert_eq(command.target_position, Vector3(1, 0, 2))
	assert_true(command.queued)
	assert_eq(command.entities, [unit] as Array[Node3D])


func test_move_does_nothing_until_tick() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(0, 0, -10)))
	assert_true(unit.orders.is_idle())
	_queue.flush()
	assert_false(unit.orders.is_idle())
	assert_eq(unit.orders.current.kind, MoveCommand.KIND_MOVE)


func test_group_arrives_in_formation() -> void:
	var units: Array[Unit] = []
	for i: int in 6:
		units.append(_unit(Vector3(i * 1.5, 0, 0)))
	var entities: Array[Node3D] = []
	entities.assign(units)
	var target: Vector3 = Vector3(0, 0, -40)
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, entities, target))
	_tick(units, 200)
	var centre: Vector3 = Vector3.ZERO
	for unit: Unit in units:
		assert_true(unit.orders.is_idle(), "every unit finished")
		assert_eq(unit.locomotion.mover.speed, 0.0)
		centre += unit.locomotion.mover.position
	assert_almost_eq(centre / 6.0, target, Vector3.ONE * 0.01, "formation centred on target")
	for i: int in units.size():
		for j: int in range(i + 1, units.size()):
			var a: Vector3 = units[i].locomotion.mover.position
			var b: Vector3 = units[j].locomotion.mover.position
			assert_gt(a.distance_to(b), 1.9, "not piled up")


func test_queued_waypoints_run_in_order() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	var units: Array[Unit] = [unit]
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(0, 0, -10)))
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(10, 0, -10), true))
	_queue.flush()
	assert_eq(unit.orders.queue.size(), 1)
	_tick(units, 30)
	assert_eq(unit.orders.current.target_position, Vector3(10, 0, -10), "moved on to waypoint 2")
	_tick(units, 60)
	assert_true(unit.orders.is_idle())
	assert_almost_eq(unit.locomotion.mover.position, Vector3(10, 0, -10), Vector3.ONE * 1e-3)


func test_unqueued_move_replaces_queue() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(0, 0, -10)))
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(10, 0, -10), true))
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(-5, 0, 0)))
	_queue.flush()
	assert_eq(unit.orders.queue.size(), 0)
	assert_eq(unit.orders.current.target_position, Vector3(-5, 0, 0))


func test_stop_halts_and_clears() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	var units: Array[Unit] = [unit]
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(0, 0, -50)))
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(9, 0, 0), true))
	_tick(units, 10)
	assert_gt(unit.locomotion.mover.speed, 0.0)
	_queue.push(StopCommand.new(0, [unit]))
	_tick(units, 10)
	assert_true(unit.orders.is_idle())
	assert_eq(unit.orders.queue.size(), 0)
	assert_eq(unit.locomotion.mover.speed, 0.0)


func test_orders_for_other_factions_units_are_ignored() -> void:
	var enemy: Unit = _unit(Vector3.ZERO, 1)
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [enemy], Vector3(0, 0, -10)))
	_queue.flush()
	assert_true(enemy.orders.is_idle())


func test_motion_changed_reports_speed() -> void:
	var unit: Unit = _unit(Vector3.ZERO)
	watch_signals(unit.locomotion)
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(0, 0, -10)))
	_tick([unit] as Array[Unit], 3)
	assert_signal_emitted(unit.locomotion, "motion_changed")


## Records every path request so tests can check the backend is the one given.
class CountingPaths:
	extends PathService

	var requests: int = 0

	func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
		requests += 1
		return super(from, to)


func test_locomotion_uses_the_given_path_service() -> void:
	var counting: CountingPaths = CountingPaths.new()
	var unit: Unit = Unit.new()
	unit.def = _def
	unit.add_child(Locomotion.new())
	unit.add_child(UnitOrders.new())
	add_child_autofree(unit)
	unit.locomotion.setup(_def, Vector3.ZERO, 0.0, counting, null)
	assert_eq(unit.locomotion.paths, counting as PathService)
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(0, 0, -10)))
	_queue.flush()
	assert_eq(counting.requests, 1, "one path request per order")


class DoglegPaths:
	extends PathService
	var requests: int = 0

	func find_path(_from: Vector3, to: Vector3) -> PackedVector3Array:
		requests += 1
		return PackedVector3Array([Vector3(0, 0, -2), to])


func test_long_leg_after_a_near_corner_is_not_treated_as_stuck() -> void:
	var paths: DoglegPaths = DoglegPaths.new()
	var unit: Unit = Unit.new()
	unit.def = _def
	unit.add_child(Locomotion.new())
	unit.add_child(UnitOrders.new())
	add_child_autofree(unit)
	unit.locomotion.setup(_def, Vector3.ZERO, 0.0, paths, null)
	_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], Vector3(0, 0, -40)))
	_tick([unit], 120)
	assert_eq(paths.requests, 1, "steady progress must not trigger a repath")
	assert_almost_eq(unit.locomotion.mover.position.z, -40.0, 0.5)


class GappyPaths:
	extends PathService

	func find_path(_from: Vector3, to: Vector3) -> PackedVector3Array:
		return PackedVector3Array() if to.x > 100.0 else PackedVector3Array([to])


func test_unreachable_waypoint_does_not_drop_the_rest_of_the_queue() -> void:
	var unit: Unit = Unit.new()
	unit.def = _def
	unit.add_child(Locomotion.new())
	unit.add_child(UnitOrders.new())
	add_child_autofree(unit)
	unit.locomotion.setup(_def, Vector3.ZERO, 0.0, GappyPaths.new(), null)
	for target: Vector3 in [Vector3(0, 0, -5), Vector3(500, 0, 0), Vector3(0, 0, -10)]:
		var command: MoveCommand = MoveCommand.new(MoveCommand.KIND_MOVE, 0, [unit], target)
		command.queued = target.z != -5.0
		_queue.push(command)
	_tick([unit], 80)
	assert_almost_eq(unit.locomotion.mover.position.z, -10.0, 0.5)
