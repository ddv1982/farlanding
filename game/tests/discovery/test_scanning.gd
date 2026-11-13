extends GutTest
## A Surveyor scanning discovery sites: a full scan resolves the site, anything that
## ends the order first interrupts it, and chained sites open one after another.

var _f: DiscoveryFixture


func before_each() -> void:
	_f = DiscoveryFixture.new(self)


func after_each() -> void:
	_f.dispose()


func test_a_scan_resolves_the_site_and_pays_intel() -> void:
	watch_signals(Events)
	var def: DiscoveryDef = _f.discovery(&"seam")
	var site: DiscoverySite = _f.site(def, Vector3(20, 0, 0))
	var scanner: Unit = _f.spawn(_f.surveyor, 0, Vector3.ZERO)
	_f.scan(scanner, site, 18)
	assert_true(site.is_being_scanned, "close enough after walking: scanning")
	assert_true(scanner.is_scanning)
	assert_signal_emitted(Events, "scan_started")
	assert_between(site.scan_progress, 0.01, 0.99)
	_f.tick(25)
	assert_true(site.is_resolved)
	assert_false(site.is_being_scanned)
	assert_eq(site.resolved_by, 0)
	assert_eq(_f.pile().intel, def.intel_reward)
	assert_signal_emitted_with_parameters(Events, "discovery_made", [site, def, 0])
	assert_signal_emitted_with_parameters(Events, "codex_entry_added", [def])
	assert_signal_emitted_with_parameters(Events, "intel_changed", [0, def.intel_reward])
	assert_eq(_f.world.discovery.codex(0), [def] as Array[DiscoveryDef])
	assert_true(scanner.orders.is_idle(), "the scan order ends with the scan")


func test_moving_away_interrupts_and_loses_progress() -> void:
	watch_signals(Events)
	var site: DiscoverySite = _f.site(_f.discovery(&"seam"), Vector3(5, 0, 0))
	var scanner: Unit = _f.spawn(_f.surveyor, 0, Vector3.ZERO)
	_f.scan(scanner, site, 8)
	assert_true(site.is_being_scanned)
	_f.push(
		MoveCommand.new(MoveCommand.KIND_MOVE, 0, [scanner] as Array[Node3D], Vector3(-40, 0, 0))
	)
	_f.tick(2)
	assert_false(site.is_being_scanned)
	assert_false(site.is_resolved)
	assert_eq(site.scan_progress, 0.0)
	assert_signal_emitted_with_parameters(Events, "scan_interrupted", [scanner, site])
	assert_eq(_f.pile().intel, 0)


func test_dying_interrupts() -> void:
	watch_signals(Events)
	var site: DiscoverySite = _f.site(_f.discovery(&"seam"), Vector3(5, 0, 0))
	var scanner: Unit = _f.spawn(_f.surveyor, 0, Vector3.ZERO)
	_f.scan(scanner, site, 5)
	assert_true(site.is_being_scanned)
	_f.world.combat.damage(scanner, 1000.0, &"heavy", null)
	_f.tick(1)
	assert_false(site.is_being_scanned)
	assert_signal_emitted(Events, "scan_interrupted")


func test_a_stop_interrupts() -> void:
	watch_signals(Events)
	var site: DiscoverySite = _f.site(_f.discovery(&"seam"), Vector3(5, 0, 0))
	var scanner: Unit = _f.spawn(_f.surveyor, 0, Vector3.ZERO)
	_f.scan(scanner, site, 5)
	_f.push(StopCommand.new(0, [scanner] as Array[Node3D]))
	_f.tick(1)
	assert_false(site.is_being_scanned)
	assert_signal_emitted(Events, "scan_interrupted")


func test_units_without_a_scanner_ignore_the_order() -> void:
	var site: DiscoverySite = _f.site(_f.discovery(&"seam"), Vector3(5, 0, 0))
	var soldier: Unit = _f.spawn(_f.combat.soldier, 0, Vector3.ZERO)
	_f.scan(soldier, site, 30)
	assert_false(site.is_resolved)
	assert_true(soldier.orders.is_idle())


func test_the_chain_charts_the_next_site_when_resolved() -> void:
	var first: DiscoveryDef = _f.discovery(&"beacon", DiscoveryDef.ANTECEDENT)
	var second: DiscoveryDef = _f.discovery(&"ruin", DiscoveryDef.ANTECEDENT)
	first.leads_to = &"ruin"
	var defs: Array[DiscoveryDef] = [first, second]
	assert_false(Discovery.is_led_to(defs, &"beacon"))
	assert_true(Discovery.is_led_to(defs, &"ruin"))
	var a: DiscoverySite = _f.site(first, Vector3(5, 0, 0))
	var b: DiscoverySite = _f.site(second, Vector3(-5, 0, 0), false)
	assert_false(b.visible, "a chained site starts hidden")
	assert_false(b.is_signal_known_to_player)
	var scanner: Unit = _f.spawn(_f.surveyor, 0, Vector3.ZERO)
	_f.scan(scanner, b, 40)
	assert_false(b.is_resolved, "it cannot be scanned before it is charted")
	_f.scan(scanner, a, 40)
	assert_true(a.is_resolved)
	assert_true(b.charted)
	assert_true(b.visible)
	_f.scan(scanner, b, 40)
	assert_true(b.is_resolved)


func test_two_scanners_scan_faster() -> void:
	var def: DiscoveryDef = _f.discovery(&"seam")
	def.scan_time = 10.0
	var site: DiscoverySite = _f.site(def, Vector3(3, 0, 0))
	var a: Unit = _f.spawn(_f.surveyor, 0, Vector3(0, 0, 2))
	var b: Unit = _f.spawn(_f.surveyor, 0, Vector3(0, 0, -2))
	_f.push(ScanCommand.new(0, [a, b] as Array[Node3D], site))
	_f.tick(56)
	assert_true(site.is_resolved, "two scanners need about half the time")


func test_site_state_saves_and_loads() -> void:
	var def: DiscoveryDef = _f.discovery(&"seam")
	var site: DiscoverySite = _f.site(def, Vector3(3, 0, 0))
	_f.world.discovery.resolve(site, 0)
	var data: Dictionary = site.to_dict()
	var copy: DiscoverySite = DiscoverySite.new()
	copy.setup(def, false)
	add_child_autofree(copy)
	copy.from_dict(data)
	assert_true(copy.is_resolved)
	assert_true(copy.charted)
