extends GutTest
## The enemy AI gets nothing from stealth data it has not earned: a concealed Wisp
## is absent from what its eyes report, from its commander's knowledge and from its
## guns, until one of its watchers has spotted it.

var _f: MissionFixture


func before_each() -> void:
	_f = MissionFixture.new(self)


func after_each() -> void:
	_f.dispose()


func test_the_ai_port_does_not_report_a_concealed_wisp() -> void:
	_f.spawn(_f.guard, 1, Vector3.ZERO, PI)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, -5))
	_f.tick(15)
	assert_true(wisp.is_cloaked)
	var port: WorldAiPort = WorldAiPort.new(_f.base.context, _f.world, 1)
	assert_false(port.seen_enemies(Vector3.ZERO, 30.0).has(wisp))
	assert_false(_f.world.combat.can_target(1, wisp))
	assert_null(_f.world.combat.find_target(1, Vector3.ZERO, 30.0))


func test_once_spotted_the_ai_sees_it_like_anything_else() -> void:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO, 0.0)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, -3))
	wisp.cloak.set_stealth_mode(false)
	_f.tick(40)
	assert_true(guard.watcher.spotted)
	var port: WorldAiPort = WorldAiPort.new(_f.base.context, _f.world, 1)
	assert_true(port.seen_enemies(Vector3.ZERO, 30.0).has(wisp))


func test_commander_knowledge_never_holds_a_concealed_wisp() -> void:
	_f.world.spawn_building(_f.combat.hq, 1, Vector3(0, 0, 0), true)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, 8))
	_f.tick(15)
	var knowledge: AiKnowledge = AiKnowledge.new(1, 400)
	var port: WorldAiPort = WorldAiPort.new(_f.base.context, _f.world, 1)
	knowledge.observe(port.seen_enemies(Vector3.ZERO, 40.0), _f.mission_tick())
	assert_false(knowledge.sightings.has(wisp.entity_id))
	assert_eq(knowledge.recent_units(_f.mission_tick(), 100).size(), 0)


func test_the_player_never_sees_a_concealed_enemy_either() -> void:
	var enemy_wisp: Unit = _f.spawn(_f.wisp, 1, Vector3(0, 0, -5))
	_f.spawn(_f.combat.soldier, 0, Vector3.ZERO, PI)
	_f.tick(15)
	assert_false(enemy_wisp.is_visible_to_player, "stealth works both ways")
