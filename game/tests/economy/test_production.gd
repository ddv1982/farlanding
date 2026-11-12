extends GutTest
## Production queues: pay on queue, the queue limit, cancel and refund, low-power
## slowdown, finished units at the door and the rally point. Through real commands.

var _f: EconomyFixture
var _barracks: Building


func before_each() -> void:
	_f = EconomyFixture.new(self)
	_f.world.spawn_building(_f.lander, 0, Vector3(-30, 0, 0), true)
	_barracks = _f.world.spawn_building(_f.barracks, 0, Vector3.ZERO, true)
	_f.tick()


func after_each() -> void:
	_f.dispose()


func _queue(def: UnitDef) -> ProduceCommand:
	var command: ProduceCommand = ProduceCommand.new(0, _barracks, def)
	_f.push(command)
	_f.tick()
	return command


func test_queueing_pays_and_starts_production() -> void:
	watch_signals(Events)
	_queue(_f.ranger)
	assert_eq(_barracks.producer.queue.size(), 1)
	assert_eq(_f.pile().alloy, 925)
	assert_signal_emitted_with_parameters(Events, "production_started", [_barracks, _f.ranger])
	assert_true(_barracks.is_producing)


func test_only_the_first_queued_unit_starts() -> void:
	_queue(_f.ranger)
	watch_signals(Events)
	_queue(_f.ranger)
	assert_signal_not_emitted(Events, "production_started")
	assert_eq(_f.pile().alloy, 850)


func test_the_queue_holds_five() -> void:
	for i: int in 5:
		_queue(_f.ranger)
	var sixth: ProduceCommand = _queue(_f.ranger)
	assert_eq(sixth.failure, Producer.QUEUE_FULL)
	assert_eq(_barracks.producer.queue.size(), 5)
	assert_eq(_f.pile().alloy, 1000 - 5 * 75, "the sixth was not paid for")


func test_unaffordable_unit_is_not_queued_and_alerts() -> void:
	_f.pile().alloy = 50
	watch_signals(Events)
	var command: ProduceCommand = _queue(_f.ranger)
	assert_eq(command.failure, &"insufficient_resources")
	assert_eq(_barracks.producer.queue.size(), 0)
	assert_eq(_f.pile().alloy, 50)
	assert_signal_emitted_with_parameters(Events, "advisor_alert", [&"insufficient_resources"])


func test_a_type_the_building_does_not_make_is_refused() -> void:
	var command: ProduceCommand = _queue(_f.hauler)
	assert_eq(command.failure, Producer.NOT_PRODUCIBLE)
	assert_eq(_f.pile().alloy, 1000)


func test_cancel_removes_the_last_and_refunds_it() -> void:
	_queue(_f.ranger)
	_queue(_f.ranger)
	_f.tick(20)
	var elapsed: float = _barracks.producer.elapsed
	_f.push(CancelProductionCommand.new(0, _barracks, _f.ranger))
	_f.tick()
	assert_eq(_barracks.producer.queue.size(), 1)
	assert_eq(_f.pile().alloy, 925, "refunded in full")
	assert_gt(_barracks.producer.elapsed, elapsed, "work on the first one kept")
	_f.push(CancelProductionCommand.new(0, _barracks, _f.ranger))
	_f.tick()
	assert_eq(_barracks.producer.queue.size(), 0)
	assert_eq(_barracks.producer.elapsed, 0.0, "cancelling the one in progress drops its work")
	assert_eq(_f.pile().alloy, 1000)


func test_a_finished_unit_appears_at_the_door_and_announces_itself() -> void:
	_queue(_f.ranger)
	watch_signals(Events)
	_f.tick(95)
	assert_signal_not_emitted(Events, "production_completed")
	_f.tick(6)
	assert_signal_emitted(Events, "production_completed")
	assert_signal_emitted_with_parameters(Events, "advisor_alert", [&"unit_ready"])
	var rangers: Array[Unit] = []
	for unit: Unit in _f.world.units:
		if unit.def == _f.ranger:
			rangers.append(unit)
	assert_eq(rangers.size(), 1)
	var at: Vector3 = rangers[0].sim_position()
	assert_lt(at.distance_to(_barracks.door_position()), 1.0, "spawned at the door")
	assert_false(_barracks.is_producing)


func test_the_next_queued_unit_starts_when_one_finishes() -> void:
	_queue(_f.ranger)
	_queue(_f.ranger)
	watch_signals(Events)
	_f.tick(101)
	assert_signal_emitted_with_parameters(Events, "production_started", [_barracks, _f.ranger])
	assert_eq(_barracks.producer.queue.size(), 1)


func test_units_walk_to_the_rally_point() -> void:
	var rally: Vector3 = Vector3(20, 0, -20)
	_f.push(RallyCommand.new(0, [_barracks] as Array[Node3D], rally))
	_queue(_f.ranger)
	_f.tick(101)
	assert_true(_barracks.producer.has_rally_point)
	_f.tick(100)
	var ranger: Unit = _f.world.units[_f.world.units.size() - 1]
	assert_lt(ranger.sim_position().distance_to(rally), 0.5)


func test_low_power_halves_production_speed() -> void:
	_f.world.spawn_building(_f.tap, 0, Vector3(30, 0, 0), true)
	_f.world.spawn_building(_f.barracks, 0, Vector3(0, 0, 30), true)
	_f.tick()
	assert_true(_f.pile().is_low_power(), "4 + 4 + 3 used > 10 produced")
	_queue(_f.ranger)
	_f.tick(100)
	assert_almost_eq(_barracks.producer.progress(), 0.5, 0.02)
	_f.world.spawn_building(_f.reactor, 0, Vector3(-30, 0, 30), true)
	_f.tick(51)
	assert_eq(_barracks.producer.queue.size(), 0, "full speed again once power is restored")


func test_an_unfinished_building_cannot_produce() -> void:
	var site: Building = _f.world.spawn_building(_f.barracks, 0, Vector3(0, 0, 40), false)
	var command: ProduceCommand = ProduceCommand.new(0, site, _f.ranger)
	_f.push(command)
	_f.tick()
	assert_eq(command.failure, Producer.NOT_PRODUCIBLE)
	assert_eq(_f.pile().alloy, 1000)


func test_producer_round_trip() -> void:
	var ranger: UnitDef = load("res://data/units/concord_ranger.tres")
	var producer: Producer = Producer.new()
	autofree(producer)
	producer.setup([ranger] as Array[UnitDef], 5)
	producer.push(ranger)
	producer.push(ranger)
	producer.tick(3.0)
	producer.set_rally_point(Vector3(5, 0, 5))
	var copy: Producer = Producer.new()
	autofree(copy)
	copy.setup([ranger] as Array[UnitDef], 5)
	copy.from_dict(producer.to_dict())
	assert_eq(copy.queue, [ranger, ranger] as Array[UnitDef])
	assert_eq(copy.rally_point, Vector3(5, 0, 5))
	assert_true(copy.has_rally_point)
	assert_almost_eq(copy.elapsed, 3.0, 0.001)
