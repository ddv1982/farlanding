extends GutTest
## Survey Lab field options: paid in Intel, cooldowns, unlocks, and their effects.

var _f: DiscoveryFixture
var _lab: Building


func before_each() -> void:
	_f = DiscoveryFixture.new(self, true)
	_lab = _f.world.spawn_building(_f.lab, 0, Vector3(-60, 0, -60), true)


func after_each() -> void:
	_f.dispose()


func _use(option: FieldOptionDef, at: Vector3) -> FieldOptionCommand:
	var command: FieldOptionCommand = FieldOptionCommand.new(0, _lab, option, at)
	_f.push(command)
	_f.tick(1)
	return command


func test_an_option_costs_intel_and_then_cools_down() -> void:
	watch_signals(Events)
	_f.world.economy.add_intel(0, 100)
	var command: FieldOptionCommand = _use(_f.orbital_scan, Vector3(50, 0, 50))
	assert_eq(command.refused, FieldOptions.OK)
	assert_eq(_f.pile().intel, 60)
	assert_signal_emitted_with_parameters(
		Events, "field_option_used", [_f.orbital_scan, 0, Vector3(50, 0, 50)]
	)
	var options: FieldOptions = _f.world.discovery.field_options
	assert_eq(options.check(0, _f.orbital_scan), FieldOptions.COOLDOWN)
	assert_almost_eq(options.cooldown_left(0, _f.orbital_scan), 60.0, 0.2)
	command = _use(_f.orbital_scan, Vector3(50, 0, 50))
	assert_eq(command.refused, FieldOptions.COOLDOWN)
	assert_eq(_f.pile().intel, 60, "nothing paid while cooling down")
	_f.tick(600)
	assert_eq(options.check(0, _f.orbital_scan), FieldOptions.OK)
	assert_signal_emitted_with_parameters(Events, "advisor_alert", [&"field_option_ready"])


func test_not_enough_intel_is_refused() -> void:
	_f.world.economy.add_intel(0, 10)
	var command: FieldOptionCommand = _use(_f.orbital_scan, Vector3.ZERO)
	assert_eq(command.refused, FieldOptions.NO_INTEL)
	assert_eq(_f.pile().intel, 10)


func test_a_locked_option_needs_its_discovery() -> void:
	_f.world.economy.add_intel(0, 500)
	assert_eq(_use(_f.lance, Vector3.ZERO).refused, FieldOptions.LOCKED)
	_f.world.discovery.field_options.unlock(0, &"antecedent_power")
	assert_eq(_use(_f.lance, Vector3(40, 0, 0)).refused, FieldOptions.OK)


func test_only_an_operational_own_lab_can_use_options() -> void:
	_f.world.economy.add_intel(0, 500)
	var site: Building = _f.world.spawn_building(_f.lab, 0, Vector3(40, 0, -60), false)
	var command: FieldOptionCommand = FieldOptionCommand.new(0, site, _f.orbital_scan, Vector3.ZERO)
	_f.push(command)
	_f.tick(1)
	assert_eq(command.refused, FieldOptions.NO_LAB)
	var foreign: FieldOptionCommand = FieldOptionCommand.new(1, _lab, _f.orbital_scan, Vector3.ZERO)
	_f.push(foreign)
	_f.tick(1)
	assert_eq(foreign.refused, FieldOptions.NO_LAB)
	assert_eq(_f.pile().intel, 500)


func test_orbital_scan_reveals_an_area_for_a_while() -> void:
	_f.world.economy.add_intel(0, 100)
	var spot: Vector3 = Vector3(60, 0, 60)
	_f.tick(2)
	assert_false(_f.world.vision.grid.is_visible(0, spot))
	_use(_f.orbital_scan, spot)
	_f.tick(3)
	assert_true(_f.world.vision.grid.is_visible(0, spot))
	assert_true(_f.world.vision.grid.is_visible(0, spot + Vector3(15, 0, 0)))
	_f.tick(110)
	assert_false(_f.world.vision.grid.is_visible(0, spot), "the scan fades")
	assert_true(_f.world.vision.grid.is_explored(0, spot), "but stays explored")


func test_supply_drop_lands_resources() -> void:
	_f.world.economy.add_intel(0, 100)
	var flux: int = _f.pile().flux
	var nodes: int = _f.world.resource_nodes.size()
	_use(_f.supply_drop, Vector3(20, 0, 20))
	assert_eq(_f.pile().flux, flux + 75)
	assert_eq(_f.world.resource_nodes.size(), nodes + 1)
	var dropped: ResourceNode = _f.world.resource_nodes.back()
	assert_eq(dropped.def, _f.rich)


func test_supply_drop_needs_open_ground() -> void:
	_f.world.economy.add_intel(0, 100)
	var command: FieldOptionCommand = _use(_f.supply_drop, _lab.position)
	assert_eq(command.refused, FieldOptions.BAD_TARGET)
	assert_eq(_f.pile().intel, 100)


func test_supply_drop_cannot_land_on_a_discovery_site() -> void:
	_f.world.economy.add_intel(0, 100)
	_f.site(_f.discovery(&"seam"), Vector3(60, 0, 60))
	var command: FieldOptionCommand = _use(_f.supply_drop, Vector3(60, 0, 60))
	assert_eq(command.refused, FieldOptions.BAD_TARGET)
	assert_eq(_f.pile().intel, 100)


func test_the_lance_strikes_everything_hostile_in_its_radius() -> void:
	_f.world.economy.add_intel(0, 200)
	_f.world.discovery.field_options.unlock(0, &"antecedent_power")
	var enemy: Unit = _f.spawn(_f.combat.scout, 1, Vector3(40, 0, 0))
	var outside: Unit = _f.spawn(_f.combat.scout, 1, Vector3(60, 0, 0))
	var own: Unit = _f.spawn(_f.combat.scout, 0, Vector3(42, 0, 0))
	_use(_f.lance, Vector3(40, 0, 0))
	assert_true(enemy.is_dead, "150 heavy damage kills a scout")
	assert_eq(outside.health.current, outside.health.max_health)
	assert_eq(own.health.current, own.health.max_health)


func test_options_save_and_load() -> void:
	_f.world.economy.add_intel(0, 100)
	_f.world.discovery.field_options.unlock(0, &"antecedent_power")
	_use(_f.orbital_scan, Vector3.ZERO)
	var data: Dictionary = _f.world.discovery.field_options.to_dict()
	var copy: FieldOptions = FieldOptions.new(_f.world, 0)
	copy.from_dict(data)
	assert_true(copy.is_unlocked(0, _f.lance))
	assert_gt(copy.cooldown_left(0, _f.orbital_scan), 50.0)


func test_loading_drops_what_was_unlocked_or_used_after_the_save() -> void:
	var options: FieldOptions = _f.world.discovery.field_options
	var data: Dictionary = options.to_dict()
	_f.world.economy.add_intel(0, 100)
	options.unlock(0, &"antecedent_power")
	_use(_f.orbital_scan, Vector3.ZERO)
	options.from_dict(data)
	assert_false(options.is_unlocked(0, _f.lance), "the later unlock is gone")
	assert_eq(options.cooldown_left(0, _f.orbital_scan), 0.0, "and so is the cooldown")


func test_restored_cooldowns_follow_the_restored_clock() -> void:
	_f.world.economy.add_intel(0, 100)
	_use(_f.orbital_scan, Vector3.ZERO)
	var data: Dictionary = _f.world.discovery.field_options.to_dict()
	var copy: FieldOptions = FieldOptions.new(_f.world, 0)
	copy.from_dict(data)
	copy.tick(5000)
	assert_gt(copy.cooldown_left(0, _f.orbital_scan), 50.0, "a fresh system starts at tick 0")
