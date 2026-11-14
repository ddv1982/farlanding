extends GutTest
## Caldera Holdout on Emberfall through a save (ADR 0013, ADR 0015): a vent part-way
## through its warning, a Flux Tap knocked out by an eruption, the vents' pressure and
## the scheduled surge, and the Holdout's wave script after its first wave all come
## back as they were; save -> load -> save gives the same save, and play carries on:
## the warned vent bursts on time and the Tap comes back to work.

## The caldera's north-west vent.
const WEST_VENT: Vector3 = Vector3(-12, 0, -11)

var _f: SaveFixture
var _maps: Array[LandingMap] = []
var _bursts: int = 0


func before_each() -> void:
	_f = SaveFixture.new(self)
	_maps.clear()
	_bursts = 0
	Events.eruption.connect(_on_eruption)


func after_each() -> void:
	Events.eruption.disconnect(_on_eruption)
	for map: LandingMap in _maps:
		_f.dispose(map)


func _on_eruption(_vent: Node3D, _radius: float) -> void:
	_bursts += 1


func test_a_vent_mid_warning_a_knocked_out_tap_and_the_waves_round_trip() -> void:
	var def: MissionDef = SaveFixture.mission(&"emberfall_holdout")
	var map: LandingMap = await _land(def)
	var world: SimWorld = map.world
	var script: WaveScript = map.runner.script_instance as WaveScript
	var sent: bool = await _f.run_until(map, func() -> bool: return script.waves_sent == 1, 1000)
	assert_true(sent, "the first wave is out")
	SaveFixture.toughen(map.runner.player_hq, 50000.0)
	var tap_def: BuildingDef = load("res://data/buildings/concord_flux_tap.tres")
	var west: ResourceNode = _vent_at(world, WEST_VENT)
	assert_not_null(west)
	var tap: Building = world.spawn_building(tap_def, 0, west.position, true)
	assert_eq(tap.vent, west)
	tap.flux_extractor.stall(30.0)
	var eruptions: EruptionSystem = world.planet as EruptionSystem
	var data: Dictionary = eruptions.to_dict()
	var now: int = map.context.sim_clock.get_tick()
	var vents: Dictionary = data["vents"]
	var west_state: Dictionary = vents[str(west.entity_id)]
	west_state["state"] = String(EruptionSystem.STATE_WARNING)
	west_state["pressure"] = 1.0
	west_state["burst_at"] = now + 60
	eruptions.from_dict(data)
	await _f.run(map, 10)
	assert_almost_eq(eruptions.seconds_to_burst(west), 5.0, 0.15, "mid-warning")
	assert_eq(_bursts, 0)
	var snapshot: Dictionary = map.snapshot()
	var saved_planet: Dictionary = eruptions.to_dict()
	var tap_id: int = tap.entity_id
	var west_id: int = west.entity_id
	var enemies: int = world.units_of(1).size()
	var stalled: float = tap.flux_extractor.stalled_seconds
	_f.dispose(map)
	var loaded: LandingMap = await _land(def, snapshot)
	world = loaded.world
	var restored: EruptionSystem = world.planet as EruptionSystem
	assert_not_null(restored)
	assert_eq(restored.to_dict(), saved_planet, "the vents, the surge and the dice")
	west = world.entity(west_id) as ResourceNode
	tap = world.entity(tap_id) as Building
	assert_eq(tap.vent, west, "the Tap stands on its vent")
	assert_true(tap.flux_extractor.is_stalled(), "still knocked out")
	assert_almost_eq(tap.flux_extractor.stalled_seconds, stalled, 0.001)
	assert_almost_eq(tap.flux_extractor.interval, 4.0 / 2.5, 0.001, "on a rich vent")
	assert_almost_eq(restored.seconds_to_burst(west), 5.0, 0.15, "the same countdown")
	assert_eq(west.seconds_to_burst, 5.0, "the gauge shows it")
	assert_not_null(west.get_node_or_null(^"VentGauge"), "with its gauge")
	var restored_script: WaveScript = loaded.runner.script_instance as WaveScript
	assert_eq(restored_script.waves_sent, 1, "the wave script is where it was")
	assert_eq(restored_script.waves_warned, script.waves_warned)
	assert_true(restored_script.climax_scheduled)
	assert_eq(world.units_of(1).size(), enemies, "the wave is back")
	var resaved: Dictionary = loaded.snapshot()
	var differences: Array[String] = SaveFixture.differences(
		SaveFixture.normalised(snapshot), SaveFixture.normalised(resaved)
	)
	assert_eq(differences, [] as Array[String], "save, load, save gives the same save")
	# Play on: the warned vent bursts on time; the Tap gets back to work.
	await _f.run(loaded, 45)
	assert_eq(_bursts, 0, "not before its time")
	await _f.run(loaded, 10)
	assert_eq(_bursts, 1, "it bursts")
	assert_eq(restored.pressure_of(west), 0.0)
	var back: bool = await _f.run_until(
		loaded, func() -> bool: return not tap.flux_extractor.is_stalled(), 600
	)
	assert_true(back, "the Tap comes back after its knock-out")


func _land(def: MissionDef, restore: Dictionary = {}) -> LandingMap:
	var map: LandingMap = await _f.land(def, null, restore)
	_maps.append(map)
	return map


static func _vent_at(world: SimWorld, at: Vector3) -> ResourceNode:
	for node: ResourceNode in world.resource_nodes:
		if node.erupts() and Vector2(node.position.x - at.x, node.position.z - at.z).length() < 1.0:
			return node
	return null
