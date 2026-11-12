extends GutTest
## Weapons in a real world: cooldown, range, travel time, splash, deaths, the attack
## order carried through to the kill, and Sentries that need power.

var _f: CombatFixture


func before_each() -> void:
	_f = CombatFixture.new(self)


func after_each() -> void:
	_f.dispose()


func test_fires_once_per_cooldown_within_range() -> void:
	var shooter: Unit = _f.spawn(_f.soldier, 0, Vector3.ZERO)
	var target: Unit = _f.spawn(_f.tank, 1, Vector3(0, 0, -8))
	target.weapon = null  # it only takes the fire
	watch_signals(Events)
	_f.tick(51)
	var shots: int = get_signal_emit_count(Events, "weapon_fired")
	assert_between(shots, 5, 6, "one shot a second for five seconds")
	assert_almost_eq(target.health.current, 400.0 - shots * 5.0, 0.01, "light on heavy: half")


func test_does_not_fire_beyond_range() -> void:
	_f.spawn(_f.soldier, 0, Vector3.ZERO)
	var target: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -25))
	watch_signals(Events)
	_f.tick(30)
	assert_signal_not_emitted(Events, "weapon_fired")
	assert_almost_eq(target.health.current, 50.0, 0.01)


func test_projectiles_take_time_to_arrive() -> void:
	var tank: Unit = _f.spawn(_f.tank, 0, Vector3.ZERO)
	var target: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -16))
	target.health.setup(1000.0, &"light", target)
	watch_signals(Events)
	_f.tick(3)
	assert_signal_emitted(Events, "projectile_launched")
	assert_almost_eq(target.health.current, 1000.0, 0.01, "still in flight")
	assert_eq(_f.world.combat.projectiles.size(), 1)
	_f.tick(10)
	assert_lt(target.health.current, 1000.0, "landed")
	assert_eq(_f.world.combat.projectiles.size(), 0)
	assert_signal_emitted(Events, "projectile_impacted")
	assert_not_null(tank)


func test_splash_hurts_nearby_enemies_less_and_spares_friends() -> void:
	_f.spawn(_f.tank, 0, Vector3.ZERO)
	var victim: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -16))
	var neighbour: Unit = _f.spawn(_f.scout, 1, Vector3(3, 0, -16))
	var far: Unit = _f.spawn(_f.scout, 1, Vector3(9, 0, -16))
	var friend: Unit = _f.spawn(_f.scout, 0, Vector3(-2, 0, -16))
	for unit: Unit in [victim, neighbour, far]:
		unit.health.setup(1000.0, &"light", unit)
	_f.tick(14)
	var direct: float = 1000.0 - victim.health.current
	var splash: float = 1000.0 - neighbour.health.current
	assert_almost_eq(direct, 40.0 * 0.8, 1.5, "heavy on light")
	assert_gt(splash, 0.0, "neighbour caught in the blast")
	assert_lt(splash, direct, "less at the edge")
	assert_almost_eq(far.health.current, 1000.0, 0.01, "outside the radius")
	assert_almost_eq(friend.health.current, 50.0, 0.01, "no friendly fire")


func test_dead_units_announce_and_leave() -> void:
	_f.spawn(_f.soldier, 0, Vector3.ZERO)
	var target: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -8))
	watch_signals(Events)
	_f.tick(60)
	assert_signal_emitted_with_parameters(Events, "entity_died", [target])
	assert_true(target.is_queued_for_deletion() or not is_instance_valid(target))
	await get_tree().process_frame
	assert_eq(_f.world.units.size(), 1, "removed from the world")


func test_attack_order_kills_then_takes_the_next_order() -> void:
	var shooter: Unit = _f.spawn(_f.soldier, 0, Vector3.ZERO)
	var target: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -30))
	_f.push(AttackCommand.new(0, [shooter], target))
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [shooter], Vector3(10, 0, 0), true))
	_f.tick(120)
	assert_true(target.is_dead, "approached to range and shot it")
	assert_eq(shooter.orders.current.kind if shooter.orders.current else &"", &"move")
	_f.tick(100)
	assert_true(shooter.orders.is_idle())
	assert_almost_eq(shooter.sim_position(), Vector3(10, 0, 0), Vector3.ONE * 0.05)


func test_dead_building_frees_its_ground() -> void:
	var building: Building = _f.world.spawn_building(_f.hq, 1, Vector3(0, 0, -6), true)
	var blocked: Vector3 = Vector3(0, 0, -6)
	assert_true(_f.world.paths.is_blocked(blocked))
	building.health.take(10000.0)
	assert_false(_f.world.paths.is_blocked(blocked), "cut-out freed at once")


func test_sentry_fires_only_with_power() -> void:
	var sentry: Building = _f.world.spawn_building(_f.sentry, 0, Vector3.ZERO, true)
	var target: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -8))
	target.health.setup(1000.0, &"light", target)
	_f.tick(20)
	assert_true(sentry.is_operational())
	assert_false(sentry.is_powered, "no reactor: low power")
	assert_almost_eq(target.health.current, 1000.0, 0.01, "silent without power")
	_f.world.spawn_building(_f.hq, 0, Vector3(20, 0, 20), true)
	_f.tick(30)
	assert_true(sentry.is_powered)
	assert_lt(target.health.current, 1000.0, "fires by itself once powered")


func test_under_attack_alert_is_throttled() -> void:
	var victim: Unit = _f.spawn(_f.scout, 0, Vector3.ZERO)
	victim.health.setup(1000.0, &"light", victim)
	var alerts: Array[StringName] = []
	var listen: Callable = func(kind: StringName) -> void:
		if kind == &"under_attack":
			alerts.append(kind)
	Events.advisor_alert.connect(listen)
	for i: int in 25:
		_f.world.combat.damage(victim, 1.0, &"light", null)
		_f.tick()
	Events.advisor_alert.disconnect(listen)
	assert_eq(alerts.size(), 3, "once a second over 2.5 s")
