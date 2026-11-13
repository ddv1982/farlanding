extends GutTest
## Patrol routes as data and the guards' behaviour: walk the route through the
## command path, pause and look around, investigate what a guard noticed, hunt when
## the faction is alerted, and go back to the route afterwards.

var _f: MissionFixture
var _port: WorldAiPort


func before_each() -> void:
	_f = MissionFixture.new(self)
	_f.world.stealth.add_guard_faction(1)
	_port = WorldAiPort.new(_f.base.context, _f.world, 1)


func after_each() -> void:
	_f.dispose()


func _route(points: PackedVector3Array, loop: bool = true, pause: float = 1.0) -> PatrolRoute:
	var route: PatrolRoute = PatrolRoute.new()
	route.unit = _f.guard
	route.waypoints = points
	route.loop = loop
	route.default_pause = pause
	return route


## Ticks the world and the behaviour (every 5 ticks, as the GuardCommander does).
func _run(patrol: PatrolBehaviour, ticks: int) -> void:
	for i: int in ticks:
		_f.tick(1)
		if _f.mission_tick() % 5 == 0:
			patrol.tick(_f.mission_tick())


func test_next_index_loops_or_ping_pongs() -> void:
	var points: PackedVector3Array = PackedVector3Array(
		[Vector3.ZERO, Vector3(10, 0, 0), Vector3(20, 0, 0)]
	)
	var loop: PatrolRoute = _route(points, true)
	assert_eq(loop.next_index(2, 1), Vector2i(0, 1))
	var back_and_forth: PatrolRoute = _route(points, false)
	assert_eq(back_and_forth.next_index(1, 1), Vector2i(2, 1))
	assert_eq(back_and_forth.next_index(2, 1), Vector2i(1, -1))
	assert_eq(back_and_forth.next_index(0, -1), Vector2i(1, 1))
	var post: PatrolRoute = _route(PackedVector3Array([Vector3.ZERO]))
	assert_eq(post.next_index(0, 1), Vector2i(0, 1))
	loop.pauses = PackedFloat32Array([4.0])
	assert_eq(loop.pause_at(0), 4.0)
	assert_eq(loop.pause_at(2), 1.0, "missing entries use the default")


func test_guards_walk_the_route_through_commands() -> void:
	var route: PatrolRoute = _route(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -20)]))
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	var patrol: PatrolBehaviour = PatrolBehaviour.new(_port, route, [guard] as Array[Unit])
	patrol.start()
	_run(patrol, 30)
	assert_eq(patrol.state(), PatrolBehaviour.PATROL)
	assert_eq(patrol.index, 1, "paused at the first, walking to the second")
	assert_gt(_port.commands_pushed, 0)
	var deepest: float = 0.0
	for i: int in 12:
		_run(patrol, 5)
		deepest = minf(deepest, guard.sim_position().z)
	assert_lt(deepest, -18.0, "reached the second waypoint")
	var back: float = deepest
	for i: int in 12:
		_run(patrol, 5)
		back = maxf(back, guard.sim_position().z)
	assert_gt(back, -3.0, "and walks back (loop)")


func test_a_suspicious_guard_investigates_then_returns() -> void:
	var route: PatrolRoute = _route(PackedVector3Array([Vector3(0, 0, 0)]))
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	var patrol: PatrolBehaviour = PatrolBehaviour.new(_port, route, [guard] as Array[Unit])
	patrol.start()
	_run(patrol, 6)
	guard.watcher.suspicion = 0.5
	guard.watcher.has_noticed = true
	guard.watcher.last_noticed = Vector3(10, 0, -10)
	guard.watcher.last_seen_tick = _f.mission_tick()
	_run(patrol, 5)
	assert_eq(patrol.state(), PatrolBehaviour.INVESTIGATE)
	assert_eq(patrol.investigations, 1)
	guard.watcher.calm()
	_run(patrol, 60)
	assert_lt(guard.sim_position().distance_to(Vector3(10, 0, -10)), 4.0, "went to look")
	_run(patrol, 100)
	assert_eq(patrol.state(), PatrolBehaviour.PAUSE, "back on its post")


func test_an_alerted_faction_hunts_where_the_intruder_was() -> void:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	var patrol: PatrolBehaviour = PatrolBehaviour.new(_port, null, [guard] as Array[Unit])
	patrol.start()
	var shooter: Unit = _f.spawn(_f.combat.scout, 0, Vector3(0, 0, -60))
	_f.world.combat.damage(guard, 1.0, &"light", shooter)
	_run(patrol, 5)
	assert_eq(patrol.state(), PatrolBehaviour.HUNT)
	_run(patrol, 50)
	assert_lt(guard.sim_position().z, -10.0, "heads for the alert position")


func test_guards_do_not_react_to_an_unnoticed_wisp_behind_them() -> void:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO, 0.0)
	var patrol: PatrolBehaviour = PatrolBehaviour.new(
		_port, _route(PackedVector3Array([Vector3.ZERO])), [guard] as Array[Unit]
	)
	patrol.start()
	_f.spawn(_f.wisp, 0, Vector3(0, 0, 6))
	_run(patrol, 60)
	assert_eq(patrol.investigations, 0)
	assert_eq(patrol.hunts, 0)
	assert_eq(patrol.nearest_enemy(), null, "it cannot see the Wisp")


func test_guard_commander_calls_reinforcements_once_per_alert() -> void:
	var commander: GuardCommander = GuardCommander.new()
	add_child_autofree(commander)
	commander.setup(_f.base.context, _f.world, 1)
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	commander.add_patrol(null, [guard] as Array[Unit])
	watch_signals(commander)
	var shooter: Unit = _f.spawn(_f.combat.scout, 0, Vector3(0, 0, -30))
	_f.world.combat.damage(guard, 1.0, &"light", shooter)
	_f.world.combat.damage(guard, 1.0, &"light", shooter)
	assert_signal_emit_count(commander, "reinforcements_called", 1)
	assert_eq(commander.guards(), [guard] as Array[Unit])
