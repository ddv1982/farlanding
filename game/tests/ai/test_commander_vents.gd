extends GutTest
## The enemy commander copes with Emberfall's vents (ADR 0015) through its VentKeeper:
## its Taps vent on purpose before they burst, its units walk out of a vent's radius
## shortly before it erupts, and it keeps its Siphons on known vents near home that are
## not about to burst. It reads only public knowledge (AiPort.vent_dangers) and acts only
## through Commands.

var _f: CombatFixture
var _rule: EruptionRule
var _rich: ResourceNodeDef
var _profile: CommanderProfile
var _port: WorldAiPort
var _keeper: VentKeeper


func before_each() -> void:
	_f = CombatFixture.new(self)
	_rule = EruptionRule.new()
	_rule.system = EruptionSystem
	_rule.tapped_rate = 0.1
	_rule.idle_rate = 0.01
	_rule.threshold_min = 1.0
	_rule.start_pressure_max = 0.0
	_rule.warning_seconds = 10.0
	_rule.radius = 10.0
	_rule.vent_min_pressure = 0.2
	_rule.vent_cooldown_seconds = 60.0
	_rich = _f.base.vent.duplicate() as ResourceNodeDef
	_rich.erupts = true
	_profile = CommanderProfile.new()
	_profile.vent_at_pressure = 0.7
	_profile.vent_flee_seconds = 15.0
	_profile.deposit_radius = 70.0
	_port = WorldAiPort.new(_f.base.context, _f.world, 1)
	_keeper = VentKeeper.new(_port, _f.world, _profile)
	# Power for faction 1.
	_f.world.spawn_building(_f.hq, 1, Vector3(-60, 0, -60), true)


func after_each() -> void:
	_f.dispose()


func _seconds(seconds: float) -> void:
	_f.tick(roundi(seconds * SimClock.TICK_RATE))


func _start() -> EruptionSystem:
	return PlanetRuleSystem.start(_f.world, _rule) as EruptionSystem


func test_nothing_happens_on_a_planet_without_eruptions() -> void:
	_f.world.spawn_resource_node(_rich, Vector3.ZERO)
	assert_eq(_port.vent_dangers().size(), 0)
	assert_null(_keeper.decide(Vector3(-60, 0, -60), []))
	assert_eq(_port.commands_pushed, 0)


func test_its_taps_vent_before_they_burst() -> void:
	var vent: ResourceNode = _f.world.spawn_resource_node(_rich, Vector3.ZERO)
	var tap: Building = _f.world.spawn_building(_f.base.tap, 1, Vector3.ZERO, true)
	var eruptions: EruptionSystem = _start()
	_seconds(5.0)
	_keeper.decide(Vector3(-60, 0, -60), [])
	_f.tick()
	assert_gt(eruptions.pressure_of(vent), 0.45, "not yet at 0.5")
	_seconds(2.5)
	_keeper.decide(Vector3(-60, 0, -60), [])
	_f.tick()
	assert_lt(eruptions.pressure_of(vent), 0.05, "vented at 0.7")
	assert_lt(tap.health.current, tap.health.max_health, "it paid the small price")
	assert_gt(eruptions.vent_cooldown_left(vent), 50.0)


func test_its_units_leave_a_vent_about_to_burst() -> void:
	_f.world.spawn_resource_node(_rich, Vector3.ZERO)
	var stander: Unit = _f.spawn(_f.soldier, 1, Vector3(4, 0, 0))
	var outsider: Unit = _f.spawn(_f.soldier, 1, Vector3(30, 0, 0))
	var player: Unit = _f.spawn(_f.scout, 0, Vector3(-4, 0, -4))
	var eruptions: EruptionSystem = _start()
	# An untapped vent near its threshold: announce it now.
	eruptions.from_dict(_state(1.0))
	_f.tick()
	assert_lt(eruptions.seconds_to_burst(_f.world.resource_nodes[0]), INF, "announced")
	_keeper.decide(Vector3(-60, 0, -60), [])
	_seconds(4.0)
	var there: Vector3 = stander.sim_position()
	assert_gt(Vector2(there.x, there.z).length(), 10.0, "out of the radius")
	assert_almost_eq(outsider.sim_position().x, 30.0, 0.01, "nobody else moved")
	assert_true(player.orders.is_idle(), "it orders only its own")


func test_a_vent_far_off_bursting_does_not_move_anyone() -> void:
	_f.world.spawn_resource_node(_rich, Vector3.ZERO)
	var stander: Unit = _f.spawn(_f.soldier, 1, Vector3(4, 0, 0))
	_start()
	_seconds(1.0)
	_keeper.decide(Vector3(-60, 0, -60), [])
	_seconds(2.0)
	assert_almost_eq(stander.sim_position().x, 4.0, 0.01, "a calm vent is no danger")


func test_it_builds_a_siphon_on_a_known_calm_vent_near_home() -> void:
	var siphon: BuildingDef = load("res://data/buildings/combine_flux_siphon.tres")
	_profile.extractor = siphon
	_profile.extractors_wanted = 1
	_f.world.economy.stockpile(1).alloy = 1000
	var near: ResourceNode = _f.world.spawn_resource_node(_rich, Vector3(-40, 0, -60))
	_f.world.spawn_resource_node(_rich, Vector3(80, 0, 80))
	var rig_def: UnitDef = _f.base.fabricator.duplicate() as UnitDef
	rig_def.builds = [siphon]
	var rig: Unit = _f.spawn(rig_def, 1, Vector3(-50, 0, -50))
	_start()
	var used: Unit = _keeper.decide(Vector3(-60, 0, -60), [rig])
	assert_eq(used, rig, "its builder goes to work")
	_f.tick()
	var placed: Building = null
	for building: Building in _f.world.buildings_of(1):
		if building.def == siphon:
			placed = building
	assert_not_null(placed, "a Siphon site")
	if placed != null:
		assert_eq(placed.vent, near, "on the vent near home")
	assert_null(_keeper.decide(Vector3(-60, 0, -60), [rig]), "one is enough")


func _state(pressure: float) -> Dictionary:
	var vent: ResourceNode = _f.world.resource_nodes[0]
	return {
		"version": EruptionSystem.SAVE_VERSION,
		"tick": _f.base.context.sim_clock.get_tick(),
		"vents":
		{
			str(vent.entity_id):
			{
				"pressure": pressure,
				"threshold": 1.0,
				"state": String(EruptionSystem.STATE_CALM),
				"burst_at": -1,
				"quiet_until": 0,
				"vent_ready_at": 0,
			}
		},
	}
