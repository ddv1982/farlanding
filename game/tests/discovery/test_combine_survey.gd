extends GutTest
## The Survey race (ADR 0011): the Combine's surveyors scan open sites through the
## same Scanner and command path as the player's, bank Intel for the Combine only,
## run when they see enemies close by, and the player's rival-Intel objective fails
## once the Combine banks its target.

var _f: MissionFixture
var _rigger: UnitDef


func before_each() -> void:
	_f = MissionFixture.new(self)
	_rigger = _f.discovery.surveyor.duplicate() as UnitDef
	_rigger.id = &"rigger"
	_rigger.scan_rate = 0.6


func after_each() -> void:
	_f.dispose()


func _survey(units: Array[Unit]) -> SurveyBehaviour:
	var port: WorldAiPort = WorldAiPort.new(_f.base.context, _f.world, 1)
	var survey: SurveyBehaviour = SurveyBehaviour.new(port, CommanderProfile.new(), units)
	survey.home = Vector3(0, 0, -60)
	return survey


func _run(survey: SurveyBehaviour, ticks: int) -> void:
	for i: int in ticks:
		if i % 5 == 0:
			survey.tick(_f.mission_tick())
		_f.tick(1)


func test_combine_surveyors_scan_open_sites_for_combine_intel() -> void:
	var near: DiscoverySite = _f.discovery.site(_f.discovery.discovery(&"near"), Vector3(10, 0, 0))
	var far: DiscoverySite = _f.discovery.site(_f.discovery.discovery(&"far"), Vector3(40, 0, 0))
	var hidden: DiscoverySite = _f.discovery.site(
		_f.discovery.discovery(&"hidden"), Vector3(-10, 0, 0), false
	)
	var a: Unit = _f.spawn(_rigger, 1, Vector3(0, 0, 0))
	var b: Unit = _f.spawn(_rigger, 1, Vector3(2, 0, 0))
	var survey: SurveyBehaviour = _survey([a, b])
	_run(survey, 120)
	assert_true(near.is_resolved, "the near site was scanned")
	assert_true(far.is_resolved, "the second surveyor took the other one")
	assert_false(hidden.is_resolved, "an uncharted site is not on anyone's scan")
	assert_eq(_f.discovery.pile(1).intel, 100, "the Combine banked both")
	assert_eq(_f.discovery.pile(0).intel, 0, "the player got nothing")


func test_a_surveyor_runs_from_enemies_close_by() -> void:
	var site: DiscoverySite = _f.discovery.site(_f.discovery.discovery(&"site"), Vector3(12, 0, 0))
	var rigger: Unit = _f.spawn(_rigger, 1, Vector3(0, 0, 0))
	_f.spawn(_f.combat.soldier, 0, Vector3(14, 0, 2))
	var survey: SurveyBehaviour = _survey([rigger])
	_run(survey, 60)
	assert_false(site.is_resolved, "it did not scan under the player's guns")
	assert_lt(rigger.sim_position().z, -5.0, "it ran for home")


func test_the_player_loses_the_race_when_the_combine_banks_its_target() -> void:
	var race: ObjectiveDef = MissionFixture.objective(&"race", ObjectiveDef.TYPE_RIVAL_INTEL)
	race.side = ObjectiveDef.SIDE_ENEMY
	race.passive = true
	race.amount = 120
	var bank: ObjectiveDef = MissionFixture.objective(&"bank", ObjectiveDef.TYPE_GATHER_INTEL)
	bank.amount = 300
	var alerts: Array[StringName] = []
	var listen: Callable = func(kind: StringName) -> void: alerts.append(kind)
	Events.advisor_alert.connect(listen)
	var mission: Mission = _f.start([bank, race] as Array[ObjectiveDef])
	var objective: Objective = mission.objective(&"race")
	_f.world.economy.add_intel(1, 80)
	_f.tick(2)
	assert_true(objective.is_active())
	assert_almost_eq(objective.progress_ratio, 80.0 / 120.0, 0.01, "the bar shows their share")
	assert_eq(objective.progress_side, ObjectiveDef.SIDE_ENEMY)
	assert_true(alerts.has(&"enemy_intel"), "the Advisor warns")
	_f.world.economy.add_intel(1, 40)
	_f.tick(2)
	Events.advisor_alert.disconnect(listen)
	assert_eq(objective.state, Objective.STATE_FAILED, "they banked theirs first")
	assert_not_null(mission.result, "the mission is over")
	assert_false(mission.result.won, "and lost")


func test_a_surveyor_killed_and_freed_is_forgotten_cleanly() -> void:
	# Found by the balance harness (ADR 0018): a freed surveyor stayed a key of the
	# typed bookkeeping dictionaries and every survey tick logged errors for it.
	_f.discovery.site(_f.discovery.discovery(&"near"), Vector3(10, 0, 0))
	_f.discovery.site(_f.discovery.discovery(&"far"), Vector3(40, 0, 0))
	var a: Unit = _f.spawn(_rigger, 1, Vector3(0, 0, 0))
	var b: Unit = _f.spawn(_rigger, 1, Vector3(2, 0, 0))
	var survey: SurveyBehaviour = _survey([a, b])
	_run(survey, 10)
	a.health.take(10000.0)
	await get_tree().process_frame
	assert_false(is_instance_valid(a), "the dead surveyor was freed")
	_run(survey, 120)
	assert_eq(survey.members.size(), 1, "only the living surveyor is left")
	var assigned: Dictionary = survey.to_dict()["assigned"]
	assert_lte(assigned.size(), 1, "the dead one's site was let go")
	assert_eq(_f.discovery.pile(1).intel, 100, "the survivor scanned both sites")
