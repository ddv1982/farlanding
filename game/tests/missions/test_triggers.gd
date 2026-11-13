extends GutTest
## Area, timer and event triggers, checked by the Mission every sim tick.

var _f: MissionFixture
var _fired: int = 0


func before_each() -> void:
	_f = MissionFixture.new(self)
	_fired = 0
	_f.start([] as Array[ObjectiveDef])


func after_each() -> void:
	_f.dispose()


func _count() -> void:
	_fired += 1


func test_area_trigger_fires_when_a_player_unit_enters() -> void:
	var unit: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 0))
	_f.spawn(_f.combat.soldier, 1, Vector3(0, 0, -20))
	var trigger: AreaTrigger = AreaTrigger.new(Vector3(0, 0, -20), 4.0, -1, _count)
	_f.mission.add_trigger(trigger)
	_f.tick(3)
	assert_eq(_fired, 0, "an enemy in the area does not count")
	unit.locomotion.mover.position = Vector3(0, 0, -19)
	_f.tick(3)
	assert_eq(_fired, 1, "fires once")
	assert_true(trigger.has_fired())


func test_repeating_area_trigger_rearms_when_the_area_empties() -> void:
	var unit: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, -20))
	var trigger: AreaTrigger = AreaTrigger.new(Vector3(0, 0, -20), 4.0, 0, _count)
	trigger.repeat = true
	_f.mission.add_trigger(trigger)
	_f.tick(2)
	unit.locomotion.mover.position = Vector3(0, 0, 10)
	_f.tick(2)
	unit.locomotion.mover.position = Vector3(0, 0, -20)
	_f.tick(2)
	assert_eq(_fired, 2)


func test_timer_trigger_fires_after_its_time() -> void:
	_f.mission.add_trigger(TimerTrigger.new(2.0, _count))
	_f.tick(19)
	assert_eq(_fired, 0)
	_f.tick(2)
	assert_eq(_fired, 1)
	_f.tick(40)
	assert_eq(_fired, 1)


func test_repeating_timer_trigger() -> void:
	var trigger: TimerTrigger = TimerTrigger.new(1.0, _count)
	trigger.repeat = true
	_f.mission.add_trigger(trigger)
	_f.tick(31)
	assert_eq(_fired, 3)


func test_event_trigger_fires_on_a_matching_emission() -> void:
	var filter: Callable = func(args: Array) -> bool: return args[0] == &"wanted"
	var trigger: EventTrigger = EventTrigger.new(Events.advisor_alert, filter, _count)
	_f.mission.add_trigger(trigger)
	Events.advisor_alert.emit(&"other")
	_f.tick(1)
	assert_eq(_fired, 0)
	Events.advisor_alert.emit(&"wanted")
	assert_eq(_fired, 0, "acts on the next sim tick")
	_f.tick(1)
	assert_eq(_fired, 1)
	var first: StringName = trigger.last_args[0]
	assert_eq(first, &"wanted")
	Events.advisor_alert.emit(&"wanted")
	_f.tick(1)
	assert_eq(_fired, 1, "once")


func test_event_trigger_lets_go_when_the_mission_ends() -> void:
	var trigger: EventTrigger = EventTrigger.new(Events.advisor_alert, Callable(), _count)
	_f.mission.add_trigger(trigger)
	_f.mission.finish(false)
	assert_false(Events.advisor_alert.is_connected(trigger._on_emitted))
