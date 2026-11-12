extends GutTest
## The under-attack rule: at most once per 20 s, never while the camera already
## shows the fight (focus within 40 m), and it outranks other waiting alerts.
## Covers the AdvisorQueue rule and the path from Events.entity_damaged.


class FakeEntity:
	extends Node3D
	var def: EntityDef
	var faction: int = 0


var _queue: AdvisorQueue


func before_each() -> void:
	_queue = AdvisorQueue.new()
	_queue.focus = Vector3.ZERO


func test_throttled_to_once_per_twenty_seconds() -> void:
	var far: Vector3 = Vector3(200, 0, 0)
	assert_true(_queue.push(&"under_attack", 0.0, far))
	assert_eq(_queue.pop_ready(0.0), &"under_attack")
	_queue.started(0.0, 1.4)
	for t: float in [2.0, 10.0, 19.9]:
		assert_false(_queue.push(&"under_attack", t, far), "throttled at %.1f s" % t)
	assert_true(_queue.push(&"under_attack", 20.1, far))


func test_silent_while_the_camera_shows_the_fight() -> void:
	assert_false(_queue.push(&"under_attack", 0.0, Vector3(25, 0, 20)), "32 m away: on screen")
	assert_false(_queue.push(&"under_attack", 0.5, Vector3(0, 30, 39)), "height does not count")
	assert_true(_queue.push(&"under_attack", 1.0, Vector3(45, 0, 0)), "45 m away: off screen")


func test_an_on_screen_hit_does_not_start_the_throttle() -> void:
	assert_false(_queue.push(&"under_attack", 0.0, Vector3(5, 0, 0)))
	_queue.focus = Vector3(300, 0, 0)
	assert_true(_queue.push(&"under_attack", 1.0, Vector3(5, 0, 0)), "camera moved away")


func test_unknown_place_or_focus_still_alerts() -> void:
	assert_true(_queue.push(&"under_attack", 0.0))
	var other: AdvisorQueue = AdvisorQueue.new()
	assert_true(other.push(&"under_attack", 0.0, Vector3(1, 0, 1)), "focus unknown")


func test_outranks_other_waiting_alerts() -> void:
	_queue.started(0.0, 2.0)
	_queue.push(&"low_power", 0.1)
	_queue.push(&"unit_ready", 0.2)
	_queue.push(&"under_attack", 0.3, Vector3(100, 0, 0))
	assert_eq(_queue.pop_ready(3.0), &"under_attack")


func test_damage_events_raise_the_alert_through_the_routers() -> void:
	var router: AudioEventRouter = AudioEventRouter.new()
	var played: Array[StringName] = []
	router.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		played.append(ids[0])
		return ids[0]
	router.focus = Vector3.ZERO
	add_child_autofree(router)
	var combat: CombatSoundRouter = CombatSoundRouter.new()
	combat.focus = Vector3.ZERO
	combat.offer_alert = func(kind: StringName, at: Vector3) -> void:
		router.offer_advisor_alert(kind, 0.0, at)
	add_child_autofree(combat)
	var near: FakeEntity = _entity(0, Vector3(10, 0, 10))
	var far: FakeEntity = _entity(0, Vector3(150, 0, 0))
	var enemy: FakeEntity = _entity(1, Vector3(160, 0, 0))
	combat.handle_entity_damaged(near, 5.0, enemy, 0.0)
	assert_false(played.has(&"advisor_under_attack"), "the player is looking at it")
	combat.handle_entity_damaged(enemy, 5.0, far, 0.0)
	assert_false(played.has(&"advisor_under_attack"), "enemy losses are not an alert")
	combat.handle_entity_damaged(far, 5.0, enemy, 0.0)
	assert_eq(played.count(&"advisor_under_attack"), 1)
	combat.handle_entity_damaged(far, 5.0, enemy, 0.0)
	assert_eq(played.count(&"advisor_under_attack"), 1, "throttled")


func test_gameplay_raised_alert_uses_the_last_hurt_position() -> void:
	var combat: CombatSoundRouter = CombatSoundRouter.new()
	add_child_autofree(combat)
	var hurt: FakeEntity = _entity(0, Vector3(70, 0, 0))
	combat.handle_entity_damaged(hurt, 3.0, null, 10.0)
	assert_eq(combat.last_hurt_position(11.0), Vector3(70, 0, 0))
	assert_eq(combat.last_hurt_position(10.0 + CombatSoundRouter.HURT_MEMORY + 1.0), Vector3.INF)


func _entity(faction: int, at: Vector3) -> FakeEntity:
	var entity: FakeEntity = FakeEntity.new()
	entity.def = EntityDef.new()
	entity.faction = faction
	add_child_autofree(entity)
	entity.global_position = at
	return entity
