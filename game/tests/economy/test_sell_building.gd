extends GutTest
## All sales enter through the real command queue; no frames are awaited so the
## snapshot checks cover the gap before queue_free is processed.

var _f: EconomyFixture


func before_each() -> void:
	_f = EconomyFixture.new(self)


func after_each() -> void:
	_f.dispose()


func _sell(building: Building, issuer: int = 0) -> SellBuildingCommand:
	var command := SellBuildingCommand.new(issuer, building)
	_f.push(command)
	_f.tick()
	return command


func test_completed_refund_rounds_down_both_resources_and_never_damages() -> void:
	_f.reactor.cost_alloy = 151
	_f.reactor.cost_flux = 31
	var building: Building = _f.world.spawn_building(_f.reactor, 0, Vector3.ZERO, true)
	_f.world.economy.pay(0, _f.reactor)
	watch_signals(building.health)
	watch_signals(Events)
	assert_eq(SellBuildingCommand.refund_for(building), Vector2i(75, 15))
	assert_true(_sell(building).sold)
	assert_eq(_f.pile().alloy, 924)
	assert_eq(_f.pile().flux, 84)
	assert_signal_not_emitted(building.health, "died")
	assert_signal_not_emitted(Events, "entity_damaged")
	assert_true(building.is_sold)
	assert_false(building.is_operational())


func test_duplicate_commands_and_reexecution_refund_only_once() -> void:
	var building: Building = _f.world.spawn_building(_f.reactor, 0, Vector3.ZERO, true)
	var first := SellBuildingCommand.new(0, building)
	var duplicate := SellBuildingCommand.new(0, building)
	_f.push(first)
	_f.push(duplicate)
	assert_eq(_f.pile().alloy, 1000, "pushing does not sell before the tick")
	_f.tick()
	assert_true(first.sold)
	assert_false(duplicate.sold)
	first.execute()
	assert_eq(_f.pile().alloy, 1075)
	assert_false(SellBuildingCommand.can_sell(building, 0))


func test_foreign_lander_nonplaceable_and_machine_buildings_are_protected() -> void:
	var foreign: Building = _f.world.spawn_building(_f.reactor, 1, Vector3.ZERO, true)
	assert_false(_sell(foreign).sold)
	var lander: Building = _f.world.spawn_building(_f.lander, 0, Vector3(20, 0, 0), true)
	assert_false(_sell(lander).sold, "even an accidentally placeable Lander is protected")
	_f.refinery.placeable = false
	var story: Building = _f.world.spawn_building(_f.refinery, 0, Vector3(40, 0, 0), true)
	assert_false(_sell(story).sold)
	_f.barracks.machine = true
	var engine: Building = _f.world.spawn_building(_f.barracks, 0, Vector3(60, 0, 0), true)
	assert_false(_sell(engine).sold)
	assert_eq(_f.pile().alloy, 1000)
	assert_eq(_f.world.buildings.size(), 4)


func test_dead_building_cannot_be_sold() -> void:
	var building: Building = _f.world.spawn_building(_f.reactor, 0, Vector3.ZERO, true)
	building.health.take(100000)
	assert_false(_sell(building).sold)
	assert_eq(_f.pile().alloy, 1000)


func test_queued_units_are_cancelled_using_existing_refund_policy() -> void:
	_f.rules.cancel_refund = 0.5
	_f.ranger.cost_flux = 7
	var building: Building = _f.world.spawn_building(_f.barracks, 0, Vector3.ZERO, true)
	_f.push(ProduceCommand.new(0, building, _f.ranger))
	_f.push(ProduceCommand.new(0, building, _f.ranger))
	_f.tick()
	assert_eq(SellBuildingCommand.refund_for(building), Vector2i(174, 6))
	_f.push(SellBuildingCommand.new(0, building))
	_f.push(ProduceCommand.new(0, building, _f.ranger))
	_f.tick()
	assert_eq(_f.pile().alloy, 1024, "850 + 100 building + twice floor(75 / 2)")
	assert_eq(_f.pile().flux, 92)
	assert_true(building.producer.queue.is_empty())
	assert_true(_f.world.units.is_empty())


func test_sale_releases_vent_navigation_power_and_snapshot_before_removal_event() -> void:
	var vent: ResourceNode = _f.world.spawn_resource_node(_f.vent, Vector3.ZERO)
	var building: Building = _f.world.spawn_building(_f.tap, 0, Vector3.ZERO, true)
	_f.tick()
	assert_eq(vent.tap, building)
	assert_true(_f.world.paths.is_blocked(Vector3.ZERO))
	assert_eq(_f.pile().power_used, 3)
	var snapshots: Array[Dictionary] = []
	var listener: Callable = func(entity: Node3D) -> void:
		if entity == building:
			snapshots.append(_f.world.to_dict())
	Events.entity_died.connect(listener)
	_sell(building)
	Events.entity_died.disconnect(listener)
	assert_null(vent.tap)
	assert_false(_f.world.paths.is_blocked(Vector3.ZERO))
	assert_eq(_f.pile().power_used, 0)
	assert_null(_f.world.entity(building.entity_id))
	assert_false(_f.world.buildings.has(building))
	assert_eq(snapshots.size(), 1)
	var during_removal: Array = snapshots[0]["buildings"]
	var after_removal: Array = _f.world.to_dict()["buildings"]
	assert_true(during_removal.is_empty())
	assert_true(after_removal.is_empty())
	var replacement: Building = _f.world.spawn_building(_f.tap, 0, Vector3.ZERO, true)
	assert_eq(vent.tap, replacement, "the vent can be reclaimed immediately")


func test_construction_cancellation_returns_full_cost_and_releases_builders() -> void:
	_f.reactor.cost_flux = 21
	var builder: Unit = _f.world.spawn_unit(_f.fabricator, 0, Vector3(0, 0, 8))
	var place := PlaceBuildingCommand.new(0, [builder] as Array[Node3D], _f.reactor, Vector3.ZERO)
	_f.push(place)
	_f.tick()
	var site: Building = place.placed
	assert_not_null(site)
	assert_eq(_f.pile().alloy, 850)
	assert_eq(_f.pile().flux, 79)
	assert_true(site.is_under_construction)
	assert_eq(SellBuildingCommand.refund_for(site), Vector2i(150, 21))
	_sell(site)
	assert_eq(_f.pile().alloy, 1000)
	assert_eq(_f.pile().flux, 100)
	assert_false(_f.world.paths.is_blocked(Vector3.ZERO))
	assert_true(builder.orders.is_idle())


func test_selling_power_source_updates_power_immediately() -> void:
	var reactor: Building = _f.world.spawn_building(_f.reactor, 0, Vector3.ZERO, true)
	_f.tick()
	assert_eq(_f.pile().power_produced, 15)
	_sell(reactor)
	assert_eq(_f.pile().power_produced, 0)


func test_refund_and_unregistration_precede_resource_and_power_notifications() -> void:
	var building: Building = _f.world.spawn_building(_f.reactor, 0, Vector3.ZERO, true)
	_f.tick()
	var snapshots: Array[Dictionary] = []
	var listener: Callable = func(_faction: int, _a: int, _b: int) -> void:
		snapshots.append(_f.world.to_dict())
	Events.resources_changed.connect(listener)
	Events.power_changed.connect(listener)
	_sell(building)
	Events.resources_changed.disconnect(listener)
	Events.power_changed.disconnect(listener)
	assert_eq(snapshots.size(), 2)
	for snapshot: Dictionary in snapshots:
		var buildings: Array = snapshot["buildings"]
		var economy: Dictionary = snapshot["economy"]
		var stockpiles: Dictionary = economy["stockpiles"]
		var pile: Dictionary = stockpiles["0"]
		assert_true(buildings.is_empty())
		var alloy: int = pile["alloy"]
		var power: int = pile["power_produced"]
		assert_eq(alloy, 1075)
		assert_eq(power, 0)
