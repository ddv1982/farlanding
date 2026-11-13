extends GutTest
## Infiltration's script: being seen changes the mission instead of ending it.
## The first alarm brings reinforcements, moves the extraction point and starts a
## countdown; the extraction objective appears once the uplink is sabotaged.

var _f: MissionFixture
var _rules: InfiltrationRules
var _guard: Unit
var _uplink: Building


func before_each() -> void:
	_f = MissionFixture.new(self)
	_rules = InfiltrationRules.new()
	_rules.target_objective = &"sabotage"
	_rules.extraction = MissionFixture.objective(
		&"extract",
		ObjectiveDef.TYPE_REACH_AREA,
		&"primary",
		{
			"side": ObjectiveDef.SIDE_PLAYER,
			"require_all": true,
			"area_center": Vector3(-60, 0, 60),
			"area_radius": 8.0,
			"at_start": false
		}
	)
	_rules.alerted_extraction = Vector3(-80, 0, -80)
	_rules.alerted_deadline_seconds = 30.0
	_rules.reinforcements = [_f.guard, _f.guard] as Array[UnitDef]
	_rules.reinforcement_entry = Vector3(60, 0, -60)
	_f.def.script_rules = _rules
	_f.def.mission_script = InfiltrationScript
	var route: PatrolRoute = PatrolRoute.new()
	route.unit = _f.guard
	route.waypoints = PackedVector3Array([Vector3(30, 0, -30)])
	_f.def.patrols = [route] as Array[PatrolRoute]
	_uplink = _f.world.spawn_building(_f.target, 1, Vector3(0, 0, -20), true)


func after_each() -> void:
	_f.dispose()


func _start() -> void:
	(
		_f
		. start(
			(
				[
					MissionFixture.objective(
						&"sabotage",
						ObjectiveDef.TYPE_SABOTAGE,
						&"primary",
						{"defs": [_f.target] as Array[EntityDef]}
					),
					_rules.extraction,
					MissionFixture.objective(
						&"quiet", ObjectiveDef.TYPE_STAY_UNDETECTED, &"secondary"
					),
				]
				as Array[ObjectiveDef]
			),
			true,
			true
		)
	)
	_guard = _f.mission.guards.guards()[0]


func _alarm() -> void:
	var intruder: Unit = _f.spawn(_f.combat.scout, 0, Vector3(30, 0, 30))
	_f.world.combat.damage(_guard, 1.0, &"light", intruder)
	_f.tick(1)


func test_extraction_is_not_there_at_the_start() -> void:
	_f.spawn(_f.wisp, 0, Vector3(-60, 0, 60))
	_start()
	assert_null(_f.mission.objective(&"extract"))
	assert_not_null(_f.mission.objective(&"sabotage"))


func test_sabotage_opens_the_extraction() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(-60, 0, 60))
	_start()
	_f.world.sabotage(_uplink, wisp)
	_f.tick(2)
	var extract: Objective = _f.mission.objective(&"extract")
	assert_not_null(extract)
	assert_eq(extract.area_center, Vector3(-60, 0, 60))
	assert_eq(extract.countdown_tick, -1, "no hurry while unseen")
	_f.tick(2)
	assert_eq(extract.state, Objective.STATE_DONE, "the squad stands in the pick-up")
	assert_true(_f.mission.result.won)
	assert_eq(_f.mission.objective(&"quiet").state, Objective.STATE_DONE)


func test_the_first_alarm_changes_the_mission_but_does_not_end_it() -> void:
	_f.spawn(_f.wisp, 0, Vector3(-60, 0, 60))
	_start()
	var units_before: int = _f.world.units_of(1).size()
	_alarm()
	assert_null(_f.mission.result, "being seen is not failure")
	assert_eq(_f.mission.objective(&"quiet").state, Objective.STATE_FAILED)
	var script: InfiltrationScript = _f.mission.script_instance as InfiltrationScript
	assert_true(script.compromised)
	assert_eq(_f.world.units_of(1).size(), units_before + 2, "reinforcements arrived")
	assert_eq(_f.mission.guards.patrols.size(), 2, "and hunt")
	_alarm()
	assert_eq(script.waves_sent, 1, "one wave only")


func test_after_an_alarm_the_extraction_moves_and_the_clock_runs() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(-60, 0, 60))
	_start()
	_alarm()
	_f.world.sabotage(_uplink, wisp)
	_f.tick(2)
	var extract: Objective = _f.mission.objective(&"extract")
	assert_eq(extract.area_center, Vector3(-80, 0, -80), "the pick-up moved")
	assert_gt(extract.countdown_tick, 0)
	assert_true(extract.is_active(), "the old pick-up no longer counts")
	_f.tick(300)
	assert_eq(extract.state, Objective.STATE_FAILED, "too late")
	assert_false(_f.mission.result.won)


func test_the_alarm_clock_runs_even_if_the_uplink_is_never_sabotaged() -> void:
	_f.spawn(_f.wisp, 0, Vector3(-60, 0, 60))
	_start()
	_alarm()
	var target: Objective = _f.mission.objective(&"sabotage")
	assert_gt(target.countdown_tick, 0, "the deadline sits on the job until the way out opens")
	_f.tick(300)
	assert_eq(target.state, Objective.STATE_FAILED, "too late")
	assert_false(_f.mission.result.won)


func test_an_alarm_after_the_sabotage_moves_an_open_extraction() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, 40))
	_start()
	_f.world.sabotage(_uplink, wisp)
	_f.tick(2)
	_alarm()
	var extract: Objective = _f.mission.objective(&"extract")
	assert_eq(extract.area_center, Vector3(-80, 0, -80))
	assert_gt(extract.countdown_tick, 0)
