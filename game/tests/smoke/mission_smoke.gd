extends Node
## Smoke run of every mission on its real map, outside GUT (GUT's script mode leaks a
## renderer RID at exit once real unit visuals were created; a normal run does not).
## Loads each mission of the catalog in turn (then every campaign route landing not in
## the catalog, with a fresh campaign's modifiers), lets it run a few seconds and checks
## that the map supplied terrain, resources and sites and the mission its forces and
## rules. Exits 0 when all pass, 1 otherwise.
##   godot --headless --path game res://tests/smoke/mission_smoke.tscn

const CATALOG: String = "res://data/missions/catalog.tres"
const CAMPAIGN: String = "res://data/campaign/kessel_trail.tres"
## Frames each mission runs before it is checked.
const FRAMES: int = 90

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog: MissionCatalog = load(CATALOG)
	var missions: Array[MissionDef] = catalog.missions.duplicate()
	var landings: Dictionary[MissionDef, LandingModifiers] = {}
	var campaign: CampaignDef = load(CAMPAIGN)
	for route_node: RouteNodeDef in campaign.nodes:
		if not missions.has(route_node.mission):
			missions.append(route_node.mission)
			var plan: LandingPlan = LandingPlan.from_state(
				CampaignState.new(campaign), route_node.id
			)
			landings[route_node.mission] = LandingBuilder.build(campaign, plan)
	for mission: MissionDef in missions:
		var map: LandingMap = mission.map_scene.instantiate() as LandingMap
		map.mission = mission
		map.modifiers = landings.get(mission, null)
		add_child(map)
		for i: int in FRAMES:
			await get_tree().physics_frame
		_check(mission, map)
		remove_child(map)
		map.free()
		await get_tree().process_frame
	if _failures.is_empty():
		print("mission_smoke: all %d missions passed" % missions.size())
	else:
		printerr("mission_smoke: FAILED\n  " + "\n  ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(mission: MissionDef, map: LandingMap) -> void:
	var runner: Mission = map.runner
	_expect(runner != null, mission, "a running mission")
	if runner == null:
		return
	_expect(runner.result == null, mission, "still running after %d frames" % FRAMES)
	_expect(not runner.known_objectives().is_empty(), mission, "objectives")
	_expect(not map.world.resource_nodes.is_empty(), mission, "the map's deposits")
	_expect(not map.world.discovery.sites.is_empty(), mission, "the map's sites")
	_expect(not map.world.units_of(mission.player_faction).is_empty(), mission, "player units")
	_expect((runner.player_hq != null) == (mission.player_hq != null), mission, "the HQ")
	_expect((runner.commander != null) == (mission.commander_profile != null), mission, "the AI")
	if mission.patrols.is_empty():
		return
	_expect(runner.guards.patrols.size() == mission.patrols.size(), mission, "every patrol")
	var unaware: bool = map.world.stealth.alert_level(mission.hostile_faction) == &"unaware"
	_expect(unaware, mission, "nobody noticed the drop")
	for unit: Unit in runner.guards.guards():
		var cones: Array[Node] = unit.find_children("SightCone", "", true, false)
		_expect(cones.size() == 1, mission, "a sight cone on %s" % unit.name)


func _expect(ok: bool, mission: MissionDef, what: String) -> void:
	if not ok:
		_failures.append("%s: %s" % [mission.id, what])
