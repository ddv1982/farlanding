extends GutTest
## Caldera Holdout on the real Emberfall map (PLAN 2.6, ADR 0015): the Lander on the
## caldera, a survive countdown to the extraction and the Lander kept alive as the
## objectives; the WaveScript announces and sends growing waves at the Lander through
## the command queue, schedules the caldera's surge, and the extraction is announced
## inbound and arrives as the win.

var _f: SaveFixture
var _maps: Array[LandingMap] = []
var _alerts: Array[StringName] = []


func before_each() -> void:
	_f = SaveFixture.new(self)
	_maps.clear()
	_alerts.clear()
	Events.advisor_alert.connect(_on_alert)


func after_each() -> void:
	Events.advisor_alert.disconnect(_on_alert)
	for map: LandingMap in _maps:
		_f.dispose(map)


func _on_alert(kind: StringName) -> void:
	_alerts.append(kind)


func _land() -> LandingMap:
	var map: LandingMap = await _f.land(SaveFixture.mission(&"emberfall_holdout"))
	_maps.append(map)
	return map


func test_the_holdout_is_data_on_the_framework() -> void:
	var def: MissionDef = SaveFixture.mission(&"emberfall_holdout")
	assert_eq(def.mission_type, MissionDef.TYPE_HOLDOUT)
	assert_eq(def.mission_script, WaveScript)
	var rules: WaveRules = def.script_rules as WaveRules
	assert_not_null(rules)
	assert_eq(rules.wave_seconds.size(), rules.wave_sizes.size(), "one size per wave")
	for i: int in range(1, rules.wave_count()):
		assert_gt(rules.wave_seconds[i], rules.wave_seconds[i - 1], "waves in order")
		assert_gte(rules.wave_sizes[i], rules.wave_sizes[i - 1], "waves grow")
	var extraction: ObjectiveDef = def.objective_def(rules.extraction_objective)
	assert_eq(extraction.type, ObjectiveDef.TYPE_SURVIVE)
	assert_lt(rules.climax_seconds, extraction.seconds, "the surge comes before the ship")
	assert_lt(rules.wave_seconds[-1], extraction.seconds, "the last wave too")
	var catalog: MissionCatalog = load("res://data/missions/catalog.tres")
	assert_true(catalog.missions.has(def), "in the single-mission catalog")


func test_waves_come_for_the_lander_and_grow() -> void:
	var map: LandingMap = await _land()
	var runner: Mission = map.runner
	var script: WaveScript = runner.script_instance as WaveScript
	assert_not_null(script)
	assert_null(runner.commander, "no base AI: only waves")
	assert_true(map.world.planet is EruptionSystem)
	var lander: Building = runner.player_hq
	assert_almost_eq(lander.position.x, 0.0, 0.01, "the Lander stands on the caldera")
	assert_gt(lander.position.y, 3.0, "up on the plateau")
	var extraction: Objective = runner.objective(&"await_extraction")
	assert_almost_eq(extraction.seconds_left(runner.now()), 720.0, 0.2, "twelve minutes")
	var eruptions: EruptionSystem = map.world.planet as EruptionSystem
	assert_eq(
		eruptions.surge_tick(),
		runner.started_tick + CommanderDifficulty.ticks(630.0),
		"the surge is scheduled"
	)
	# Wave sizes and times from the Phase 9 balance pass (ADR 0018).
	assert_eq(script.wave_roster(0).size(), 2)
	assert_eq(script.wave_roster(7).size(), 8, "the last wave is the largest")
	assert_eq(map.world.units_of(1).size(), 0, "no enemy yet")
	var warned: bool = await _f.run_until(
		map, func() -> bool: return _alerts.has(&"wave_incoming"), 750
	)
	assert_true(warned, "the first wave is announced")
	assert_eq(script.waves_sent, 0, "ahead of it")
	var sent: bool = await _f.run_until(map, func() -> bool: return script.waves_sent == 1, 250)
	assert_true(sent, "the first wave arrives at 1:30")
	await _f.run(map, 2)
	var wave: Array[Unit] = map.world.units_of(1)
	assert_eq(wave.size(), 2)
	assert_eq(script.groups.size(), 1, "one group per wave")
	var group: AttackGroup = script.groups[0]
	assert_eq(group.mode, AttackGroup.MODE_LAST_STAND, "it never turns back")
	assert_almost_eq(group.target.x, lander.position.x, 0.01, "it goes for the Lander")
	var start: float = _flat(group.centroid(), lander.position)
	await _f.run(map, 100)
	assert_lt(_flat(group.centroid(), lander.position), start - 10.0, "on its way")


func test_the_extraction_is_announced_and_wins() -> void:
	var map: LandingMap = await _land()
	var runner: Mission = map.runner
	var extraction: Objective = runner.objective(&"await_extraction")
	extraction.countdown_tick = runner.now() + 50
	await _f.run(map, 2)
	assert_true(_alerts.has(&"extraction_inbound"), "a minute out")
	assert_false(_alerts.has(&"extraction_arrived"))
	var ended: bool = await _f.run_until(map, func() -> bool: return runner.result != null, 80)
	assert_true(ended)
	assert_true(runner.result.won, "holding out is the win")
	assert_true(_alerts.has(&"extraction_arrived"))


func test_losing_the_lander_loses_the_holdout() -> void:
	var map: LandingMap = await _land()
	var runner: Mission = map.runner
	runner.player_hq.health.take(100000.0, null)
	var ended: bool = await _f.run_until(map, func() -> bool: return runner.result != null, 20)
	assert_true(ended)
	assert_false(runner.result.won)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_wave_sizes_follow_the_commander_level() -> void:
	var rules: WaveRules = WaveRules.new()
	rules.wave_seconds = PackedFloat32Array([60, 120])
	rules.wave_sizes = PackedInt32Array([4, 10])
	assert_eq(rules.wave_size(1), 10, "Normal plays the sizes as listed")
	assert_lt(rules.wave_size(1, &"easy"), 10, "Easy is gentler")
	assert_gt(rules.wave_size(1, &"hard"), 10, "Hard is harsher")
	assert_eq(rules.wave_size(5, &"hard"), 0, "no such wave")
	rules.wave_sizes = PackedInt32Array([1])
	assert_eq(rules.wave_size(0, &"easy"), 1, "never below one unit")
