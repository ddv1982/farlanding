extends GutTest
## Construction: placing pays and makes a site, builders finish it, several builders
## build faster, low power slows it, a Refinery comes with a Hauler.

var _f: EconomyFixture


func before_each() -> void:
	_f = EconomyFixture.new(self)
	_f.world.spawn_building(_f.lander, 0, Vector3(-40, 0, 0), true)


func after_each() -> void:
	_f.dispose()


## `count` builders standing 12 m south of `near`.
func _builders(count: int, near: Vector3 = Vector3.ZERO) -> Array[Node3D]:
	var builders: Array[Node3D] = []
	for i: int in count:
		builders.append(_f.world.spawn_unit(_f.fabricator, 0, near + Vector3(i * 2.0, 0, 12)))
	return builders


func _place(def: BuildingDef, at: Vector3, builders: Array[Node3D]) -> Building:
	var command: PlaceBuildingCommand = PlaceBuildingCommand.new(0, builders, def, at)
	_f.push(command)
	_f.tick()
	return command.placed


## Ticks until `site` is finished; returns how many ticks that took (or -1).
func _ticks_to_finish(site: Building, limit: int = 600) -> int:
	for i: int in limit:
		if site.is_operational():
			return i
		_f.tick()
	return -1


func test_several_builders_add_up() -> void:
	var construction: Construction = Construction.new()
	autofree(construction)
	construction.start(10.0, false)
	construction.add_work(0.1)
	construction.add_work(0.1)
	construction.end_tick()
	assert_almost_eq(construction.progress(), 0.02, 0.0001)
	assert_eq(construction.builders, 2)
	construction.add_work(100.0)
	assert_true(construction.is_complete())
	assert_eq(construction.progress(), 1.0, "never past done")


func test_placing_pays_and_makes_a_site() -> void:
	watch_signals(Events)
	var site: Building = _place(_f.reactor, Vector3.ZERO, _builders(1))
	assert_not_null(site)
	assert_true(site.is_under_construction)
	assert_false(site.is_operational())
	assert_eq(_f.pile().alloy, 850)
	assert_signal_emitted_with_parameters(Events, "building_placed", [site])
	assert_signal_emitted_with_parameters(Events, "advisor_alert", [&"building_placed"])


func test_builder_finishes_the_site() -> void:
	var site: Building = _place(_f.reactor, Vector3.ZERO, _builders(1))
	watch_signals(Events)
	assert_gt(_ticks_to_finish(site), 0)
	assert_signal_emitted_with_parameters(Events, "construction_completed", [site])
	assert_signal_emitted_with_parameters(Events, "advisor_alert", [&"construction_complete"])
	assert_eq(_f.pile().power_produced, 25, "the Reactor adds its power once finished")


func test_two_builders_build_about_twice_as_fast() -> void:
	var one: int = _ticks_to_finish(_place(_f.reactor, Vector3.ZERO, _builders(1)))
	var at: Vector3 = Vector3(0, 0, 40)
	var two: int = _ticks_to_finish(_place(_f.reactor, at, _builders(2, at)))
	assert_gt(one, 0)
	assert_gt(two, 0)
	# Both include the same short walk, so the ratio is a little under 2.
	assert_between(float(one) / two, 1.6, 2.1)


func test_a_builder_can_be_sent_to_help() -> void:
	var builders: Array[Node3D] = _builders(1)
	var site: Building = _place(_f.reactor, Vector3.ZERO, builders)
	var helper: Unit = _f.world.spawn_unit(_f.fabricator, 0, Vector3(-6, 0, 12))
	_f.push(BuildCommand.new(0, [helper] as Array[Node3D], site))
	_f.tick(40)
	assert_eq(helper.orders.current.kind, Builder.KIND)
	assert_eq(site.construction.builders, 2)


func test_invalid_spot_is_refused_and_not_paid() -> void:
	_place(_f.reactor, Vector3.ZERO, _builders(1))
	watch_signals(Events)
	var second: Building = _place(_f.reactor, Vector3(2, 0, 0), _builders(1))
	assert_null(second)
	assert_eq(_f.pile().alloy, 850, "only the first was paid")
	assert_signal_emitted_with_parameters(Events, "ui_feedback", [&"placement_invalid"])


func test_unaffordable_placement_places_nothing() -> void:
	_f.pile().alloy = 100
	var site: Building = _place(_f.reactor, Vector3.ZERO, _builders(1))
	assert_null(site)
	assert_eq(_f.pile().alloy, 100)


func test_low_power_slows_construction() -> void:
	var first: Building = _place(_f.reactor, Vector3.ZERO, _builders(1))
	var full: int = _ticks_to_finish(first)
	first.free()
	_f.world.spawn_building(_f.barracks, 0, Vector3(40, 0, 0), true)
	_f.world.spawn_building(_f.barracks, 0, Vector3(40, 0, 40), true)
	_f.world.spawn_building(_f.tap, 0, Vector3(40, 0, -40), true)
	_f.tick()
	assert_true(_f.pile().is_low_power(), "4 + 4 + 3 used > 10 produced")
	var at: Vector3 = Vector3(0, 0, -40)
	var low: int = _ticks_to_finish(_place(_f.reactor, at, _builders(1, at)))
	assert_between(float(low) / full, 1.6, 2.1)


func test_a_refinery_comes_with_a_hauler() -> void:
	var site: Building = _place(_f.refinery, Vector3.ZERO, _builders(2))
	var before: int = _f.world.units.size()
	_ticks_to_finish(site)
	_f.tick()
	assert_eq(_f.world.units.size(), before + 1)
	assert_eq(_f.world.units[_f.world.units.size() - 1].def, _f.hauler)


func test_buildings_block_the_area_they_stand_on() -> void:
	var site: Building = _place(_f.reactor, Vector3.ZERO, _builders(1))
	assert_false(_f.world.paths.is_walkable(Vector3.ZERO), "a site blocks at once")
	assert_true(_f.world.paths.is_walkable(Vector3(10, 0, 0)))
	site.free()
	assert_true(_f.world.paths.is_walkable(Vector3.ZERO), "unblocked when it is gone")


func test_building_round_trip() -> void:
	var site: Building = _place(_f.reactor, Vector3.ZERO, _builders(1))
	_f.tick(30)
	var data: Dictionary = site.to_dict()
	var copy: Building = Building.new()
	copy.def = _f.reactor
	copy.setup(false)
	autofree(copy)
	copy.from_dict(data)
	assert_almost_eq(copy.construction.work, site.construction.work, 0.0001)
	assert_eq(copy.entity_id, site.entity_id)


func _inside(site: Building, unit: Unit) -> bool:
	var at: Vector3 = unit.sim_position()
	return site.footprint().has_point(Vector2(at.x, at.z))


func test_a_busy_unit_standing_on_a_new_site_walks_out_first() -> void:
	var walker: Unit = _f.world.spawn_unit(_f.ranger, 0, Vector3.ZERO)
	var enemy: Unit = _f.world.spawn_unit(_f.ranger, 1, Vector3(0, 0, -8))
	# Holding an attack never ends by itself, so a queued evacuation would wait forever.
	_f.push(AttackCommand.new(0, [walker], enemy))
	_f.tick(5)
	var site: Building = _place(_f.reactor, Vector3.ZERO, _builders(1))
	_f.tick(60)
	assert_false(_inside(site, walker), "left the footprint")
	assert_eq(walker.orders.current.kind, AttackCommand.KIND, "then resumed its order")


func test_an_idle_fabricator_standing_on_a_new_site_walks_out() -> void:
	var idle: Unit = _f.world.spawn_unit(_f.fabricator, 0, Vector3.ZERO)
	var site: Building = _place(_f.reactor, Vector3.ZERO, _builders(1))
	_f.tick(60)
	assert_false(_inside(site, idle), "left the footprint")
