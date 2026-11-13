extends GutTest
## Saving and loading the Infiltration landing (Quiet Uplink) on the real map (ADR
## 0013): the patrols on their routes and hunting, the outpost alerted (a Surveyor
## walked into a patrol: reinforcements, extraction moved, countdown running), a Wisp
## halfway through sabotaging the uplink. Loaded into a fresh map it is the same situation
## (the patrols in the same states on the same legs, the same alert level and script
## state) and it carries on: the sabotage completes, the extraction appears where the
## alarm moved it, and getting the squad there wins.

const WISP_HEALTH: float = 5000.0

var _f: SaveFixture
var _maps: Array[LandingMap] = []


func before_each() -> void:
	_f = SaveFixture.new(self)


func after_each() -> void:
	for map: Variant in _maps:
		_f.dispose(map)
	_maps.clear()
	# Let the renderer release what the freed visuals used (sabotage sparks).
	await wait_frames(3)


func test_quiet_uplink_round_trip_carries_on() -> void:
	var def: MissionDef = SaveFixture.mission(&"infiltration")
	var map: LandingMap = await _land(def)
	var world: SimWorld = map.world
	await _f.run(map, 30)
	var guards: GuardCommander = map.runner.guards
	assert_eq(guards.patrols.size(), def.patrols.size(), "every patrol walks")
	var hub: Building = null
	for building: Building in world.buildings_of(def.hostile_faction):
		if building.def == def.hostile_hq:
			hub = building
	# The Surveyor walks into a patrol: the outpost raises the alarm (reinforcements,
	# the extraction moves, the clock starts) before the save.
	var surveyor: Unit = SaveFixture.unit_of(world, 0, &"concord_surveyor")
	SaveFixture.toughen(surveyor, WISP_HEALTH)
	var patrol: PatrolBehaviour = guards.patrols[0]
	SaveFixture.teleport(surveyor, world.paths.closest_point(patrol.centroid() + Vector3(4, 0, 4)))
	var alarmed: Callable = func() -> bool:
		return world.stealth.alert_level(def.hostile_faction) == StealthSystem.LEVEL_ALERTED
	assert_true(await _f.run_until(map, alarmed, 600), "the outpost is alerted")
	assert_eq(guards.calls, 1, "help was called")
	var wisp: Unit = SaveFixture.unit_of(world, 0, &"concord_wisp")
	SaveFixture.toughen(wisp, WISP_HEALTH)
	SaveFixture.teleport(wisp, _approach_spot(world, hub))
	# A saboteur must see its target: let the fog catch up with the Wisp first.
	var seen: Callable = func() -> bool: return world.vision.can_see(0, hub)
	assert_true(await _f.run_until(map, seen, 40), "the Wisp sees the uplink")
	map.context.command_queue.push(SabotageCommand.new(0, [wisp] as Array[Node3D], hub))
	var halfway: Callable = func() -> bool: return hub.sabotage_progress > 0.3
	var under_way: bool = await _f.run_until(map, halfway, 600)
	assert_true(under_way, "the sabotage is under way")
	assert_true(wisp.is_sabotaging, "the Wisp works on")
	var script: InfiltrationScript = map.runner.script_instance as InfiltrationScript
	assert_true(script.compromised, "the script knows")
	assert_eq(script.waves_sent, 1, "reinforcements came")
	var before: Dictionary = _situation(map)
	var snapshot: Dictionary = map.snapshot()
	var hub_id: int = hub.entity_id
	var wisp_id: int = wisp.entity_id
	_f.dispose(map)
	var loaded: LandingMap = await _land(def, snapshot)
	var after: Dictionary = _situation(loaded)
	for key: String in before:
		assert_eq(var_to_str(after[key]), var_to_str(before[key]), "same %s after the load" % key)
	var resaved: Dictionary = loaded.snapshot()
	var differences: Array[String] = SaveFixture.differences(
		SaveFixture.normalised(snapshot), SaveFixture.normalised(resaved)
	)
	assert_eq(differences, [] as Array[String], "save, load, save gives the same save")
	assert_true(SaveFixture.explored_covers(resaved, snapshot), "the explored fog is kept")
	world = loaded.world
	hub = world.entity(hub_id) as Building
	wisp = world.entity(wisp_id) as Unit
	assert_eq(wisp.saboteur.target, hub, "the Wisp is back on the uplink")
	script = loaded.runner.script_instance as InfiltrationScript
	var saved_script: Array = before["script"]
	var was_compromised: bool = saved_script[0]
	assert_eq(script.compromised, was_compromised, "the script remembers the alarm")
	var sabotaged: Callable = func() -> bool: return hub.is_sabotaged
	assert_true(await _f.run_until(loaded, sabotaged, 600), "the sabotage completes")
	await _f.run(loaded, 2)
	var extraction: Objective = loaded.runner.objective(&"extract")
	assert_not_null(extraction, "the extraction opens")
	if extraction == null:
		return
	assert_true(script.compromised)
	if script.compromised:
		assert_almost_eq(extraction.area_center.x, -90.0, 0.1, "where the alarm moved it")
		assert_gt(extraction.countdown_tick, 0, "with the clock running")
	for unit: Unit in world.units_of(0):
		SaveFixture.teleport(unit, world.paths.closest_point(extraction.area_center))
	var over: Callable = func() -> bool: return loaded.runner.result != null
	assert_true(await _f.run_until(loaded, over, 100), "the landing ends")
	assert_true(loaded.runner.result != null and loaded.runner.result.won, "won")


func _land(def: MissionDef, restore: Dictionary = {}) -> LandingMap:
	var map: LandingMap = await _f.land(def, null, restore)
	_maps.append(map)
	return map


func _situation(map: LandingMap) -> Dictionary:
	var world: SimWorld = map.world
	var patrols: Array = []
	for patrol: PatrolBehaviour in map.runner.guards.patrols:
		patrols.append([patrol.state(), patrol.index, patrol.direction, patrol.members.size()])
	var units: Dictionary = {}
	for unit: Unit in world.units:
		units[unit.entity_id] = [unit.sim_position(), unit.health.current, unit.is_cloaked]
	var objectives: Dictionary = {}
	for objective: Objective in map.runner.objectives:
		objectives[objective.id] = [
			objective.state, objective.countdown_tick, objective.area_center
		]
	var script: InfiltrationScript = map.runner.script_instance as InfiltrationScript
	return {
		"tick": map.context.sim_clock.get_tick(),
		"alert": world.stealth.alert_level(map.mission.hostile_faction),
		"script": [script.compromised, script.waves_sent],
		"calls": map.runner.guards.calls,
		"patrols": patrols,
		"units": units,
		"objectives": objectives,
	}


## A walkable spot a few metres from `building` with a path to its edge.
static func _approach_spot(world: SimWorld, building: Building) -> Vector3:
	var area: Rect2 = building.footprint()
	for step: int in 16:
		var angle: float = TAU * step / 16.0
		var reach: float = area.size.length() * 0.5 + 6.0
		var spot: Vector3 = world.paths.closest_point(
			building.position + Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
		)
		var edge: Vector3 = (
			building.position
			+ Vector3(cos(angle), 0.0, sin(angle)) * (area.size.length() * 0.5 + 1.5)
		)
		if world.paths.is_walkable(spot) and not world.paths.find_path(spot, edge).is_empty():
			return spot
	return world.paths.closest_point(building.position + Vector3(0.0, 0.0, 12.0))
