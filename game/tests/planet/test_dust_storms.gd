extends GutTest
## Kessel Reach's planet rule (ADR 0011): dust storms arrive on a schedule, are
## announced, build, hold and pass; while they blow, vision, ground speed (hover units
## less), sight cones and long weapon ranges are cut for everyone. A climax storm
## never lifts. The system saves and restores mid-storm.

var _f: CombatFixture
var _rule: DustStormRule
var _incoming: Array[float] = []
var _intensities: Array[float] = []
var _intensity_ticks: Array[int] = []
var _alerts: Array[StringName] = []


func before_each() -> void:
	_f = CombatFixture.new(self)
	_f.world.enable_vision(Rect2(-60, -60, 120, 120), 2.0)
	_rule = DustStormRule.new()
	_rule.id = &"test_storms"
	_rule.system = DustStormSystem
	_rule.random_seed = 3
	_rule.first_storm_seconds = 10.0
	_rule.interval_seconds = 20.0
	_rule.interval_variation = 0.0
	_rule.warning_seconds = 5.0
	_rule.build_seconds = 4.0
	_rule.hold_seconds = 6.0
	_rule.hold_variation = 0.0
	_rule.fade_seconds = 4.0
	_incoming.clear()
	_intensities.clear()
	_intensity_ticks.clear()
	_alerts.clear()
	Events.storm_incoming.connect(_on_incoming)
	Events.storm_changed.connect(_on_changed)
	Events.advisor_alert.connect(_on_alert)


func after_each() -> void:
	Events.storm_incoming.disconnect(_on_incoming)
	Events.storm_changed.disconnect(_on_changed)
	Events.advisor_alert.disconnect(_on_alert)
	_f.dispose()


func _on_incoming(seconds: float) -> void:
	_incoming.append(seconds)


func _on_changed(intensity: float) -> void:
	_intensities.append(intensity)
	_intensity_ticks.append(_f.base.context.sim_clock.get_tick())


func _on_alert(kind: StringName) -> void:
	_alerts.append(kind)


func _storms() -> DustStormSystem:
	return PlanetRuleSystem.start(_f.world, _rule) as DustStormSystem


func _seconds(seconds: float) -> void:
	_f.tick(roundi(seconds * SimClock.TICK_RATE))


func test_a_storm_is_announced_then_builds_holds_and_passes() -> void:
	var storms: DustStormSystem = _storms()
	assert_not_null(storms, "the rule names its system")
	_seconds(4.9)
	assert_eq(_incoming.size(), 0, "nothing announced yet")
	_seconds(0.2)
	assert_eq(_incoming.size(), 1, "announced warning_seconds ahead")
	assert_almost_eq(_incoming[0], 5.0, 0.15)
	assert_true(_alerts.has(&"storm_warning"), "the Advisor warns")
	assert_eq(storms.state, DustStormSystem.STATE_WARNING)
	_seconds(5.0)
	assert_eq(storms.state, DustStormSystem.STATE_BUILDING)
	_seconds(4.1)
	assert_eq(storms.state, DustStormSystem.STATE_FULL)
	assert_eq(storms.intensity, 1.0)
	_seconds(6.1)
	assert_eq(storms.state, DustStormSystem.STATE_FADING)
	_seconds(4.1)
	assert_eq(storms.state, DustStormSystem.STATE_CLEAR)
	assert_eq(storms.intensity, 0.0)
	assert_true(_alerts.has(&"storm_passed"), "the all-clear is announced")
	var peak: float = _intensities.max()
	var last: float = _intensities[_intensities.size() - 1]
	assert_eq(peak, 1.0, "storm_changed reached full")
	assert_eq(last, 0.0, "and went back to clear")
	var now: int = _f.base.context.sim_clock.get_tick()
	assert_almost_eq(storms.next_storm_tick() - now, 200, 6, "the next storm is drawn")


func test_storm_changed_is_emitted_a_few_times_a_second_at_most() -> void:
	_storms()
	_seconds(30.0)
	assert_gt(_intensities.size(), 4, "it follows the storm")
	for i: int in range(1, _intensity_ticks.size()):
		var gap: int = _intensity_ticks[i] - _intensity_ticks[i - 1]
		var at_end: bool = _intensities[i] <= 0.0 or _intensities[i] >= 1.0
		if not at_end:
			assert_gte(gap, DustStormSystem.EMIT_TICKS, "rate limited")


func test_full_storm_cuts_vision_speed_sight_and_long_range() -> void:
	var ground: Unit = _f.spawn(_f.soldier, 0, Vector3.ZERO)
	var hover_def: UnitDef = _f.soldier.duplicate() as UnitDef
	hover_def.hovers = true
	var hover: Unit = _f.spawn(hover_def, 0, Vector3(4, 0, 0))
	var long_gun: WeaponDef = _f.rifle.duplicate() as WeaponDef
	long_gun.max_range = 30.0
	var calm_sight: float = ground.sight_range
	var calm_speed: float = ground.locomotion.mover.max_speed
	_storms()
	_seconds(19.5)
	var conditions: WorldConditions = _f.world.conditions
	assert_eq(conditions.storm_intensity, 1.0, "full storm")
	assert_almost_eq(_f.world.vision.range_scale, _rule.vision_factor, 0.01, "vision cut")
	assert_almost_eq(
		ground.locomotion.mover.max_speed, calm_speed * _rule.ground_speed_factor, 0.01
	)
	assert_almost_eq(hover.locomotion.mover.max_speed, calm_speed * _rule.hover_speed_factor, 0.01)
	assert_gt(
		hover.locomotion.mover.max_speed, ground.locomotion.mover.max_speed, "hover slowed less"
	)
	assert_almost_eq(ground.sight_range, calm_sight * _rule.sight_factor, 0.01, "cones shrink")
	assert_almost_eq(_f.world.combat.weapon_range(long_gun), 21.0, 0.01, "long range cut")
	assert_eq(_f.world.combat.weapon_range(_f.rifle), 10.0, "short range untouched")
	var floor_gun: WeaponDef = _f.rifle.duplicate() as WeaponDef
	floor_gun.max_range = 20.0
	assert_eq(_f.world.combat.weapon_range(floor_gun), 18.0, "never below long_range_from")
	_seconds(12.0)
	assert_eq(conditions.storm_intensity, 0.0, "passed")
	assert_almost_eq(ground.locomotion.mover.max_speed, calm_speed, 0.01, "speed back")
	assert_eq(_f.world.vision.range_scale, 1.0, "vision back")


func test_vision_is_cut_on_the_grid() -> void:
	_f.scout.vision_range = 20.0
	_f.spawn(_f.scout, 0, Vector3.ZERO)
	_storms()
	_f.tick(2)
	var grid: VisionGrid = _f.world.vision.grid
	assert_true(grid.is_visible(0, Vector3(16, 0, 0)), "16 m away is seen in clear weather")
	_seconds(19.5)
	_f.tick(2)
	assert_false(grid.is_visible(0, Vector3(16, 0, 0)), "not in a full storm")
	assert_true(grid.is_visible(0, Vector3(8, 0, 0)), "close by still is")


func test_the_climax_reaches_full_at_its_tick_and_never_lifts() -> void:
	var storms: DustStormSystem = _storms()
	var now: int = _f.base.context.sim_clock.get_tick()
	storms.schedule_climax(now + 120)
	assert_eq(storms.next_storm_tick(), DustStormSystem.NEVER, "no regular storm runs into it")
	_seconds(7.0)
	assert_eq(_incoming.size(), 1, "the climax is announced")
	assert_true(storms.is_final)
	_seconds(5.1)
	assert_eq(storms.state, DustStormSystem.STATE_FULL, "full at the deadline")
	_seconds(120.0)
	assert_eq(storms.state, DustStormSystem.STATE_FULL, "and it stays")
	assert_true(_f.world.conditions.storm_is_final)
	assert_eq(storms.indicator_text(0), "BURIED")


func test_a_fading_storm_turns_into_the_climax() -> void:
	var storms: DustStormSystem = _storms()
	_seconds(20.5)
	assert_eq(storms.state, DustStormSystem.STATE_FADING)
	var now: int = _f.base.context.sim_clock.get_tick()
	storms.schedule_climax(now + 30)
	var warned: int = _incoming.size()
	_f.tick(1)
	assert_eq(storms.state, DustStormSystem.STATE_BUILDING, "it builds again")
	assert_eq(_incoming.size(), warned + 1, "and is announced")
	_seconds(2.0)
	assert_lt(storms.intensity, 1.0, "not full before the deadline")
	_seconds(1.5)
	assert_eq(storms.intensity, 1.0)
	_seconds(30.0)
	assert_eq(storms.state, DustStormSystem.STATE_FULL)


func test_a_building_storm_turns_into_the_climax() -> void:
	var storms: DustStormSystem = _storms()
	while storms.state != DustStormSystem.STATE_BUILDING:
		_f.tick(1)
	var now: int = _f.base.context.sim_clock.get_tick()
	storms.schedule_climax(now + 80)
	_f.tick(1)
	assert_true(storms.is_final)
	assert_true(_alerts.has(&"storm_final"), "the Advisor says which storm this is")
	_seconds(6.0)
	assert_lt(storms.intensity, 1.0, "it keeps building until the deadline")
	_seconds(2.1)
	assert_eq(storms.state, DustStormSystem.STATE_FULL)
	_seconds(120.0)
	assert_eq(storms.state, DustStormSystem.STATE_FULL, "and it stays")


func test_saves_and_restores_mid_storm() -> void:
	var storms: DustStormSystem = _storms()
	_seconds(12.0)
	var saved: Dictionary = storms.to_dict()
	var mid: float = storms.intensity
	assert_gt(mid, 0.0)
	assert_lt(mid, 1.0)
	_seconds(10.0)
	storms.from_dict(saved)
	assert_eq(storms.state, DustStormSystem.STATE_BUILDING)
	assert_almost_eq(storms.intensity, mid, 0.001)
	assert_almost_eq(_f.world.conditions.storm_intensity, mid, 0.001, "conditions follow")
	var world_saved: Dictionary = _f.world.to_dict()
	assert_true(world_saved.has("planet"), "the world saves the planet rule")


func test_the_same_seed_draws_the_same_schedule() -> void:
	_rule.interval_variation = 30.0
	_rule.first_storm_seconds = 100.0
	var first: int = _storms().next_storm_tick()
	var again: DustStormSystem = DustStormSystem.new()
	again.setup(_f.world, _rule)
	assert_eq(again.next_storm_tick(), first)


func test_the_hud_indicator_reads_the_storm() -> void:
	var storms: DustStormSystem = _storms()
	assert_eq(storms.indicator_title(), "DUST STORM")
	assert_eq(storms.indicator_text(0), "CLEAR")
	assert_false(storms.indicator_alarm())
	_seconds(6.0)
	var now: int = _f.base.context.sim_clock.get_tick()
	assert_eq(storms.indicator_text(now), "IN 0:04")
	assert_true(storms.indicator_alarm())
