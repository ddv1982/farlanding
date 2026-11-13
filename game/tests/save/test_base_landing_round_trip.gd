extends GutTest
## Saving and loading a base-building landing on the real Kessel map (ADR 0013): a
## Proving Ground in full swing (haulers on their loop, a Reactor going up with a
## Fabricator on it, a scan under way, the Lander's queue running with a rally point,
## Rangers attacking, a dust storm building) is saved, loaded into a fresh map and
## found the same, and it carries on: the Reactor completes, the haulers deliver,
## the scan pays out, the queue produces, the fight ends, and the mission can still
## be won. The same for Tidewater Landing played from the campaign, through a save
## file, and Before the Storm with the rival Combine out surveying.

const RANGER: String = "res://data/units/concord_ranger.tres"
const FORGE: String = "res://data/buildings/combine_forge.tres"
const REACTOR: String = "res://data/buildings/concord_reactor.tres"
const HAULER: String = "res://data/units/concord_hauler.tres"
const FABRICATOR: String = "res://data/units/concord_fabricator.tres"
const SAVES: String = "user://test_base_round_trip_saves/"

var _f: SaveFixture
var _maps: Array[KesselProving] = []
var _saved_dir: String


func before_each() -> void:
	_f = SaveFixture.new(self)
	_saved_dir = SaveSlots.default_dir
	SaveSlots.default_dir = SAVES


func after_each() -> void:
	for map: Variant in _maps:
		_f.dispose(map)
	_maps.clear()
	for slot: StringName in SaveSlots.slots():
		SaveSlots.remove(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES))
	SaveSlots.default_dir = _saved_dir


func test_proving_ground_round_trip_carries_on() -> void:
	var def: MissionDef = SaveFixture.mission(&"conquest")
	var map: KesselProving = await _land(def)
	var scene: Dictionary = await _set_the_scene(map)
	var snapshot: Dictionary = map.snapshot()
	var before: Dictionary = _situation(map)
	_f.dispose(map)
	var loaded: KesselProving = await _land(def, null, snapshot)
	_expect_same(snapshot, loaded, before)
	await _expect_it_carries_on(loaded, scene)
	await _expect_the_mission_can_be_won(loaded)


func test_before_the_storm_round_trip_keeps_the_rival_at_work() -> void:
	var def: MissionDef = SaveFixture.mission(&"survey")
	var map: KesselProving = await _land(def)
	# Let the Combine get going: its surveyors go out after a minute and a half.
	await _f.run(map, 900)
	var scene: Dictionary = await _set_the_scene(map)
	var commander: Commander = map.runner.commander
	var surveying: Callable = func() -> bool:
		return commander.survey != null and not commander.survey.members.is_empty()
	assert_true(await _f.run_until(map, surveying, 600), "the rival surveys")
	var surveyors: Array[int] = _ids(commander.survey.members)
	var scouts: Array[int] = _ids(commander.scout.members) if commander.scout != null else []
	var memory: Dictionary = commander.memory.to_dict()
	var dice: int = commander.brain.rng.state
	var climax: int = map.world.planet.to_dict()["climax"]
	map.world.economy.add_intel(0, 50)
	await _f.run(map, 1)
	var bank: Objective = map.runner.objective(&"bank_intel")
	assert_true(bank.is_active() and bank.progress_ratio > 0.0, "the Intel goal is partly done")
	var snapshot: Dictionary = map.snapshot()
	var before: Dictionary = _situation(map)
	_f.dispose(map)
	var loaded: KesselProving = await _land(def, null, snapshot)
	_expect_same(snapshot, loaded, before)
	commander = loaded.runner.commander
	assert_eq(_ids(commander.survey.members), surveyors, "the same surveyors")
	if commander.scout != null:
		assert_eq(_ids(commander.scout.members), scouts, "the same scout")
	assert_eq(commander.memory.to_dict(), memory, "the commander remembers")
	assert_eq(commander.brain.rng.state, dice, "and rolls the same dice")
	var climax_after: int = loaded.world.planet.to_dict()["climax"]
	assert_eq(climax_after, climax, "the climax is due")
	bank = loaded.runner.objective(&"bank_intel")
	assert_true(bank.is_active(), "the Intel goal is still open")
	await _expect_it_carries_on(loaded, scene)
	var rival_scanning: Callable = func() -> bool:
		for unit: Unit in commander.survey.members:
			if unit.is_scanning:
				return true
		return false
	assert_true(await _f.run_until(loaded, rival_scanning, 1200), "the rival scans on")
	loaded.world.economy.add_intel(0, 300)
	var over: Callable = func() -> bool: return loaded.runner.result != null
	assert_true(await _f.run_until(loaded, over, 20), "banking the Intel ends it")
	assert_true(loaded.runner.result != null and loaded.runner.result.won, "won")


func test_tidewater_landing_through_a_save_file_carries_on() -> void:
	var def: MissionDef = SaveFixture.mission(&"thalassa_shallows")
	var campaign: CampaignDef = load(SaveFixture.CAMPAIGN) as CampaignDef
	var session: CampaignSession = CampaignSession.new(campaign)
	session.state.current_node = &"thalassa_shallows"
	session.landing = LandingPlan.from_state(session.state, &"thalassa_shallows")
	session.landing.techs.append(&"hauler_racks")
	var modifiers: LandingModifiers = LandingBuilder.build(campaign, session.landing)
	var map: KesselProving = await _land(def, modifiers)
	var scene: Dictionary = await _set_the_scene(map)
	var game: SaveGame = SaveGame.capture(
		def, map.snapshot(), map.runner.elapsed_seconds(), session
	)
	assert_eq(SaveSlots.write(SaveSlots.MANUAL[0], game), "", "written")
	var before: Dictionary = _situation(map)
	_f.dispose(map)
	var read: SaveGame = SaveSlots.read(SaveSlots.MANUAL[0])
	assert_not_null(read, SaveSlots.last_error)
	assert_eq(read.kind, SaveGame.KIND_CAMPAIGN)
	assert_eq(read.plan.node_id, &"thalassa_shallows")
	assert_true(read.plan.techs.has(&"hauler_racks"))
	var again: LandingModifiers = LandingBuilder.build(read.campaign_def(), read.plan)
	var loaded: KesselProving = await _land(read.mission_def(), again, read.landing)
	_expect_same(read.landing, loaded, before)
	var hauler: Unit = SaveFixture.unit_of(loaded.world, 0, &"concord_hauler")
	assert_eq(
		hauler.carry_capacity, roundi(hauler.def.carry_capacity * 1.25), "the tech still applies"
	)
	await _expect_it_carries_on(loaded, scene)
	await _expect_the_mission_can_be_won(loaded)


func _land(
	def: MissionDef, modifiers: LandingModifiers = null, restore: Dictionary = {}
) -> KesselProving:
	var map: KesselProving = await _f.land(def, modifiers, restore)
	_maps.append(map)
	return map


## Gives the orders and runs until everything is under way. Returns what the later
## checks need to find again (by save id).
func _set_the_scene(map: KesselProving) -> Dictionary:
	var world: SimWorld = map.world
	var queue: CommandQueue = map.context.command_queue
	var hq: Building = map.runner.player_hq
	await _f.run(map, 20)
	var fabricator: Unit = SaveFixture.unit_of(world, 0, &"concord_fabricator")
	var surveyor: Unit = SaveFixture.unit_of(world, 0, &"concord_surveyor")
	var reactor_def: BuildingDef = load(REACTOR) as BuildingDef
	var spot: Vector3 = SaveFixture.free_spot(world, reactor_def, hq)
	assert_ne(spot, Vector3.INF, "room for a Reactor")
	queue.push(PlaceBuildingCommand.new(0, [fabricator] as Array[Node3D], reactor_def, spot))
	var site: DiscoverySite = _nearest_site(world, surveyor.sim_position())
	queue.push(ScanCommand.new(0, [surveyor] as Array[Node3D], site))
	queue.push(ProduceCommand.new(0, hq, load(HAULER) as UnitDef))
	queue.push(ProduceCommand.new(0, hq, load(FABRICATOR) as UnitDef))
	queue.push(RallyCommand.new(0, [hq] as Array[Node3D], hq.position + Vector3(6.0, 0.0, 12.0)))
	var rangers: Array[Node3D] = []
	for i: int in 2:
		var at: Vector3 = world.paths.closest_point(
			hq.position + Vector3(14.0 + i * 2.0, 0.0, -14.0)
		)
		rangers.append(world.spawn_unit(load(RANGER) as UnitDef, 0, at))
	# A Combine Forge out in the open: it does not walk away, and it takes a while.
	var forge_def: BuildingDef = load(FORGE) as BuildingDef
	var rules: PlacementRules = world.placement_rules()
	var forge_at: Vector3 = rules.snap(forge_def, hq.position + Vector3(36.0, 0.0, -26.0))
	var target: Building = world.spawn_building(forge_def, 1, forge_at, true)
	target.health.from_dict({"version": 1, "current": 700.0, "max": 700.0})
	queue.push(AttackCommand.new(0, rangers, target))
	var storm: DustStormSystem = world.planet as DustStormSystem
	if storm != null:
		storm._next_start = map.context.sim_clock.get_tick() + 40
	await _f.run(map, 2)
	var reactor: Building = null
	for building: Building in world.buildings_of(0):
		if building.def == reactor_def:
			reactor = building
	assert_not_null(reactor, "the Reactor site is placed")
	var first: Unit = rangers[0] as Unit
	var ready: Callable = func() -> bool:
		return (
			first.orders.attack_target() == target
			and fabricator.builder.site == reactor
			and reactor.construction.progress() > 0.05
			and surveyor.is_scanning
			and site.scan_progress > 0.3
			and (storm == null or storm.state != DustStormSystem.STATE_CLEAR)
		)
	var under_way: bool = await _f.run_until(map, ready, 900)
	if not under_way:
		print(
			(
				"scene: working %s scanning %s progress %.2f storm %s reactor %s fab order %s"
				% [
					fabricator.builder.is_working(),
					surveyor.is_scanning,
					site.scan_progress,
					storm.state if storm != null else &"none",
					reactor.construction.progress(),
					fabricator.orders.current.kind if fabricator.orders.current != null else &"idle"
				]
			)
		)
	assert_true(under_way, "everything under way")
	var hauler: Unit = SaveFixture.unit_of(world, 0, &"concord_hauler")
	assert_true(hq.producer.is_busy(), "the queue runs")
	assert_true(reactor.is_under_construction, "the Reactor is not done yet")
	assert_eq(hauler.orders.current.kind, Harvester.KIND, "the hauler is on its loop")
	return {
		"reactor": reactor.entity_id,
		"site": site.entity_id,
		"hauler": hauler.entity_id,
		"target": target.entity_id,
		"haulers": SaveFixture.count_of(world, 0, &"concord_hauler"),
		"intel": world.economy.stockpile(0).intel,
		"deliveries": hauler.harvester.deliveries,
	}


## What must be the same after the load, read from the world before it is freed.
func _situation(map: KesselProving) -> Dictionary:
	var world: SimWorld = map.world
	var positions: Dictionary = {}
	var health: Dictionary = {}
	var orders: Dictionary = {}
	for unit: Unit in world.units:
		positions[unit.entity_id] = unit.sim_position()
		health[unit.entity_id] = unit.health.current
		orders[unit.entity_id] = unit.orders.current.kind if unit.orders.current != null else &""
	var objectives: Dictionary = {}
	for objective: Objective in map.runner.objectives:
		objectives[objective.id] = [objective.state, objective.progress_text]
	var pile: Stockpile = world.economy.stockpile(0)
	return {
		"tick": map.context.sim_clock.get_tick(),
		"positions": positions,
		"health": health,
		"orders": orders,
		"buildings": world.buildings.size(),
		"resources": [pile.alloy, pile.flux, pile.intel],
		"objectives": objectives,
		"storm":
		[
			world.planet.to_dict().get("state", "") if world.planet != null else "",
			world.conditions.vision_factor
		],
		"explored": world.vision.grid.to_dict()["explored"],
		"rng": world.planet.to_dict().get("rng_state", "") if world.planet != null else "",
	}


func _expect_same(snapshot: Dictionary, loaded: KesselProving, before: Dictionary) -> void:
	var after: Dictionary = _situation(loaded)
	for key: String in before:
		assert_eq(var_to_str(after[key]), var_to_str(before[key]), "same %s after the load" % key)
	var resaved: Dictionary = loaded.snapshot()
	var differences: Array[String] = SaveFixture.differences(
		SaveFixture.normalised(snapshot), SaveFixture.normalised(resaved)
	)
	assert_eq(differences, [] as Array[String], "save, load, save gives the same save")
	assert_true(SaveFixture.explored_covers(resaved, snapshot), "the explored fog is kept")
	var world: SimWorld = loaded.world
	var fabricator: Unit = SaveFixture.unit_of(world, 0, &"concord_fabricator")
	assert_not_null(fabricator.builder.site, "the builder is back on its site")
	var surveyor: Unit = SaveFixture.unit_of(world, 0, &"concord_surveyor")
	assert_true(surveyor.is_scanning, "the surveyor scans on")
	var camera_text: String = snapshot["camera"]
	var focus: Vector3 = str_to_var(camera_text)
	assert_almost_eq(loaded.camera.get_focus().x, focus.x, 0.01, "the camera looks where it did")


func _expect_it_carries_on(map: KesselProving, scene: Dictionary) -> void:
	var world: SimWorld = map.world
	var reactor_id: int = scene["reactor"]
	var site_id: int = scene["site"]
	var hauler_id: int = scene["hauler"]
	var reactor: Building = world.entity(reactor_id) as Building
	var site: DiscoverySite = world.entity(site_id) as DiscoverySite
	var hauler: Unit = world.entity(hauler_id) as Unit
	var deliveries: int = scene["deliveries"]
	var haulers: int = scene["haulers"]
	var intel: int = scene["intel"]
	var target_id: int = scene["target"]
	var done: Callable = func() -> bool:
		return (
			not reactor.is_under_construction
			and site.is_resolved
			and hauler.harvester.deliveries > deliveries
			and SaveFixture.count_of(world, 0, &"concord_hauler") > haulers
			and world.entity(target_id) == null
		)
	var finished: bool = await _f.run_until(map, done, 3000)
	if not finished:
		var target: Building = world.entity(target_id) as Building
		if target != null:
			print("  target hp %.0f at %s" % [target.health.current, target.sim_position()])
		for ranger: Unit in world.units_of(0):
			if ranger.def.id == &"concord_ranger":
				print(
					(
						"  ranger %s order %s target %s"
						% [
							ranger.sim_position(),
							(
								ranger.orders.current.kind
								if ranger.orders.current != null
								else &"idle"
							),
							ranger.weapon.target
						]
					)
				)
		var lander: Building = map.runner.player_hq
		print(
			(
				"  dock %s path %d reactor at %s walkable %s"
				% [
					lander.dock_position(),
					world.paths.find_path(hauler.sim_position(), lander.dock_position()).size(),
					reactor.position,
					world.paths.is_walkable(hauler.sim_position())
				]
			)
		)
		for building: Building in world.buildings_of(0):
			print(
				(
					"  %s id %d operational %s accepts %s work %.1f/%.1f"
					% [
						building.def.id,
						building.entity_id,
						building.is_operational(),
						building.accepts_alloy_from(0),
						building.construction.work,
						building.construction.build_time
					]
				)
			)
		print(
			(
				"carry on: hauler %s %s cargo %d pos %s travelling %s"
				% [
					hauler.orders.current.kind if hauler.orders.current != null else &"idle",
					hauler.harvester.state,
					hauler.harvester.cargo,
					hauler.sim_position(),
					hauler.locomotion.is_travelling()
				]
			)
		)
	assert_false(reactor.is_under_construction, "the Reactor completes")
	assert_true(site.is_resolved, "the scan finishes")
	assert_gt(world.economy.stockpile(0).intel, intel, "and pays out")
	assert_gt(hauler.harvester.deliveries, deliveries, "the hauler delivers")
	assert_gt(SaveFixture.count_of(world, 0, &"concord_hauler"), haulers, "the queue produces")
	assert_null(world.entity(target_id), "the Rangers destroy their target")
	assert_true(finished)


func _expect_the_mission_can_be_won(map: KesselProving) -> void:
	for unit: Unit in map.world.units_of(1):
		unit.health.take(1.0e9)
	for building: Building in map.world.buildings_of(1):
		building.health.take(1.0e9)
	var over: Callable = func() -> bool: return map.runner.result != null
	assert_true(await _f.run_until(map, over, 50), "the mission ends")
	assert_true(map.runner.result != null and map.runner.result.won, "won")


static func _ids(units: Array[Unit]) -> Array[int]:
	var ids: Array[int] = []
	for unit: Unit in units:
		ids.append(unit.entity_id)
	return ids


static func _nearest_site(world: SimWorld, from: Vector3) -> DiscoverySite:
	var best: DiscoverySite = null
	for site: DiscoverySite in world.discovery.sites:
		if not site.can_be_scanned():
			continue
		if best == null or site.position.distance_to(from) < best.position.distance_to(from):
			best = site
	return best
