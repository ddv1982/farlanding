extends GutTest
## How a Mission decides: all non-passive primaries done = won (passive ones then
## count as done), any primary failed = lost (losing beats winning), hidden
## objectives appear only once achieved, and the debrief numbers.

var _f: MissionFixture
var _ended: Array[bool] = []
var _added: Array[StringName] = []
var _completed: Array[StringName] = []
var _failed: Array[StringName] = []


func before_each() -> void:
	_f = MissionFixture.new(self)
	_ended.clear()
	_added.clear()
	_completed.clear()
	_failed.clear()
	Events.mission_ended.connect(_on_ended)
	Events.objective_added.connect(_on_added)
	Events.objective_completed.connect(_on_completed)
	Events.objective_failed.connect(_on_failed)


func after_each() -> void:
	Events.mission_ended.disconnect(_on_ended)
	Events.objective_added.disconnect(_on_added)
	Events.objective_completed.disconnect(_on_completed)
	Events.objective_failed.disconnect(_on_failed)
	_f.dispose()


func _on_ended(won: bool) -> void:
	_ended.append(won)


func _on_added(objective: RefCounted) -> void:
	_added.append((objective as Objective).id)


func _on_completed(objective: RefCounted) -> void:
	_completed.append((objective as Objective).id)


func _on_failed(objective: RefCounted) -> void:
	_failed.append((objective as Objective).id)


## A conquest: destroy every enemy, keep the HQ, plus an optional and a hidden one.
func _conquest() -> Array:
	var hq: Building = _f.world.spawn_building(_f.combat.hq, 0, Vector3(-40, 0, 40), true)
	var enemy: Unit = _f.spawn(_f.combat.soldier, 1, Vector3(40, 0, -40))
	var warden: Unit = _f.spawn(_f.discovery.warden, Factions.CUSTODIANS, Vector3(0, 0, -60))
	var keep: Dictionary = {
		"side": ObjectiveDef.SIDE_PLAYER, "defs": [_f.combat.hq] as Array[EntityDef]
	}
	var hidden: Dictionary = {
		"side": ObjectiveDef.SIDE_CUSTODIAN, "defs": [_f.discovery.warden] as Array[EntityDef]
	}
	(
		_f
		. start(
			(
				[
					MissionFixture.objective(&"destroy", ObjectiveDef.TYPE_DESTROY_ALL),
					MissionFixture.objective(
						&"keep", ObjectiveDef.TYPE_KEEP_ALIVE, &"primary", keep
					),
					MissionFixture.objective(
						&"intel", ObjectiveDef.TYPE_GATHER_INTEL, &"secondary"
					),
					MissionFixture.objective(
						&"warden", ObjectiveDef.TYPE_DESTROY_COUNT, &"hidden", hidden
					),
				]
				as Array[ObjectiveDef]
			)
		)
	)
	return [hq, enemy, warden]


func test_known_objectives_are_announced_hidden_ones_are_not() -> void:
	_conquest()
	assert_eq(_added, [&"destroy", &"keep", &"intel"] as Array[StringName])
	assert_eq(_f.mission.known_objectives().size(), 3)


func test_destroying_the_enemy_wins_and_passive_objectives_complete() -> void:
	var things: Array = _conquest()
	var enemy: Unit = things[1]
	enemy.health.take(10000.0, null)
	_f.tick(1)
	assert_eq(_ended, [true] as Array[bool])
	assert_not_null(_f.mission.result)
	assert_true(_f.mission.result.won)
	assert_eq(_f.mission.objective(&"keep").state, Objective.STATE_DONE)
	assert_eq(_f.mission.objective(&"intel").state, Objective.STATE_ACTIVE, "not achieved")
	assert_true(_completed.has(&"destroy"))
	assert_true(_completed.has(&"keep"))


func test_losing_the_hq_loses() -> void:
	var things: Array = _conquest()
	var hq: Building = things[0]
	hq.health.take(100000.0, null)
	_f.tick(1)
	assert_eq(_ended, [false] as Array[bool])
	assert_false(_f.mission.result.won)
	assert_true(_failed.has(&"keep"))


func test_losing_beats_winning_on_the_same_tick() -> void:
	var things: Array = _conquest()
	var hq: Building = things[0]
	var enemy: Unit = things[1]
	hq.health.take(100000.0, null)
	enemy.health.take(100000.0, null)
	_f.tick(1)
	assert_eq(_ended, [false] as Array[bool])


func test_the_outcome_is_announced_once() -> void:
	var things: Array = _conquest()
	var enemy: Unit = things[1]
	enemy.health.take(10000.0, null)
	_f.tick(5)
	var hq: Building = things[0]
	hq.health.take(100000.0, null)
	_f.tick(5)
	assert_eq(_ended.size(), 1)


func test_a_hidden_objective_appears_when_achieved() -> void:
	var things: Array = _conquest()
	var warden: Unit = things[2]
	warden.health.take(100000.0, null)
	_f.tick(1)
	var last: StringName = _added.back()
	assert_eq(last, &"warden")
	assert_true(_completed.has(&"warden"))
	assert_true(_f.mission.objective(&"warden").is_known)
	assert_null(_f.mission.result, "a hidden objective decides nothing")


func test_a_failed_hidden_objective_stays_hidden() -> void:
	_f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 0))
	var a: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(5, 0, 0))
	_f.start(
		(
			[
				MissionFixture.objective(
					&"no_losses",
					ObjectiveDef.TYPE_KEEP_ALIVE,
					&"hidden",
					{"side": ObjectiveDef.SIDE_PLAYER, "require_all": true}
				)
			]
			as Array[ObjectiveDef]
		)
	)
	a.health.take(10000.0, null)
	_f.tick(1)
	assert_eq(_f.mission.objective(&"no_losses").state, Objective.STATE_FAILED)
	assert_eq(_failed.size(), 0)
	assert_eq(_added.size(), 0)


func test_any_failed_primary_loses_even_with_others_open() -> void:
	_f.spawn(_f.combat.soldier, 1, Vector3(40, 0, -40))
	(
		_f
		. start(
			(
				[
					MissionFixture.objective(&"destroy", ObjectiveDef.TYPE_DESTROY_ALL),
					MissionFixture.objective(
						&"intel",
						ObjectiveDef.TYPE_GATHER_INTEL,
						&"primary",
						{"amount": 10, "deadline_seconds": 1.0}
					),
				]
				as Array[ObjectiveDef]
			)
		)
	)
	_f.tick(12)
	assert_eq(_ended, [false] as Array[bool])


func test_result_counts_time_intel_and_losses() -> void:
	var things: Array = _conquest()
	var mine: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(-30, 0, 30))
	_f.world.economy.add_intel(0, 40)
	_f.world.economy.spend_intel(0, 20)
	_f.world.economy.add_intel(0, 10)
	mine.health.take(10000.0, null)
	_f.tick(50)
	var enemy: Unit = things[1]
	enemy.health.take(10000.0, null)
	_f.tick(1)
	var result: MissionResult = _f.mission.result
	assert_eq(result.intel_earned, 50)
	assert_eq(result.units_lost, 1)
	assert_eq(result.buildings_lost, 0)
	assert_eq(result.enemies_destroyed, 1)
	assert_almost_eq(result.seconds, 5.1, 0.11)
	assert_eq(result.objectives.size(), 3, "only known objectives")
	assert_eq(MissionResult.clock_text(125.0), "2:05")


func test_finished_signal_carries_the_result() -> void:
	var things: Array = _conquest()
	watch_signals(_f.mission)
	var enemy: Unit = things[1]
	enemy.health.take(10000.0, null)
	_f.tick(1)
	assert_signal_emitted(_f.mission, "finished")
