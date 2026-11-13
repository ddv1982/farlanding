extends GutTest
## Emberfall's planet rule (ADR 0015): erupting vents build pressure (fast while
## tapped, slowly on their own), are announced, burst (damage in the radius, the Tap
## knocked out, the pressure emptied, a quiet spell), can be vented on purpose with a
## cooldown, surge on a mission's call, are named by a forecast, show on the HUD's
## gauge, take the campaign's perks, and save and restore mid-warning.

const EMBERFALL: String = "res://data/planets/emberfall.tres"
const VENT_AT: Vector3 = Vector3(0, 0, 0)

var _f: CombatFixture
var _rule: EruptionRule
var _rich: ResourceNodeDef
var _warnings: Array[Array] = []
var _bursts: Array[Array] = []
var _alerts: Array[StringName] = []
var _feedback: Array[StringName] = []


func before_each() -> void:
	_f = CombatFixture.new(self)
	_rule = EruptionRule.new()
	_rule.id = &"test_eruptions"
	_rule.system = EruptionSystem
	_rule.random_seed = 3
	_rule.tapped_rate = 0.1
	_rule.idle_rate = 0.01
	_rule.threshold_min = 1.0
	_rule.start_pressure_max = 0.0
	_rule.warning_seconds = 2.0
	_rule.radius = 10.0
	_rule.building_damage = 100.0
	_rule.unit_damage = 20.0
	_rule.knockout_seconds = 5.0
	_rule.quiet_seconds = 3.0
	_rule.vent_min_pressure = 0.2
	_rule.vent_damage = 10.0
	_rule.vent_stall_seconds = 1.0
	_rule.vent_cooldown_seconds = 8.0
	_rule.surge_area = Rect2(-30, -30, 60, 60)
	_rule.surge_step_seconds = 1.0
	_rule.surge_warning_seconds = 5.0
	_rule.alert_seconds = 0.0
	_rich = _f.base.vent.duplicate() as ResourceNodeDef
	_rich.id = &"rich_vent"
	_rich.erupts = true
	_rich.flux_rate_scale = 2.5
	_warnings.clear()
	_bursts.clear()
	_alerts.clear()
	_feedback.clear()
	Events.eruption_warning.connect(_on_warning)
	Events.eruption.connect(_on_eruption)
	Events.advisor_alert.connect(_on_alert)
	Events.ui_feedback.connect(_on_feedback)


func after_each() -> void:
	Events.eruption_warning.disconnect(_on_warning)
	Events.eruption.disconnect(_on_eruption)
	Events.advisor_alert.disconnect(_on_alert)
	Events.ui_feedback.disconnect(_on_feedback)
	_f.dispose()


func _on_warning(vent: Node3D, seconds: float, radius: float) -> void:
	_warnings.append([vent, seconds, radius])


func _on_eruption(vent: Node3D, radius: float) -> void:
	_bursts.append([vent, radius])


func _on_alert(kind: StringName) -> void:
	_alerts.append(kind)


func _on_feedback(kind: StringName) -> void:
	_feedback.append(kind)


func _seconds(seconds: float) -> void:
	_f.tick(roundi(seconds * SimClock.TICK_RATE))


## A powered Lander far away, a rich vent at VENT_AT, and a finished Tap on it.
func _tapped_vent() -> Building:
	_f.world.spawn_building(_f.base.lander, 0, Vector3(80, 0, 80), true)
	_f.world.spawn_resource_node(_rich, VENT_AT)
	return _f.world.spawn_building(_f.base.tap, 0, VENT_AT, true)


func _start() -> EruptionSystem:
	return PlanetRuleSystem.start(_f.world, _rule) as EruptionSystem


func _vent() -> ResourceNode:
	for node: ResourceNode in _f.world.resource_nodes:
		if node.erupts():
			return node
	return null


func test_emberfall_names_the_rule_and_its_numbers() -> void:
	var planet: PlanetDef = load(EMBERFALL)
	var rule: EruptionRule = planet.rule as EruptionRule
	assert_not_null(rule, "Emberfall plays an EruptionRule")
	assert_eq(rule.system, EruptionSystem)
	assert_ne(planet.summary, "")
	assert_gt(rule.tapped_rate, rule.idle_rate * 3.0, "tapping is what fills a vent")
	assert_gt(rule.building_damage, rule.unit_damage * 3.0, "buildings take it hardest")
	assert_lt(rule.vent_damage, rule.building_damage * 0.25, "venting is a small price")


func test_a_tapped_vent_fills_erupts_and_knocks_its_tap_out() -> void:
	var tap: Building = _tapped_vent()
	var near: Building = _f.world.spawn_building(_f.sentry, 0, Vector3(6, 0, 0), true)
	var far: Building = _f.world.spawn_building(_f.sentry, 0, Vector3(30, 0, 0), true)
	var soldier: Unit = _f.spawn(_f.soldier, 0, Vector3(0, 0, 5))
	var bystander: Unit = _f.spawn(_f.soldier, 0, Vector3(0, 0, 25))
	var eruptions: EruptionSystem = _start()
	assert_not_null(eruptions, "the rule names its system")
	var vent: ResourceNode = _vent()
	assert_eq(eruptions.pressure_of(vent), 0.0)
	_seconds(5.0)
	assert_almost_eq(eruptions.pressure_of(vent), 0.5, 0.02, "tapped: 0.1 a second")
	assert_almost_eq(vent.pressure, eruptions.pressure_of(vent), 0.01, "the node shows it")
	assert_eq(_warnings.size(), 0)
	_seconds(5.1)
	assert_eq(_warnings.size(), 1, "full: the eruption is announced")
	var warned_vent: Node3D = _warnings[0][0]
	assert_eq(warned_vent, vent)
	var warned_seconds: float = _warnings[0][1]
	var warned_radius: float = _warnings[0][2]
	assert_almost_eq(warned_seconds, 2.0, 0.01, "warning_seconds ahead")
	assert_almost_eq(warned_radius, 10.0, 0.01, "over the radius")
	assert_true(_alerts.has(&"eruption_warning"), "the Advisor warns")
	assert_lt(eruptions.seconds_to_burst(vent), 2.01)
	assert_true(eruptions.indicator_alarm())
	assert_string_starts_with(
		eruptions.indicator_text(_f.base.context.sim_clock.get_tick()), "ERUPTING IN"
	)
	var flux_before: int = _f.base.pile().flux
	_seconds(2.1)
	assert_eq(_bursts.size(), 1, "it bursts")
	assert_eq(eruptions.pressure_of(vent), 0.0, "the pressure is gone")
	assert_eq(tap.health.current, tap.health.max_health - 100.0, "the Tap is hit")
	assert_eq(near.health.current, near.health.max_health - 100.0, "a building in range is hit")
	assert_eq(far.health.current, far.health.max_health, "one out of range is not")
	assert_eq(soldier.health.current, soldier.health.max_health - 20.0, "units take less")
	assert_eq(bystander.health.current, bystander.health.max_health)
	assert_true(tap.flux_extractor.is_stalled(), "the Tap is knocked out")
	assert_true(_alerts.has(&"eruption_damage") == false, "nothing nearly lost")
	flux_before = _f.base.pile().flux
	_seconds(2.5)
	assert_eq(_f.base.pile().flux, flux_before, "a knocked-out Tap yields nothing")
	assert_eq(eruptions.pressure_of(vent), 0.0, "quiet after an eruption")
	_seconds(3.0)
	assert_false(tap.flux_extractor.is_stalled(), "back to work")
	assert_gt(eruptions.pressure_of(vent), 0.0, "and the pressure builds again")


func test_an_untapped_vent_fills_slowly() -> void:
	_f.world.spawn_resource_node(_rich, VENT_AT)
	var eruptions: EruptionSystem = _start()
	_seconds(10.0)
	assert_almost_eq(eruptions.pressure_of(_vent()), 0.1, 0.01, "idle: 0.01 a second")
	assert_eq(eruptions.indicator_text(0), "STABLE")


func test_a_rich_vent_yields_faster_and_the_siphon_banks_alloy() -> void:
	var tap: Building = _tapped_vent()
	assert_almost_eq(tap.flux_extractor.interval, 4.0 / 2.5, 0.001, "2.5 times as fast")
	var siphon: BuildingDef = load("res://data/buildings/combine_flux_siphon.tres")
	assert_eq(siphon.flux_banked_as, &"alloy")
	_f.world.spawn_building(_f.hq, 1, Vector3(-60, 0, -60), true)
	_f.world.spawn_resource_node(_rich, Vector3(40, 0, -40))
	var rig: Building = _f.world.spawn_building(siphon, 1, Vector3(40, 0, -40), true)
	assert_eq(rig.vent.position, Vector3(40, 0, -40))
	var pile: Stockpile = _f.world.economy.stockpile(1)
	var alloy: int = pile.alloy
	var flux: int = pile.flux
	_seconds(4.0)
	assert_gt(pile.alloy, alloy, "the Siphon burns Flux into Alloy")
	assert_eq(pile.flux, flux)


func test_venting_releases_the_pressure_with_a_cooldown() -> void:
	var tap: Building = _tapped_vent()
	var eruptions: EruptionSystem = _start()
	var vent: ResourceNode = _vent()
	_seconds(1.0)
	assert_eq(eruptions.can_vent(tap), EruptionSystem.TOO_LOW, "not at 0.1")
	_f.push(VentCommand.new(0, [tap] as Array[Node3D]))
	_f.tick()
	assert_eq(_feedback, [&"vent_denied"] as Array[StringName])
	_seconds(5.0)
	assert_eq(eruptions.can_vent(tap), EruptionSystem.OK)
	var command: VentCommand = VentCommand.new(0, [tap] as Array[Node3D])
	_f.push(command)
	_f.tick()
	assert_eq(command.vented, [tap] as Array[Building])
	assert_eq(_feedback[-1], &"vent_release")
	assert_almost_eq(eruptions.pressure_of(vent), 0.0, 0.005, "released")
	assert_eq(tap.health.current, tap.health.max_health - 10.0, "a small price")
	assert_true(tap.flux_extractor.is_stalled(), "a short pause")
	assert_eq(_bursts.size(), 0, "no eruption")
	assert_almost_eq(eruptions.vent_cooldown_left(vent), 8.0, 0.15)
	_seconds(4.0)
	assert_eq(eruptions.can_vent(tap), EruptionSystem.COOLING, "cooling down")
	_f.push(VentCommand.new(1, [tap] as Array[Node3D]))
	_f.tick()
	assert_gt(eruptions.pressure_of(vent), 0.2, "nobody else vents our Tap")
	_seconds(4.1)
	assert_eq(eruptions.can_vent(tap), EruptionSystem.OK, "ready again")


func test_venting_calls_off_an_announced_eruption() -> void:
	var tap: Building = _tapped_vent()
	var eruptions: EruptionSystem = _start()
	_seconds(10.1)
	assert_eq(_warnings.size(), 1)
	_f.push(VentCommand.new(0, [tap] as Array[Node3D]))
	_seconds(3.0)
	assert_eq(_bursts.size(), 0, "vented in time")
	assert_eq(eruptions.seconds_to_burst(_vent()), INF)


func test_perks_shield_buildings_and_shorten_the_cooldown() -> void:
	var perks: FactionPerks = FactionPerks.new()
	perks.add_scale(&"", FactionPerks.ERUPTION_DAMAGE, 0.5)
	perks.add_scale(&"tap", FactionPerks.VENT_COOLDOWN, 0.5)
	_f.world.perks[0] = perks
	var tap: Building = _tapped_vent()
	var eruptions: EruptionSystem = _start()
	_seconds(12.2)
	assert_eq(_bursts.size(), 1)
	assert_eq(tap.health.current, tap.health.max_health - 50.0, "heat shielding")
	_seconds(8.0)
	assert_true(eruptions.vent(tap), "vented at about 0.25")
	assert_almost_eq(eruptions.vent_cooldown_left(_vent()), 4.0, 0.15, "pressure valves")


func test_the_player_hears_when_an_eruption_nearly_costs_something() -> void:
	_tapped_vent()
	var frail: Unit = _f.spawn(_f.soldier, 0, Vector3(3, 0, 0))
	frail.health.from_dict({"version": 1, "current": 25.0, "max": 100.0})
	_start()
	_seconds(12.2)
	assert_eq(_bursts.size(), 1)
	assert_true(_alerts.has(&"eruption_damage"))


func test_the_surge_sets_off_every_caldera_vent_in_turn() -> void:
	_f.world.spawn_building(_f.base.lander, 0, Vector3(80, 0, 80), true)
	_f.world.spawn_resource_node(_rich, Vector3(-10, 0, 0))
	_f.world.spawn_resource_node(_rich, Vector3(10, 0, 0))
	_f.world.spawn_resource_node(_rich, Vector3(70, 0, -70))
	var tap: Building = _f.world.spawn_building(_f.base.tap, 0, Vector3(10, 0, 0), true)
	var eruptions: EruptionSystem = _start()
	var at: int = _f.base.context.sim_clock.get_tick() + 100
	eruptions.schedule_surge(at)
	assert_eq(eruptions.surge_tick(), at)
	_seconds(4.9)
	assert_false(_alerts.has(&"surge_incoming"))
	_seconds(0.2)
	assert_true(_alerts.has(&"surge_incoming"), "announced ahead")
	assert_string_starts_with(
		eruptions.indicator_text(_f.base.context.sim_clock.get_tick()), "SURGE IN"
	)
	_seconds(3.0)
	assert_eq(_warnings.size(), 2, "both caldera vents announce")
	assert_eq(eruptions.can_vent(tap), EruptionSystem.SURGING, "too late to vent")
	_seconds(2.0)
	assert_eq(_bursts.size(), 1, "the first bursts at the surge's tick")
	_seconds(1.0)
	assert_eq(_bursts.size(), 2, "the next a step later")
	_seconds(5.0)
	assert_eq(_bursts.size(), 2, "the vent off the caldera is left alone")


func test_a_forecast_names_the_next_vent() -> void:
	_f.world.spawn_building(_f.base.lander, 0, Vector3(80, 0, 80), true)
	_f.world.spawn_resource_node(_rich, Vector3(-40, 0, 0))
	_f.world.spawn_resource_node(_rich, VENT_AT)
	_f.world.spawn_building(_f.base.tap, 0, VENT_AT, true)
	var eruptions: EruptionSystem = _start()
	_f.tick()
	assert_eq(eruptions.next_to_erupt(), _vent_at(VENT_AT), "the tapped one fills first")
	assert_false(_vent_at(VENT_AT).is_next_to_erupt, "unknown without a forecast")
	eruptions.forecast(0, 30.0)
	assert_true(_vent_at(VENT_AT).is_next_to_erupt, "named")
	assert_false(_vent_at(Vector3(-40, 0, 0)).is_next_to_erupt)
	assert_string_starts_with(
		eruptions.indicator_text(_f.base.context.sim_clock.get_tick()), "NEXT"
	)
	_seconds(31.0)
	assert_false(_vent_at(VENT_AT).is_next_to_erupt, "the forecast runs out")


func test_a_geological_forecast_comes_from_a_discovery() -> void:
	var fissure: DiscoveryDef = load("res://data/discoveries/emberfall_seismic_fissure.tres")
	assert_eq(fissure.payoff, DiscoveryDef.PAYOFF_FORECAST)
	assert_eq(fissure.discovery_type, DiscoveryDef.GEOLOGICAL)
	_tapped_vent()
	_start()
	var site: DiscoverySite = _f.world.spawn_site(fissure, Vector3(20, 0, 20))
	_f.world.discovery.resolve(site, 0)
	_f.tick(10)
	assert_true(_vent().is_next_to_erupt)


func test_dangers_tell_the_ai_what_is_about_to_burst() -> void:
	_tapped_vent()
	var eruptions: EruptionSystem = _start()
	assert_eq(eruptions.dangers().size(), 0, "calm")
	_seconds(8.5)
	var dangers: Array[Vector4] = eruptions.dangers()
	assert_eq(dangers.size(), 1, "filling up")
	assert_almost_eq(dangers[0].z, 10.0, 0.01, "its radius")
	assert_almost_eq(dangers[0].w, 3.5, 0.3, "about to be announced, then 2 s")
	var port: WorldAiPort = WorldAiPort.new(_f.base.context, _f.world, 1)
	assert_eq(port.vent_dangers(), dangers, "public knowledge")


func test_a_vent_mid_warning_saves_and_restores() -> void:
	var tap: Building = _tapped_vent()
	var eruptions: EruptionSystem = _start()
	_seconds(10.5)
	assert_eq(_warnings.size(), 1)
	eruptions.forecast(0, 60.0)
	var saved: Dictionary = eruptions.to_dict()
	var restored: EruptionSystem = _start()
	restored.from_dict(saved)
	assert_eq(_warnings.size(), 2, "the warning is announced again")
	assert_almost_eq(restored.seconds_to_burst(_vent()), eruptions.seconds_to_burst(_vent()), 0.01)
	assert_eq(restored.to_dict(), saved, "the same state, RNG included")
	assert_true(_vent().is_next_to_erupt, "the forecast too")
	_seconds(2.0)
	assert_eq(_bursts.size(), 1, "and it bursts on time")
	assert_true(tap.flux_extractor.is_stalled())
	var knocked: Dictionary = tap.flux_extractor.to_dict()
	var copy: FluxExtractor = FluxExtractor.new()
	copy.setup(5, 4.0)
	copy.from_dict(knocked)
	assert_true(copy.is_stalled(), "a knocked-out Tap stays knocked out")
	assert_almost_eq(copy.interval, 4.0 / 2.5, 0.001, "on a rich vent")
	copy.free()


func _vent_at(at: Vector3) -> ResourceNode:
	for node: ResourceNode in _f.world.resource_nodes:
		if node.position.is_equal_approx(at):
			return node
	return null
