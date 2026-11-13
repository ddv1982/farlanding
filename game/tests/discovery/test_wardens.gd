extends GutTest
## Custodian Wardens: dormant until disturbed, then hostile to everyone nearby; they
## never decide a conquest.

var _f: DiscoveryFixture


func before_each() -> void:
	_f = DiscoveryFixture.new(self)


func after_each() -> void:
	_f.dispose()


func test_a_dormant_warden_neither_fires_nor_is_fired_at() -> void:
	var warden: Unit = _f.spawn(_f.warden, Factions.CUSTODIANS, Vector3(9, 0, 0))
	var soldier: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 0))
	_f.tick(20)
	assert_true(warden.is_dormant)
	assert_eq(warden.health.current, warden.health.max_health, "no one shoots it on their own")
	assert_eq(soldier.health.current, soldier.health.max_health, "it does not shoot")


func test_it_wakes_when_something_comes_close_and_fights() -> void:
	watch_signals(Events)
	var warden: Unit = _f.spawn(_f.warden, Factions.CUSTODIANS, Vector3(0, 0, 0))
	var woke: Array[bool] = []
	warden.woke.connect(func() -> void: woke.append(true))
	var intruder: Unit = _f.spawn(_f.combat.soldier, 1, Vector3(5, 0, 0))
	_f.tick(10)
	assert_false(warden.is_dormant)
	assert_eq(woke.size(), 1)
	_f.tick(30)
	assert_lt(intruder.health.current, intruder.health.max_health, "hostile to the Combine too")


func test_it_wakes_when_attacked() -> void:
	var warden: Unit = _f.spawn(_f.warden, Factions.CUSTODIANS, Vector3(9, 0, 0))
	var soldier: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 0))
	_f.push(AttackCommand.new(0, [soldier] as Array[Node3D], warden))
	_f.tick(20)
	assert_false(warden.is_dormant)
	_f.tick(30)
	assert_lt(soldier.health.current, soldier.health.max_health, "it fights back")


func test_dormancy_is_saved() -> void:
	var warden: Unit = _f.spawn(_f.warden, Factions.CUSTODIANS, Vector3(9, 0, 0))
	warden.dormancy.wake()
	var data: Dictionary = warden.to_dict()
	var copy: Unit = _f.spawn(_f.warden, Factions.CUSTODIANS, Vector3(50, 0, 50))
	copy.from_dict(data)
	assert_false(copy.is_dormant)


func test_the_win_check_ignores_custodians() -> void:
	var hq: Building = _f.world.spawn_building(_f.combat.hq, 0, Vector3(-40, 0, 0), true)
	_f.spawn(_f.warden, Factions.CUSTODIANS, Vector3(40, 0, 0))
	assert_eq(
		ConquestOutcome.evaluate(_f.world.units, _f.world.buildings, 0, _f.combat.hq),
		ConquestOutcome.Result.WON,
		"no Combine left: won, Wardens or not"
	)
	var enemy: Unit = _f.spawn(_f.combat.soldier, 1, Vector3(40, 0, 40))
	assert_eq(
		ConquestOutcome.evaluate(_f.world.units, _f.world.buildings, 0, _f.combat.hq),
		ConquestOutcome.Result.NONE
	)
	enemy.free()
	hq.free()
	assert_eq(
		ConquestOutcome.evaluate(_f.world.units, _f.world.buildings, 0, _f.combat.hq),
		ConquestOutcome.Result.LOST
	)
