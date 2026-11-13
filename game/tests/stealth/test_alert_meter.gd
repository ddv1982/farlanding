extends GutTest
## A guard faction's alert meter: Unaware -> Suspicious -> Alerted, raised by
## suspicion, sabotage and attacks, stepping back down after quiet periods. Its
## watchers also notice plain intruders.

var _f: MissionFixture
var _levels: Array = []


func before_each() -> void:
	_f = MissionFixture.new(self)
	_levels.clear()
	_f.world.stealth.add_guard_faction(1)
	Events.alert_level_changed.connect(_on_level)


func after_each() -> void:
	Events.alert_level_changed.disconnect(_on_level)
	_f.dispose()


func _on_level(faction: int, level: StringName, previous: StringName) -> void:
	_levels.append([faction, level, previous])


func test_starts_unaware() -> void:
	assert_eq(_f.world.stealth.alert_level(1), StealthSystem.LEVEL_UNAWARE)
	assert_eq(_f.world.stealth.alert_level(0), StealthSystem.LEVEL_UNAWARE, "no meter: unaware")
	assert_eq(_f.world.stealth.alert_position(1), Vector3.INF)


func test_suspicion_makes_the_faction_suspicious_then_alerted() -> void:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, -6))
	wisp.cloak.set_stealth_mode(false)
	var stealth: StealthSystem = _f.world.stealth
	while guard.suspicion < StealthSystem.SUSPICIOUS_AT + 0.01:
		_f.tick(1)
	_f.tick(1)
	assert_eq(stealth.alert_level(1), StealthSystem.LEVEL_SUSPICIOUS)
	_f.tick(60)
	assert_eq(stealth.alert_level(1), StealthSystem.LEVEL_ALERTED)
	assert_eq(
		_levels,
		[
			[1, StealthSystem.LEVEL_SUSPICIOUS, StealthSystem.LEVEL_UNAWARE],
			[1, StealthSystem.LEVEL_ALERTED, StealthSystem.LEVEL_SUSPICIOUS],
		]
	)
	assert_almost_eq(stealth.alert_position(1).z, -6.0, 0.5)


func test_alert_decays_one_step_at_a_time_after_quiet() -> void:
	var stealth: StealthSystem = _f.world.stealth
	var shooter: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 10))
	var victim: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	_f.world.combat.damage(victim, 1.0, &"light", shooter)
	assert_eq(stealth.alert_level(1), StealthSystem.LEVEL_ALERTED, "an attack alerts at once")
	shooter.locomotion.mover.position = Vector3(0, 0, 90)
	_f.tick(StealthSystem.ALERTED_QUIET_TICKS - 5)
	assert_eq(stealth.alert_level(1), StealthSystem.LEVEL_ALERTED)
	_f.tick(10)
	assert_eq(stealth.alert_level(1), StealthSystem.LEVEL_SUSPICIOUS)
	_f.tick(StealthSystem.SUSPICIOUS_QUIET_TICKS + 5)
	assert_eq(stealth.alert_level(1), StealthSystem.LEVEL_UNAWARE)
	assert_eq(_levels.size(), 3)


func test_noticing_again_keeps_the_alert_up() -> void:
	var stealth: StealthSystem = _f.world.stealth
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	var shooter: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, -8))
	_f.world.combat.damage(guard, 1.0, &"light", shooter)
	_f.tick(StealthSystem.ALERTED_QUIET_TICKS + 20)
	assert_eq(stealth.alert_level(1), StealthSystem.LEVEL_ALERTED, "still in sight: no decay")


func test_guard_factions_notice_plain_intruders() -> void:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	_f.spawn(_f.combat.scout, 0, Vector3(0, 0, -12))
	_f.tick(30)
	assert_almost_eq(guard.suspicion, 1.0, 0.001)
	assert_eq(_f.world.stealth.alert_level(1), StealthSystem.LEVEL_ALERTED)


func test_sabotage_makes_the_owner_suspicious() -> void:
	var uplink: Building = _f.world.spawn_building(_f.target, 1, Vector3(0, 0, -30), true)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, 0))
	_f.world.sabotage(uplink, wisp)
	assert_eq(_f.world.stealth.alert_level(1), StealthSystem.LEVEL_SUSPICIOUS)
	assert_eq(_f.world.stealth.alert_position(1), uplink.position)


func test_watchers_show_the_faction_alert() -> void:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3(40, 0, 40))
	var shooter: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 0))
	var victim: Unit = _f.spawn(_f.guard, 1, Vector3(0, 0, 5))
	_f.world.combat.damage(victim, 1.0, &"light", shooter)
	_f.tick(1)
	assert_true(guard.is_alerted, "every watcher of an alerted faction is alerted")


func test_alert_meter_saves_and_loads() -> void:
	var shooter: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 10))
	var victim: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	_f.world.combat.damage(victim, 1.0, &"light", shooter)
	var data: Dictionary = _f.world.stealth.to_dict()
	var restored: StealthSystem = StealthSystem.new()
	restored.from_dict(data)
	assert_eq(restored.alert_level(1), StealthSystem.LEVEL_ALERTED)
	assert_true(restored.guard_factions.has(1))
	assert_eq(restored.alert_position(1), _f.world.stealth.alert_position(1))
