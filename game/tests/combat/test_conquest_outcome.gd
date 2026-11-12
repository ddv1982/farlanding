extends GutTest
## Win/lose: lost with the last HQ, won when every enemy unit and building is gone,
## announced once.

var _f: CombatFixture


func before_each() -> void:
	_f = CombatFixture.new(self)


func after_each() -> void:
	_f.dispose()


func test_nothing_decided_while_both_sides_stand() -> void:
	_f.world.spawn_building(_f.hq, 0, Vector3(-40, 0, 0), true)
	_f.spawn(_f.scout, 1, Vector3(40, 0, 0))
	var outcome: ConquestOutcome = ConquestOutcome.new(0, _f.hq)
	assert_eq(outcome.check(_f.world), ConquestOutcome.Result.NONE)


func test_won_when_every_enemy_unit_and_building_is_destroyed() -> void:
	_f.world.spawn_building(_f.hq, 0, Vector3(-40, 0, 0), true)
	var enemy: Unit = _f.spawn(_f.scout, 1, Vector3(40, 0, 0))
	var post: Building = _f.world.spawn_building(_f.sentry, 1, Vector3(40, 0, 20), true)
	var outcome: ConquestOutcome = ConquestOutcome.new(0, _f.hq)
	watch_signals(Events)
	enemy.health.take(1000.0)
	assert_eq(outcome.check(_f.world), ConquestOutcome.Result.NONE, "a building is left")
	post.health.take(1000.0)
	assert_eq(outcome.check(_f.world), ConquestOutcome.Result.WON)
	assert_signal_emitted_with_parameters(Events, "mission_ended", [true])
	outcome.check(_f.world)
	assert_signal_emit_count(Events, "mission_ended", 1, "announced once")


func test_lost_with_the_headquarters() -> void:
	var lander: Building = _f.world.spawn_building(_f.hq, 0, Vector3(-40, 0, 0), true)
	_f.spawn(_f.soldier, 0, Vector3(-30, 0, 0))
	_f.spawn(_f.scout, 1, Vector3(40, 0, 0))
	var outcome: ConquestOutcome = ConquestOutcome.new(0, _f.hq)
	watch_signals(Events)
	lander.health.take(10000.0)
	assert_eq(outcome.check(_f.world), ConquestOutcome.Result.LOST, "units left do not help")
	assert_signal_emitted_with_parameters(Events, "mission_ended", [false])


func test_losing_the_headquarters_together_with_the_last_enemy_is_a_loss() -> void:
	var lander: Building = _f.world.spawn_building(_f.hq, 0, Vector3(-40, 0, 0), true)
	var last_enemy: Unit = _f.spawn(_f.scout, 1, Vector3(40, 0, 0))
	var outcome: ConquestOutcome = ConquestOutcome.new(0, _f.hq)
	last_enemy.health.take(10000.0)
	lander.health.take(10000.0)
	assert_eq(outcome.check(_f.world), ConquestOutcome.Result.LOST)
