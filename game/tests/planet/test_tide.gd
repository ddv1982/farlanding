extends GutTest
## Thalassa Low's planet rule (ADR 0014): the tide holds at low water, is announced,
## rises, holds at high water, is announced again and falls. It acts only through the
## WorldConditions and Events, follows the sea level a few times a second at most,
## shows on the HUD's gauge, and saves and restores mid-rise.

const THALASSA: String = "res://data/planets/thalassa_low.tres"

var _f: CombatFixture
var _rule: TideRule
var _turning: Array[Array] = []
var _levels: Array[float] = []
var _level_ticks: Array[int] = []
var _alerts: Array[StringName] = []


func before_each() -> void:
	_f = CombatFixture.new(self)
	_rule = TideRule.new()
	_rule.id = &"test_tide"
	_rule.system = TideSystem
	_rule.random_seed = 5
	_rule.low_water = -1.0
	_rule.high_water = 0.0
	_rule.first_rise_seconds = 10.0
	_rule.low_hold_seconds = 20.0
	_rule.rise_seconds = 8.0
	_rule.high_hold_seconds = 12.0
	_rule.fall_seconds = 6.0
	_rule.hold_variation = 0.0
	_rule.warning_seconds = 4.0
	_turning.clear()
	_levels.clear()
	_level_ticks.clear()
	_alerts.clear()
	Events.tide_turning.connect(_on_turning)
	Events.tide_changed.connect(_on_changed)
	Events.advisor_alert.connect(_on_alert)


func after_each() -> void:
	Events.tide_turning.disconnect(_on_turning)
	Events.tide_changed.disconnect(_on_changed)
	Events.advisor_alert.disconnect(_on_alert)
	_f.dispose()


func _on_turning(seconds: float, rising: bool) -> void:
	_turning.append([seconds, rising])


func _on_changed(level: float) -> void:
	_levels.append(level)
	_level_ticks.append(_f.base.context.sim_clock.get_tick())


func _on_alert(kind: StringName) -> void:
	_alerts.append(kind)


func _tide() -> TideSystem:
	return PlanetRuleSystem.start(_f.world, _rule) as TideSystem


func _seconds(seconds: float) -> void:
	_f.tick(roundi(seconds * SimClock.TICK_RATE))


func test_the_tide_is_announced_rises_holds_and_falls() -> void:
	var tide: TideSystem = _tide()
	assert_not_null(tide, "the rule names its system")
	var conditions: WorldConditions = _f.world.conditions
	assert_true(conditions.has_sea())
	assert_almost_eq(conditions.sea_level, -1.0, 0.001, "it starts at low water")
	assert_eq(tide.state, TideSystem.STATE_LOW)
	_seconds(5.9)
	assert_eq(_turning.size(), 0, "nothing announced yet")
	assert_almost_eq(conditions.shallows_close_seconds, 4.1, 0.15, "the AI knows")
	_seconds(0.2)
	assert_eq(_turning.size(), 1, "announced warning_seconds ahead")
	var warned: float = _turning[0][0]
	assert_almost_eq(warned, 4.0, 0.15)
	var first_rising: bool = _turning[0][1]
	assert_true(first_rising, "rising")
	assert_true(_alerts.has(&"tide_rising"), "the Advisor warns")
	assert_true(tide.indicator_alarm())
	assert_string_starts_with(
		tide.indicator_text(_f.base.context.sim_clock.get_tick()), "RISING IN"
	)
	_seconds(4.0)
	assert_eq(tide.state, TideSystem.STATE_RISING)
	_seconds(4.0)
	assert_almost_eq(tide.level, 0.5, 0.05, "half way up after half the rise")
	assert_almost_eq(conditions.sea_level, -0.5, 0.05)
	assert_eq(conditions.shallows_close_seconds, 0.0, "unsafe while it rises")
	_seconds(4.1)
	assert_eq(tide.state, TideSystem.STATE_HIGH)
	assert_eq(tide.level, 1.0)
	assert_almost_eq(conditions.sea_level, 0.0, 0.001)
	assert_eq(tide.indicator_text(0), "HIGH")
	_seconds(8.0)
	assert_eq(_turning.size(), 2)
	var second_rising: bool = _turning[1][1]
	assert_false(second_rising, "falling")
	assert_true(_alerts.has(&"tide_falling"))
	_seconds(4.0 + 6.1)
	assert_eq(tide.state, TideSystem.STATE_LOW)
	assert_eq(tide.level, 0.0)
	assert_almost_eq(conditions.shallows_close_seconds, 20.0, 0.5, "the low hold starts")


func test_a_new_landing_reports_where_the_sea_is() -> void:
	_tide()
	_f.tick(1)
	assert_eq(_levels, [0.0] as Array[float], "low water is reported at once")


func test_the_level_is_reported_a_few_times_a_second_at_most() -> void:
	_tide()
	_seconds(10.0 + 8.0 + 1.0)
	assert_gt(_levels.size(), 5, "the rise is followed")
	assert_eq(_levels[_levels.size() - 1], 1.0, "the top is reported")
	for i: int in range(1, _levels.size()):
		assert_gt(_levels[i], _levels[i - 1], "it only rises")
		if _levels[i] < 1.0:
			assert_gte(_level_ticks[i] - _level_ticks[i - 1], TideSystem.EMIT_TICKS)
	var reported: int = _levels.size()
	_seconds(5.0)
	assert_eq(_levels.size(), reported, "nothing while it holds")


func test_saves_and_restores_mid_rise_and_goes_on_alike() -> void:
	var tide: TideSystem = _tide()
	_seconds(13.0)
	assert_eq(tide.state, TideSystem.STATE_RISING)
	var saved: Dictionary = tide.to_dict()
	var mid: float = tide.level
	assert_gt(mid, 0.0)
	assert_lt(mid, 1.0)
	var world_saved: Dictionary = _f.world.to_dict()
	assert_true(world_saved.has("planet"), "the world saves the planet rule")
	_seconds(30.0)
	var expected: Dictionary = tide.to_dict()
	# A second tide restored from the save follows the same course from there.
	var other: CombatFixture = CombatFixture.new(self)
	var again: TideSystem = PlanetRuleSystem.start(other.world, _rule) as TideSystem
	other.tick(_f.base.context.sim_clock.get_tick() - 300)
	again.from_dict(saved)
	assert_eq(again.state, TideSystem.STATE_RISING)
	assert_almost_eq(again.level, mid, 0.001)
	assert_almost_eq(other.world.conditions.tide_level, mid, 0.001, "conditions follow")
	other.tick(300)
	assert_eq(var_to_str(again.to_dict()), var_to_str(expected), "the same course")
	other.dispose()


func test_holds_vary_from_the_seed_and_the_rng_is_saved() -> void:
	_rule.hold_variation = 6.0
	var first: TideSystem = _tide()
	var turn: int = first.turn_tick()
	var other: CombatFixture = CombatFixture.new(self)
	var second: TideSystem = PlanetRuleSystem.start(other.world, _rule) as TideSystem
	assert_eq(second.turn_tick(), turn, "the same seed draws the same first rise")
	other.dispose()
	assert_true(first.to_dict().has("rng_state"))


func test_thalassa_plays_the_tide_in_the_sound_s_range() -> void:
	var planet: PlanetDef = load(THALASSA)
	var rule: TideRule = planet.rule as TideRule
	assert_not_null(rule, "Thalassa's rule is the tide")
	assert_eq(rule.system, TideSystem)
	assert_ne(planet.summary, "")
	assert_ne(rule.summary, "")
	# The tide sound assumes a full swing of 40 to 90 seconds.
	assert_between(rule.rise_seconds, 40.0, 90.0)
	assert_between(rule.fall_seconds, 40.0, 90.0)
	assert_almost_eq(rule.low_water, -1.3, 0.001)
	assert_almost_eq(rule.high_water, 0.15, 0.001)
	assert_gte(rule.first_rise_seconds - rule.hold_variation, rule.warning_seconds + 60.0)
