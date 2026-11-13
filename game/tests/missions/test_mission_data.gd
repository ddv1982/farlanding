extends GutTest
## The three missions as data: they load, use the Kessel map, and differ in what
## they ask (destroy a base, bank Intel against a clock, a stealth raid without a
## base).

const CATALOG: String = "res://data/missions/catalog.tres"


func _mission(id: StringName) -> MissionDef:
	var catalog: MissionCatalog = load(CATALOG)
	for mission: MissionDef in catalog.missions:
		if mission.id == id:
			return mission
	return null


func _types(mission: MissionDef) -> Array[StringName]:
	var types: Array[StringName] = []
	for objective: ObjectiveDef in mission.objectives:
		types.append(objective.type)
	return types


func _kinds(mission: MissionDef) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for objective: ObjectiveDef in mission.objectives:
		kinds.append(objective.kind)
	return kinds


func test_catalog_lists_the_kessel_missions_and_recovery() -> void:
	var catalog: MissionCatalog = load(CATALOG)
	assert_eq(catalog.missions.size(), 6)
	assert_eq(catalog.missions[3].id, &"thalassa_recovery")
	assert_eq(catalog.missions[4].id, &"emberfall_conquest")
	assert_eq(catalog.missions[5].id, &"emberfall_holdout")
	for mission: MissionDef in catalog.missions:
		assert_not_null(mission.map_scene, String(mission.id))
		assert_ne(mission.title, "")
		assert_ne(mission.summary, "")
		assert_ne(mission.briefing, "")
		for objective: ObjectiveDef in mission.objectives:
			assert_not_null(ObjectiveFactory.create(objective), String(objective.id))


func test_conquest_destroys_a_base_with_a_secondary_and_a_hidden_objective() -> void:
	var mission: MissionDef = _mission(&"conquest")
	assert_eq(mission.mission_type, MissionDef.TYPE_CONQUEST)
	assert_not_null(mission.player_hq)
	assert_not_null(mission.commander_profile)
	assert_true(_types(mission).has(ObjectiveDef.TYPE_DESTROY_ALL))
	assert_true(_kinds(mission).has(&"secondary"))
	assert_true(_kinds(mission).has(&"hidden"))
	assert_false(mission.enemy_alert_meter)


func test_survey_banks_intel_against_a_storm_with_raiders() -> void:
	var mission: MissionDef = _mission(&"survey")
	var bank: ObjectiveDef = mission.objective_def(&"bank_intel")
	assert_eq(bank.type, ObjectiveDef.TYPE_GATHER_INTEL)
	assert_gt(bank.deadline_seconds, 0.0, "the storm")
	assert_eq(bank.kind, &"primary")
	assert_ne(mission.commander_profile, _mission(&"conquest").commander_profile)
	var raid: CommanderDifficulty = mission.commander_profile.difficulty(
		StringName(mission.enemy_difficulty)
	)
	assert_lte(raid.max_wave_size, 8, "harassment, not all-out attacks")
	assert_eq(_kinds(mission).count(&"secondary"), 2)


func test_infiltration_has_no_base_patrols_an_alert_meter_and_a_script() -> void:
	var mission: MissionDef = _mission(&"infiltration")
	assert_null(mission.player_hq, "no base")
	assert_null(mission.commander_profile, "no base AI either")
	for unit: UnitDef in mission.player_roster:
		assert_false(unit.can_build(), "no production")
	assert_true(mission.player_roster.any(func(u: UnitDef) -> bool: return u.can_cloak))
	assert_true(mission.enemy_alert_meter)
	assert_gte(mission.patrols.size(), 4)
	for route: PatrolRoute in mission.patrols:
		assert_lt(route.unit.sight_angle, 360.0, "guards have sight cones")
	assert_true(_types(mission).has(ObjectiveDef.TYPE_STAY_UNDETECTED))
	assert_true(_types(mission).has(ObjectiveDef.TYPE_SABOTAGE))
	assert_not_null(mission.mission_script)
	var rules: InfiltrationRules = mission.script_rules as InfiltrationRules
	assert_not_null(rules)
	assert_false(rules.extraction.at_start, "the way out appears after the sabotage")
	assert_ne(rules.alerted_extraction, rules.extraction.area_center)
