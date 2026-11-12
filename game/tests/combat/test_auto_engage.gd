extends GutTest
## Units fight on their own: idle units engage what they see in range, walk a short
## way to enemies just beyond it and come back, ignore far ones, return fire, and
## moving units hold fire unless their weapon fires on the move.

var _f: CombatFixture
var _listeners: Array[Callable] = []


func before_each() -> void:
	_f = CombatFixture.new(self)


func after_each() -> void:
	for listener: Callable in _listeners:
		Events.weapon_fired.disconnect(listener)
	_listeners.clear()
	_f.dispose()


func _shots_by(shooter: Node3D) -> Array[int]:
	var shots: Array[int] = [0]
	var id: int = shooter.get_instance_id()
	var listener: Callable = func(by: Node3D, _w: WeaponDef, _m: Vector3, _t: Vector3) -> void:
		if is_instance_valid(by) and by.get_instance_id() == id:
			shots[0] += 1
	Events.weapon_fired.connect(listener)
	_listeners.append(listener)
	return shots


func test_idle_unit_shoots_an_enemy_in_range_without_moving() -> void:
	var guard: Unit = _f.spawn(_f.soldier, 0, Vector3.ZERO)
	var enemy: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -8))
	_f.tick(20)
	assert_lt(enemy.health.current, 50.0)
	assert_almost_eq(guard.sim_position(), Vector3.ZERO, Vector3.ONE * 0.01, "stood its ground")


func test_walks_up_to_a_near_enemy_kills_it_and_returns() -> void:
	var guard: Unit = _f.spawn(_f.soldier, 0, Vector3.ZERO)
	var enemy: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -15))
	_f.tick(5)
	assert_true(guard.orders.is_auto_attacking(), "engaging on its own")
	_f.tick(100)
	assert_true(enemy.is_dead)
	_f.tick(60)
	assert_true(guard.orders.is_idle(), "done")
	var home: float = guard.sim_position().length()
	assert_lt(home, UnitOrders.GUARD_RADIUS + 0.5, "walked back to where it stood")


func test_ignores_enemies_well_beyond_range() -> void:
	var guard: Unit = _f.spawn(_f.soldier, 0, Vector3.ZERO)
	var enemy: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -25))
	_f.tick(40)
	assert_true(guard.orders.is_idle())
	assert_almost_eq(enemy.health.current, 50.0, 0.01)
	assert_almost_eq(guard.sim_position(), Vector3.ZERO, Vector3.ONE * 0.01)


func test_gives_up_when_the_enemy_runs_off_the_leash() -> void:
	var guard: Unit = _f.spawn(_f.soldier, 0, Vector3.ZERO)
	var enemy: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -16))
	enemy.health.setup(1000.0, &"light", enemy)
	_f.tick(10)
	assert_true(guard.orders.is_auto_attacking())
	enemy.locomotion.mover.position = Vector3(0, 0, -45)
	_f.tick(2)
	assert_false(guard.orders.is_auto_attacking(), "no long chase")
	_f.tick(60)
	assert_lt(guard.sim_position().length(), UnitOrders.GUARD_RADIUS + 0.5, "back home")


func test_moving_units_hold_fire() -> void:
	var walker: Unit = _f.spawn(_f.soldier, 0, Vector3.ZERO)
	_f.spawn(_f.scout, 1, Vector3(6, 0, -20))
	var shots: Array[int] = _shots_by(walker)
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [walker], Vector3(0, 0, -40)))
	_f.tick(90)
	assert_eq(shots[0], 0, "walked past without shooting")
	assert_almost_eq(walker.sim_position(), Vector3(0, 0, -40), Vector3.ONE * 0.05, "kept going")


func test_weapons_that_fire_on_the_move_do() -> void:
	var runner: UnitDef = _f.soldier.duplicate()
	runner.weapon = _f.rifle.duplicate()
	runner.weapon.fire_while_moving = true
	var walker: Unit = _f.spawn(runner, 0, Vector3.ZERO)
	_f.spawn(_f.scout, 1, Vector3(6, 0, -20))
	var shots: Array[int] = _shots_by(walker)
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [walker], Vector3(0, 0, -40)))
	_f.tick(90)
	assert_gt(shots[0], 0, "shot while passing")
	assert_almost_eq(walker.sim_position(), Vector3(0, 0, -40), Vector3.ONE * 0.05, "kept going")


func test_returns_fire_on_an_attacker_out_of_reach() -> void:
	var guard: Unit = _f.spawn(_f.soldier, 0, Vector3.ZERO)
	guard.health.setup(1000.0, &"light", guard)
	var tank: Unit = _f.spawn(_f.tank, 1, Vector3(0, 0, -19))
	_f.tick(25)
	assert_lt(guard.health.current, 1000.0, "the tank hit first")
	assert_true(guard.orders.is_auto_attacking(), "answered")
	_f.tick(60)
	assert_lt(tank.health.current, 400.0, "and is shooting back")


func test_does_not_engage_what_its_faction_cannot_see() -> void:
	_f.world.enable_vision(Rect2(-100, -100, 200, 200), 2.0)
	var short_sighted: UnitDef = _f.soldier.duplicate()
	short_sighted.vision_range = 4.0
	var guard: Unit = _f.spawn(short_sighted, 0, Vector3.ZERO)
	var enemy: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -8))
	_f.tick(30)
	assert_almost_eq(enemy.health.current, 50.0, 0.01, "in range but unseen")
	_f.push(AttackCommand.new(0, [guard], enemy))
	_f.tick(1)
	assert_true(guard.orders.is_idle(), "cannot be ordered onto it either")
	short_sighted.vision_range = 12.0
	_f.tick(20)
	assert_lt(enemy.health.current, 50.0, "seen, so engaged")


func test_attackers_beyond_sight_are_exposed_and_answered() -> void:
	_f.world.enable_vision(Rect2(-100, -100, 200, 200), 2.0)
	var short_sighted: UnitDef = _f.soldier.duplicate()
	short_sighted.vision_range = 6.0
	var guard: Unit = _f.spawn(short_sighted, 0, Vector3.ZERO)
	guard.health.setup(1000.0, &"light", guard)
	var tank: Unit = _f.spawn(_f.tank, 1, Vector3(0, 0, -19))
	_f.tick(30)
	assert_lt(guard.health.current, 1000.0, "shelled from beyond its sight")
	assert_true(_f.world.vision.can_see(0, tank), "the shooter gave itself away")
	_f.tick(80)
	assert_lt(tank.health.current, 400.0, "and was answered")
