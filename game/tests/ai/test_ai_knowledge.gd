extends GutTest
## What the commander knows comes only from its own faction's vision grid: attack
## targets come from seen cells, remembered buildings are forgotten when their ground
## is seen empty, and scouts are sent to unexplored ground first.

var _f: AiFixture
var _commander: Commander


func before_each() -> void:
	_f = AiFixture.new(self)
	_f.world.enable_vision(Rect2(-120, -120, 240, 240), 2.0)


func after_each() -> void:
	if is_instance_valid(_commander):
		_commander.free()
	_f.dispose()


func _start_commander() -> void:
	_commander = Commander.new()
	add_child(_commander)
	_commander.setup(
		_f.combat.base.context,
		_f.world,
		AiFixture.AI,
		_f.profile,
		&"normal",
		Rect2(-120, -120, 240, 240)
	)


## Runs both factions' vision updates, then lets the commander look.
func _look() -> void:
	_f.tick(2)
	_commander.perceive(_f.combat.base.context.sim_clock.get_tick())


func test_attack_targets_come_only_from_seen_cells() -> void:
	_f.building(_f.hub, Vector3(80, 0, 80))
	var enemy_post: Building = _f.building(_f.combat.sentry, Vector3(-60, 0, -60), AiFixture.ENEMY)
	_start_commander()
	_look()
	assert_eq(_commander.knowledge.known_buildings().size(), 0, "the enemy base is unseen")
	var view: CommanderView = _commander.build_view(1)
	assert_false(view.has_target, "nothing to attack yet")
	var eyes: Unit = _f.unit(_f.scout, Vector3(-45, 0, -45))
	_look()
	view = _commander.build_view(2)
	assert_true(view.has_target)
	assert_eq(view.attack_target, enemy_post.position)
	eyes.free()
	_look()
	assert_eq(
		_commander.knowledge.known_buildings().size(), 1, "remembered after the scout is gone"
	)


func test_a_destroyed_building_is_forgotten_once_its_ground_is_seen() -> void:
	_f.building(_f.hub, Vector3(80, 0, 80))
	var enemy_post: Building = _f.building(_f.combat.sentry, Vector3(-60, 0, -60), AiFixture.ENEMY)
	_start_commander()
	var eyes: Unit = _f.unit(_f.scout, Vector3(-45, 0, -45))
	_look()
	eyes.free()
	_look()
	enemy_post.health.take(100000.0)
	_f.tick(1)
	_look()
	assert_eq(_commander.knowledge.known_buildings().size(), 1, "it died out of sight")
	_f.unit(_f.scout, Vector3(-45, 0, -45))
	_look()
	assert_eq(_commander.knowledge.known_buildings().size(), 0, "seen empty: forgotten")


func test_unseen_enemy_units_are_not_known_and_seen_ones_fade() -> void:
	_f.building(_f.hub, Vector3(80, 0, 80))
	_f.soldiers(4, Vector3(-60, 0, 60), AiFixture.ENEMY)
	_start_commander()
	_look()
	assert_eq(_commander.knowledge.sightings.size(), 0)
	var eyes: Unit = _f.unit(_f.scout, Vector3(-50, 0, 50))
	_look()
	assert_eq(_commander.knowledge.sightings.size(), 4)
	eyes.free()
	_f.tick(_commander.knowledge.memory_ticks + 5)
	_look()
	assert_eq(_commander.knowledge.sightings.size(), 0, "old unit sightings are dropped")


func test_scouts_go_to_unexplored_ground_far_from_home_first() -> void:
	var knowledge: AiKnowledge = AiKnowledge.new(1)
	var all_walkable: Callable = func(_point: Vector3) -> bool: return true
	knowledge.setup_sectors(Rect2(-100, -100, 200, 200), 50.0, all_walkable)
	assert_eq(knowledge.sector_points.size(), 16)
	var home: Vector3 = Vector3(75, 0, 75)
	var first: Vector3 = knowledge.next_scout_point(home, home, 0, 1000)
	assert_eq(first, Vector3(-75, 0, -75), "the far corner, where the enemy likely is")
	var seen_far: Callable = func(point: Vector3) -> bool: return point.x < 0.0 and point.z < 0.0
	var none: Callable = func(_area: Rect2) -> bool: return false
	knowledge.forget(10, none, seen_far)
	var second: Vector3 = knowledge.next_scout_point(first, home, 10, 1000)
	assert_false(second.x < 0.0 and second.z < 0.0, "explored sectors are skipped")
	knowledge.block_sector_at(second, 500)
	var third: Vector3 = knowledge.next_scout_point(first, home, 20, 1000)
	assert_ne(third, second, "an unreachable sector is skipped for a while")
