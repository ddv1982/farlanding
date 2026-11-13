extends GutTest
## Intel accounting and the payoff of each discovery type.

var _f: DiscoveryFixture


func before_each() -> void:
	_f = DiscoveryFixture.new(self, true)


func after_each() -> void:
	_f.dispose()


func test_intel_is_added_and_spent_and_announced() -> void:
	watch_signals(Events)
	var economy: Economy = _f.world.economy
	economy.add_intel(0, 70)
	assert_eq(_f.pile().intel, 70)
	assert_signal_emitted_with_parameters(Events, "intel_changed", [0, 70])
	assert_false(economy.spend_intel(0, 100), "cannot spend more than there is")
	assert_eq(_f.pile().intel, 70)
	assert_true(economy.spend_intel(0, 30))
	assert_eq(_f.pile().intel, 40)
	assert_eq(_f.pile(1).intel, 0, "each faction has its own Intel")


func test_intel_survives_a_save() -> void:
	_f.world.economy.add_intel(0, 55)
	var copy: Stockpile = Stockpile.new()
	copy.from_dict(_f.pile().to_dict())
	assert_eq(copy.intel, 55)
	var old: Stockpile = Stockpile.new()
	old.from_dict({"version": 1, "alloy": 5, "flux": 1})
	assert_eq(old.intel, 0, "saves from before Intel load with none")


func test_geological_uncovers_a_deposit() -> void:
	var def: DiscoveryDef = _f.discovery(
		&"seam", DiscoveryDef.GEOLOGICAL, DiscoveryDef.PAYOFF_DEPOSIT
	)
	def.payoff_node = _f.rich
	def.payoff_offset = Vector3(0, 0, 8)
	var site: DiscoverySite = _f.site(def, Vector3(10, 0, 10))
	var before: int = _f.world.resource_nodes.size()
	_f.world.discovery.resolve(site, 0)
	assert_eq(_f.world.resource_nodes.size(), before + 1)
	var node: ResourceNode = _f.world.resource_nodes.back()
	assert_eq(node.def, _f.rich)
	assert_almost_eq(node.position.z, 18.0, 0.01)


func test_biological_heals_own_units_near_the_site_for_a_while() -> void:
	var def: DiscoveryDef = _f.discovery(&"bloom", DiscoveryDef.BIOLOGICAL)
	def.payoff = DiscoveryDef.PAYOFF_HEAL_FIELD
	def.payoff_radius = 10.0
	def.payoff_amount = 10.0
	def.payoff_seconds = 2.0
	var site: DiscoverySite = _f.site(def, Vector3.ZERO)
	var near: Unit = _f.spawn(_f.combat.scout, 0, Vector3(4, 0, 0))
	var far: Unit = _f.spawn(_f.combat.scout, 0, Vector3(40, 0, 0))
	var enemy: Unit = _f.spawn(_f.combat.scout, 1, Vector3(-4, 0, 0))
	for unit: Unit in [near, far, enemy]:
		unit.health.current = 20.0
	_f.world.discovery.resolve(site, 0)
	_f.tick(10)
	assert_almost_eq(near.health.current, 30.0, 0.5, "10 health per second for a second")
	assert_eq(far.health.current, 20.0, "out of the field")
	assert_eq(enemy.health.current, 20.0, "only the discovering faction")
	_f.tick(30)
	assert_almost_eq(near.health.current, 40.0, 1.5, "the field ends after its time")


func test_a_restored_heal_field_follows_the_restored_clock() -> void:
	var def: DiscoveryDef = _f.discovery(&"bloom", DiscoveryDef.BIOLOGICAL)
	def.payoff = DiscoveryDef.PAYOFF_HEAL_FIELD
	def.payoff_seconds = 30.0
	_f.world.discovery.resolve(_f.site(def, Vector3.ZERO), 0)
	var copy: Discovery = autofree(Discovery.new())
	copy.setup(_f.world, 0)
	copy.from_dict(_f.world.discovery.to_dict())
	copy.tick(5000, SimClock.TICK_DELTA)
	assert_eq(copy.heal_fields().size(), 1, "a fresh system starts at tick 0")


func test_antecedent_unlocks_a_field_option() -> void:
	watch_signals(Events)
	var def: DiscoveryDef = _f.discovery(&"ruin", DiscoveryDef.ANTECEDENT)
	def.payoff = DiscoveryDef.PAYOFF_UNLOCK_OPTION
	def.unlocks_option = &"antecedent_power"
	var options: FieldOptions = _f.world.discovery.field_options
	assert_eq(options.check(0, _f.lance), FieldOptions.LOCKED)
	_f.world.discovery.resolve(_f.site(def, Vector3.ZERO), 0)
	assert_true(options.is_unlocked(0, _f.lance))
	assert_false(options.is_unlocked(1, _f.lance), "only for the faction that found it")
	assert_signal_emitted_with_parameters(Events, "advisor_alert", [&"field_option_ready"])


func test_enemy_discovery_reveals_enemy_positions_to_the_finder_only() -> void:
	var def: DiscoveryDef = _f.discovery(&"relay", DiscoveryDef.ENEMY)
	def.payoff = DiscoveryDef.PAYOFF_REVEAL_ENEMY
	def.payoff_radius = 6.0
	def.payoff_seconds = 5.0
	var site: DiscoverySite = _f.site(def, Vector3(-60, 0, -60))
	_f.spawn(_f.surveyor, 0, Vector3(-60, 0, -55))
	var enemy: Unit = _f.spawn(_f.combat.soldier, 1, Vector3(70, 0, 70))
	var hq: Building = _f.world.spawn_building(_f.combat.hq, 1, Vector3(70, 0, 40), true)
	_f.tick(4)
	var grid: VisionGrid = _f.world.vision.grid
	assert_false(grid.is_visible(0, enemy.sim_position()))
	_f.world.discovery.resolve(site, 0)
	_f.tick(4)
	assert_true(grid.is_visible(0, enemy.sim_position()), "the enemy unit is shown")
	assert_true(_f.world.vision.can_see(0, hq), "the enemy building is shown")
	assert_true(enemy.is_visible_to_player)
	_f.tick(60)
	assert_false(grid.is_visible(0, enemy.sim_position()), "only for a while")


func test_resolving_wakes_nothing_but_scanning_wakes_guards() -> void:
	var def: DiscoveryDef = _f.discovery(&"ruin", DiscoveryDef.ANTECEDENT)
	var site: DiscoverySite = _f.site(def, Vector3(0, 0, 0))
	var guard: Unit = _f.spawn(_f.warden, Factions.CUSTODIANS, Vector3(15, 0, 0))
	var far: Unit = _f.spawn(_f.warden, Factions.CUSTODIANS, Vector3(80, 0, 0))
	var scanner: Unit = _f.spawn(_f.surveyor, 0, Vector3(-10, 0, 0))
	_f.scan(scanner, site, 10)
	assert_true(site.is_being_scanned)
	assert_false(guard.is_dormant, "a scan within its guard radius wakes it")
	assert_true(far.is_dormant)
