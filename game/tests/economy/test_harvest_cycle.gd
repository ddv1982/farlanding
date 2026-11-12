extends GutTest
## The harvest cycle: to_deposit -> mining -> to_dock -> unloading -> to_deposit,
## delivery into the stockpile, drop-off choice, depletion and moving on.

var _f: EconomyFixture
var _lander: Building


func before_each() -> void:
	_f = EconomyFixture.new(self)
	_lander = _f.world.spawn_building(_f.lander, 0, Vector3.ZERO, true)


func after_each() -> void:
	_f.dispose()


func _hauler(at: Vector3 = Vector3(10, 0, 10)) -> Unit:
	return _f.world.spawn_unit(_f.hauler, 0, at)


func _harvest(hauler: Unit, deposit: ResourceNode) -> void:
	_f.push(HarvestCommand.new(0, [hauler] as Array[Node3D], deposit))
	_f.tick()


## Ticks until `hauler` has made `count` deliveries; returns the states it passed.
func _run_until_deliveries(hauler: Unit, count: int, limit: int = 2000) -> Array[StringName]:
	var states: Array[StringName] = [hauler.harvester.state]
	for i: int in limit:
		if hauler.harvester.deliveries >= count:
			break
		_f.tick()
		if hauler.harvester.state != states[states.size() - 1]:
			states.append(hauler.harvester.state)
	return states


func test_a_round_trip_passes_every_state_in_order() -> void:
	var deposit: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 0))
	var hauler: Unit = _hauler()
	_harvest(hauler, deposit)
	var states: Array[StringName] = _run_until_deliveries(hauler, 2)
	assert_eq(
		states.slice(0, 6),
		(
			[
				Harvester.STATE_TO_DEPOSIT,
				Harvester.STATE_MINING,
				Harvester.STATE_TO_DOCK,
				Harvester.STATE_UNLOADING,
				Harvester.STATE_TO_DEPOSIT,
				Harvester.STATE_MINING,
			]
			as Array[StringName]
		)
	)


func test_two_trips_deliver_two_loads() -> void:
	var deposit: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 0))
	var hauler: Unit = _hauler()
	watch_signals(Events)
	_harvest(hauler, deposit)
	_run_until_deliveries(hauler, 2)
	assert_eq(hauler.harvester.deliveries, 2)
	assert_eq(_f.pile().alloy, 1100)
	assert_eq(deposit.remaining, 100)
	assert_signal_emit_count(Events, "harvest_delivered", 2)
	assert_signal_emitted_with_parameters(Events, "harvest_delivered", [hauler, 50])


func test_mining_is_reported_while_at_the_deposit() -> void:
	var deposit: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 0))
	var hauler: Unit = _hauler()
	_harvest(hauler, deposit)
	for i: int in 400:
		if hauler.harvester.state == Harvester.STATE_MINING:
			break
		_f.tick()
	assert_true(hauler.is_harvesting)
	assert_eq(hauler.harvester.cargo, 0, "the load is taken when mining ends")


func test_a_refinery_is_preferred_over_the_lander() -> void:
	var refinery: Building = _f.world.spawn_building(_f.refinery, 0, Vector3(60, 0, 0), true)
	assert_eq(_f.world.nearest_dropoff(0, Vector3(5, 0, 0)), refinery, "even when further away")
	var site: Building = _f.world.spawn_building(_f.refinery, 0, Vector3(10, 0, 30), false)
	assert_eq(
		_f.world.nearest_dropoff(0, Vector3(10, 0, 25)), refinery, "not one under construction"
	)
	site.free()
	refinery.free()
	assert_eq(_f.world.nearest_dropoff(0, Vector3(5, 0, 0)), _lander, "the Lander stands in")
	assert_null(_f.world.nearest_dropoff(1, Vector3.ZERO), "never another faction's")


func test_a_hauler_waits_while_there_is_no_dropoff() -> void:
	_lander.free()
	var deposit: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 0))
	var hauler: Unit = _hauler()
	_harvest(hauler, deposit)
	for i: int in 300:
		_f.tick()
	assert_eq(hauler.harvester.state, Harvester.STATE_WAITING)
	assert_eq(hauler.harvester.cargo, 50)
	_f.world.spawn_building(_f.refinery, 0, Vector3(30, 0, 20), true)
	_run_until_deliveries(hauler, 1)
	assert_eq(_f.pile().alloy, 1050, "delivers once a drop-off exists")


func test_depletion_is_announced_and_the_hauler_moves_on() -> void:
	var first: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 0))
	var second: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 30))
	var hauler: Unit = _hauler()
	watch_signals(Events)
	_harvest(hauler, first)
	_run_until_deliveries(hauler, 5)
	assert_signal_emitted(Events, "resource_depleted")
	assert_signal_emitted_with_parameters(Events, "advisor_alert", [&"deposit_depleted"])
	assert_true(first.is_queued_for_deletion(), "the empty deposit is taken off the map")
	assert_eq(hauler.harvester.deposit, second)
	assert_eq(_f.pile().alloy, 1250)


func test_the_order_ends_when_nothing_is_left_nearby() -> void:
	var only: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 0))
	var hauler: Unit = _hauler()
	_harvest(hauler, only)
	_run_until_deliveries(hauler, 4)
	_f.tick(10)
	assert_true(hauler.orders.is_idle())
	assert_eq(_f.pile().alloy, 1200)


func test_a_move_order_stops_harvesting() -> void:
	var deposit: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 0))
	var hauler: Unit = _hauler()
	_harvest(hauler, deposit)
	_f.tick(20)
	_f.push(
		MoveCommand.new(MoveCommand.KIND_MOVE, 0, [hauler] as Array[Node3D], Vector3(-20, 0, 20))
	)
	_f.tick()
	assert_eq(hauler.orders.current.kind, MoveCommand.KIND_MOVE)
	assert_eq(hauler.harvester.state, Harvester.STATE_IDLE)


func test_new_haulers_find_the_nearest_deposit_themselves() -> void:
	_f.world.spawn_resource_node(_f.deposit, Vector3(50, 0, 0))
	var near: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(20, 0, 0))
	var hauler: Unit = _hauler(Vector3(10, 0, 0))
	assert_true(_f.world.auto_harvest(hauler, hauler.sim_position()))
	assert_eq(hauler.harvester.deposit, near)


func test_a_flux_tap_adds_flux_on_a_timer() -> void:
	_f.world.spawn_building(_f.tap, 0, Vector3(30, 0, 30), true)
	_f.tick(41)
	assert_eq(_f.pile().flux, 105, "5 Flux every 4 s")


func test_harvester_state_round_trip() -> void:
	var deposit: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 0))
	var hauler: Unit = _hauler()
	_harvest(hauler, deposit)
	_run_until_deliveries(hauler, 1)
	var data: Dictionary = hauler.to_dict()
	var copy: Unit = _f.world.spawn_unit(_f.hauler, 0, Vector3(-20, 0, 0))
	copy.from_dict(data)
	assert_eq(copy.harvester.state, hauler.harvester.state)
	assert_eq(copy.harvester.deliveries, 1)
	assert_eq(copy.orders.current.target_id, deposit.entity_id)
