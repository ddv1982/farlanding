class_name Commander
extends Node
## The enemy commander for one faction (PLAN 3.5, ADR 0008). On a slow, staggered tick
## it looks through its own faction's eyes (AiKnowledge), builds a CommanderView,
## lets the CommanderBrain decide (opening from data, then goal scoring) and turns the
## AiActions into Commands on the mission's CommandQueue, or into unit behaviours
## (AttackGroup, ScoutBehaviour) that issue Commands themselves. It plays by the
## player's rules: same definitions, same costs and build times, same command path,
## and it knows only what its vision grid has seen.

## Emitted after each decision with what was decided.
signal decided(actions: Array[AiAction])
## A notable event in words (wave launched, building placed ...), for logs and tests.
signal logged(text: String)

const SAVE_VERSION: int = 1
## Sim ticks between attempts to order the same idle harvester or builder.
const IDLE_RETRY_TICKS: int = 100
## Enemies seen this recently near home count as a threat.
const THREAT_TICKS: int = 30
## A scout skips a sector it could not reach for this long.
const UNREACHABLE_TICKS: int = 1200
## Site search: rings around the anchor, metres.
const SITE_RINGS: Array[float] = [
	0.0, 8.0, 12.0, 16.0, 20.0, 24.0, 28.0, 32.0, 38.0, 44.0, 50.0, 57.0, 64.0
]
const SITE_DIRECTIONS: int = 16
## New buildings keep this far from producers' doors and drop-off docks.
const DOOR_CLEARANCE: float = 7.0
## New buildings need open ground this far around them: none in a corridor, where it
## would choke the base's own exits.
const OPEN_MARGIN: float = 6.0
## Share of the ring around a new building that must be open ground.
const OPEN_SHARE: float = 0.9
## Perception: own sight sources are merged per cell of this size.
const SOURCE_CELL: float = 8.0
## A site the placement rules refused (something it had not seen was in the way) is
## not tried again for this long, in sim ticks.
const REFUSED_SITE_TICKS: int = 1200

var context: MissionContext
var world: SimWorld
var faction: int = 1
var profile: CommanderProfile
var difficulty: CommanderDifficulty
var knowledge: AiKnowledge
var memory: CommanderMemory = CommanderMemory.new()
var brain: CommanderBrain
var port: WorldAiPort
## Prints a line per notable decision (play-testing).
var verbose: bool = false
var attack_group: AttackGroup = null
var defence_group: AttackGroup = null
var scout: ScoutBehaviour = null
## The faction's own surveyors scanning sites for Intel (profiles with a surveyor).
var survey: SurveyBehaviour = null
## The squad taking an artefact home (profile `retrieves_cargo`), or null.
var retrieval: RetrieveGroup = null
## Venting, fleeing and siphons on an erupting planet (ADR 0015).
var vents: VentKeeper = null
## The faction's patrols when the mission has them (Verdance's Hornet watch), or null:
## their units are never taken into the army.
var guards: GuardCommander = null
## Where the base is, and where new army units wait.
var home: Vector3 = Vector3.ZERO
var staging: Vector3 = Vector3.ZERO
## Cost of decisions (perception + view + brain + commands), wall clock.
var decisions: int = 0
var last_decision_usec: int = 0
var max_decision_usec: int = 0
var total_decision_usec: int = 0
## Cost of behaviour steps, wall clock.
var last_behaviour_usec: int = 0
var max_behaviour_usec: int = 0
## Waves and their sizes so far (play-testing).
var wave_sizes: Array[int] = []

var _phase: int = 0
var _map_area: Rect2 = Rect2()
var _last_ordered: Dictionary[int, int] = {}
var _view: CommanderView = null
## Footprints of sites the placement rules refused -> sim tick they are forgotten.
var _refused_sites: Dictionary[Rect2, int] = {}


## Starts commanding `p_faction` in `p_world`. `difficulty_id` is &"easy", &"normal"
## or &"hard". `map_area` is split into scouting sectors.
func setup(
	p_context: MissionContext,
	p_world: SimWorld,
	p_faction: int,
	p_profile: CommanderProfile,
	difficulty_id: StringName,
	map_area: Rect2,
) -> void:
	context = p_context
	world = p_world
	faction = p_faction
	profile = p_profile
	difficulty = profile.difficulty(difficulty_id)
	_map_area = map_area
	port = WorldAiPort.new(context, world, faction)
	vents = VentKeeper.new(port, world, profile)
	knowledge = AiKnowledge.new(faction, CommanderDifficulty.ticks(profile.memory_seconds))
	knowledge.setup_sectors(map_area, profile.sector_size, world.paths.is_terrain_walkable)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = profile.random_seed + faction
	brain = CommanderBrain.new(profile, difficulty, memory, rng)
	# Stagger: commanders of different factions (and the vision round robin) do not
	# all land on the same tick.
	_phase = (faction * 7 + 3) % difficulty.decision_interval_ticks
	# Home and staging are found on the first decision: the navigation map is only
	# ready to answer queries after its first synchronisation.
	context.sim_clock.ticked.connect(_on_ticked)
	context.command_queue.command_executed.connect(_on_command_executed)


## Average decision cost so far, in microseconds.
func average_decision_usec() -> float:
	return float(total_decision_usec) / decisions if decisions > 0 else 0.0


## The last decision's snapshot (debugging).
func last_view() -> CommanderView:
	return _view


func _on_ticked(tick: int) -> void:
	var interval: int = profile.behaviour_interval_ticks
	if (tick + _phase) % interval == 0:
		_tick_behaviours(tick)
	if (tick + _phase) % difficulty.decision_interval_ticks == 0:
		_decide(tick)


## A placement of ours was refused by the real rules: something it did not know of
## stands there. Leave that ground alone for a while (the refusal is what the player
## would hear too).
func _on_command_executed(command: Command) -> void:
	var placing: PlaceBuildingCommand = command as PlaceBuildingCommand
	if placing == null or placing.issuer_faction != faction or placing.building_def == null:
		return
	if (
		placing.refused == PlacementRules.OK
		or placing.refused == PlaceBuildingCommand.NOT_AFFORDABLE
	):
		return
	var area: Rect2 = placing.building_def.world_footprint(placing.target_position)
	_refused_sites[area] = port.now() + REFUSED_SITE_TICKS
	_log("placing %s refused (%s)" % [placing.building_def.id, placing.refused])


func _decide(tick: int) -> void:
	var started: int = Time.get_ticks_usec()
	_update_home()
	_staff_survey(tick)
	_staff_retrieval(tick)
	perceive(tick)
	_view = build_view(tick)
	var put_to_work: Unit = vents.decide(home, _view.idle_builders)
	if put_to_work != null:
		_last_ordered[put_to_work.entity_id] = tick
		_view.idle_builders.erase(put_to_work)
	var actions: Array[AiAction] = brain.decide(_view)
	for action: AiAction in actions:
		_apply(action, tick)
	last_decision_usec = Time.get_ticks_usec() - started
	max_decision_usec = maxi(max_decision_usec, last_decision_usec)
	total_decision_usec += last_decision_usec
	decisions += 1
	decided.emit(actions)


func _tick_behaviours(tick: int) -> void:
	var started: int = Time.get_ticks_usec()
	for group: AiGroup in [attack_group, defence_group, scout, survey, retrieval]:
		if group != null:
			group.tick(tick)
	if attack_group != null and attack_group.finished:
		_log(
			"wave ended (%s), %d back" % [attack_group.retreat_reason, attack_group.members.size()]
		)
		attack_group = null
	if defence_group != null and defence_group.finished:
		defence_group = null
	if scout != null and scout.finished:
		scout = null
	if retrieval != null and retrieval.finished:
		retrieval = null
	last_behaviour_usec = Time.get_ticks_usec() - started
	max_behaviour_usec = maxi(max_behaviour_usec, last_behaviour_usec)


## Looks through the faction's own eyes: every own unit and building reports the
## enemies its faction sees within its vision range.
func perceive(tick: int) -> void:
	var sources: Dictionary[Vector2i, Vector4] = {}
	for unit: Unit in world.units_of(faction):
		if not unit.is_dead and unit.def != null:
			_add_source(sources, unit.sim_position(), unit.def.vision_range)
	for building: Building in world.buildings_of(faction):
		if not building.is_dead and building.def != null:
			_add_source(sources, building.position, building.def.vision_range)
	if world.vision == null:
		# Fog switched off: the faction sees the whole map, so look at all of it.
		# Forgetting below then also treats everything as visible, consistently.
		var centre: Vector2 = _map_area.get_center()
		sources = {Vector2i.ZERO: Vector4(centre.x, home.y, centre.y, _map_area.size.length())}
	var seen: Dictionary[Node3D, bool] = {}
	for source: Vector4 in sources.values():
		var at: Vector3 = Vector3(source.x, source.y, source.z)
		for enemy: Node3D in port.seen_enemies(at, source.w):
			seen[enemy] = true
	var found: Array[Node3D] = []
	found.assign(seen.keys())
	var known_before: int = knowledge.known_buildings().size()
	knowledge.observe(found, tick)
	if world.vision != null:
		var grid: VisionGrid = world.vision.grid
		knowledge.forget(
			tick,
			func(area: Rect2) -> bool: return grid.is_area_visible(faction, area),
			func(point: Vector3) -> bool: return grid.is_visible(faction, point)
		)
	else:
		# Fog switched off: everything is in view, so what was not seen is gone.
		knowledge.forget(
			tick,
			func(_area: Rect2) -> bool: return true,
			func(_point: Vector3) -> bool: return true
		)
	if knowledge.known_buildings().size() > known_before and known_before == 0:
		_log("found enemy buildings")


static func _add_source(sources: Dictionary[Vector2i, Vector4], at: Vector3, radius: float) -> void:
	var cell: Vector2i = Vector2i(floori(at.x / SOURCE_CELL), floori(at.z / SOURCE_CELL))
	# One query per cell, placed at the first source and widened so it encloses the
	# sight disc of any source in the same cell. Over-reaching is safe: the vision
	# grid still rejects what the faction cannot see.
	var padded: float = radius + SOURCE_CELL * sqrt(2.0)
	var known: Vector4 = sources.get(cell, Vector4(at.x, at.y, at.z, 0.0))
	sources[cell] = Vector4(known.x, known.y, known.z, maxf(known.w, padded))


## The snapshot the brain decides from: own forces in full, the enemy as known.
func build_view(tick: int) -> CommanderView:
	var view: CommanderView = CommanderView.new()
	view.tick = tick
	var pile: Stockpile = world.economy.stockpile(faction)
	view.alloy = pile.alloy
	view.flux = pile.flux
	view.power_free = pile.power_produced - pile.power_used
	view.home = home
	view.staging = staging
	for building: Building in world.buildings_of(faction):
		if building.is_dead:
			continue
		view.building_counts[building.def.id] = view.building_counts.get(building.def.id, 0) + 1
		if building.is_under_construction:
			view.sites.append(building)
		elif building.producer != null:
			view.producers.append(building)
			for queued: UnitDef in building.producer.queue:
				view.unit_counts[queued.id] = view.unit_counts.get(queued.id, 0) + 1
	view.storm_intensity = port.storm_intensity()
	view.storm_eta_seconds = port.storm_eta_seconds()
	view.storm_is_final = port.storm_is_final()
	view.tide_level = port.tide_level()
	view.shallows_close_seconds = port.shallows_close_seconds()
	view.survey_open = _survey_open(tick)
	if survey != null:
		view.surveying = survey.members.size()
	var grouped: Dictionary[Unit, bool] = {}
	for group: AiGroup in [attack_group, defence_group, scout, survey, retrieval]:
		if group != null:
			for unit: Unit in group.members:
				grouped[unit] = true
	if guards != null:
		for unit: Unit in guards.guards():
			grouped[unit] = true
	for unit: Unit in world.units_of(faction):
		if unit.is_dead or unit.def == null:
			continue
		view.unit_counts[unit.def.id] = view.unit_counts.get(unit.def.id, 0) + 1
		if unit.def == profile.surveyor:
			view.surveyor_count += 1
		if grouped.has(unit) and survey != null and survey.has_member(unit):
			continue
		var idle: bool = unit.orders != null and unit.orders.is_idle()
		var may_order: bool = (
			tick - _last_ordered.get(unit.entity_id, -IDLE_RETRY_TICKS) >= IDLE_RETRY_TICKS
		)
		if unit.builder != null:
			view.builders.append(unit)
			if idle and may_order:
				view.idle_builders.append(unit)
		elif unit.harvester != null:
			if idle and may_order:
				view.idle_harvesters.append(unit)
		elif unit.weapon != null:
			view.army.append(unit)
			view.army_strength += AiKnowledge.strength_of(unit)
			if not grouped.has(unit):
				view.guards.append(unit)
				view.guard_strength += AiKnowledge.strength_of(unit)
	view.deposits_near_home = _known_deposits(home, profile.deposit_radius).size()
	var threat: Vector4 = knowledge.threat_near(home, profile.base_radius, tick, THREAT_TICKS)
	view.threat_strength = threat.w
	view.threat_position = Vector3(threat.x, threat.y, threat.z)
	var target: Vector3 = knowledge.attack_target(home, tick, profile.base_radius * 1.5)
	view.has_target = target != Vector3.INF
	view.attack_target = target if view.has_target else Vector3.ZERO
	view.known_enemy_buildings = knowledge.known_buildings().size()
	view.enemy_heavy_share = knowledge.heavy_share()
	view.enemy_air_share = knowledge.air_share()
	view.explored_share = knowledge.explored_share()
	view.scout_active = scout != null
	view.attack_active = attack_group != null
	view.defence_active = defence_group != null
	return view


func _apply(action: AiAction, tick: int) -> void:
	match action.kind:
		AiAction.PRODUCE:
			port.push(ProduceCommand.new(faction, action.building, action.def as UnitDef))
		AiAction.BUILD:
			_place(action, tick)
		AiAction.HARVEST:
			_harvest(action.units, tick)
		AiAction.ASSIST:
			for unit: Unit in action.units:
				_last_ordered[unit.entity_id] = tick
			port.push(BuildCommand.new(faction, AiGroup._as_nodes(action.units), action.building))
		AiAction.SCOUT:
			_send_scout(action.units[0])
		AiAction.ATTACK:
			_launch(action)
		AiAction.DEFEND:
			defence_group = _make_attack(
				action.units, AttackGroup.MODE_DEFEND, action.position, staging, staging
			)
			defence_group.start()
			_log("defending home with %d" % action.units.size())
		AiAction.RECALL:
			if attack_group != null:
				attack_group.recall()
				_log("wave recalled to defend home")


func _place(action: AiAction, tick: int) -> void:
	var def: BuildingDef = action.def as BuildingDef
	var spot: Vector3 = find_site(def, action.position)
	if spot == Vector3.INF:
		memory.back_off(def, tick + CommanderDifficulty.ticks(CommanderBrain.BACKOFF_SECONDS))
		_log("no room for %s" % def.id)
		return
	for unit: Unit in action.units:
		_last_ordered[unit.entity_id] = tick
	port.push(PlaceBuildingCommand.new(faction, AiGroup._as_nodes(action.units), def, spot))
	_log("placing %s at (%d, %d)" % [def.id, roundi(spot.x), roundi(spot.z)])


func _harvest(units: Array[Unit], tick: int) -> void:
	var deposits: Array[ResourceNode] = _known_deposits(home, INF)
	for unit: Unit in units:
		_last_ordered[unit.entity_id] = tick
		var best: ResourceNode = null
		var best_distance: float = INF
		for node: ResourceNode in deposits:
			var distance: float = AiGroup.flat_distance(node.position, unit.sim_position())
			if distance < best_distance:
				best = node
				best_distance = distance
		if best != null:
			port.push(HarvestCommand.new(faction, [unit] as Array[Node3D], best))


func _send_scout(unit: Unit) -> void:
	scout = _make_scout(unit)
	scout.start()
	_log("scout out (%s)" % unit.def.id)


func _make_scout(unit: Unit) -> ScoutBehaviour:
	var made: ScoutBehaviour = ScoutBehaviour.new(port, profile, unit)
	var stale: int = CommanderDifficulty.ticks(profile.stale_seconds)
	made.next_point = func(from: Vector3) -> Vector3:
		return knowledge.next_scout_point(from, home, port.now(), stale)
	made.on_unreachable = func(point: Vector3) -> void:
		knowledge.block_sector_at(point, port.now() + UNREACHABLE_TICKS)
	return made


func _launch(action: AiAction) -> void:
	var last_stand: bool = action.reason == &"last_stand"
	var target: Vector3 = action.position
	if target == Vector3.INF:
		target = knowledge.next_scout_point(staging, home, port.now(), 0)
	if target == Vector3.INF:
		return
	attack_group = _make_attack(
		action.units,
		AttackGroup.MODE_LAST_STAND if last_stand else AttackGroup.MODE_ATTACK,
		target,
		staging,
		staging
	)
	attack_group.start()
	wave_sizes.append(action.units.size())
	_log(
		(
			"%s: %d units (strength %d) -> (%d, %d)"
			% [
				action.reason,
				action.units.size(),
				roundi(attack_group.initial_strength),
				roundi(target.x),
				roundi(target.z)
			]
		)
	)


func _make_attack(
	units: Array[Unit],
	mode: StringName,
	target: Vector3,
	group_home: Vector3,
	group_staging: Vector3
) -> AttackGroup:
	var made: AttackGroup = AttackGroup.new(
		port, profile, units, mode, target, group_home, group_staging
	)
	if mode == AttackGroup.MODE_DEFEND:
		return made
	var last_stand: bool = mode == AttackGroup.MODE_LAST_STAND
	made.next_target = func(from: Vector3) -> Vector3:
		var next: Vector3 = knowledge.attack_target(from, port.now())
		if next == Vector3.INF and last_stand:
			# Searching: the sector just reached is done for a while.
			knowledge.block_sector_at(from, port.now() + UNREACHABLE_TICKS)
			next = knowledge.next_scout_point(from, home, port.now(), 0)
		return next
	return made


## The commander's state for a saved game (ADR 0013): its memory and dice, what it
## knows, its base, and its running groups (members by save id).
func to_dict() -> Dictionary:
	var ordered: Dictionary = {}
	for id: int in _last_ordered:
		ordered[str(id)] = _last_ordered[id]
	var refused: Array = []
	for area: Rect2 in _refused_sites:
		refused.append([var_to_str(area), _refused_sites[area]])
	return {
		"version": SAVE_VERSION,
		"memory": memory.to_dict(),
		"rng": str(brain.rng.state),
		"knowledge": knowledge.to_dict(),
		"home": var_to_str(home),
		"staging": var_to_str(staging),
		"wave_sizes": wave_sizes.duplicate(),
		"last_ordered": ordered,
		"refused": refused,
		"attack": _group_dict(attack_group),
		"defence": _group_dict(defence_group),
		"scout": _group_dict(scout),
		"survey": _group_dict(survey),
		"retrieval": _group_dict(retrieval),
	}


## Restores what `to_dict()` saved into a commander that was just `setup()`.
func from_dict(data: Dictionary) -> void:
	var memory_data: Dictionary = data.get("memory", {})
	if not memory_data.is_empty():
		memory.from_dict(memory_data)
	var rng_text: String = data.get("rng", "")
	if rng_text != "":
		brain.rng.state = int(rng_text)
	var knowledge_data: Dictionary = data.get("knowledge", {})
	knowledge.from_dict(knowledge_data, world.entity)
	var home_text: String = data.get("home", var_to_str(home))
	home = str_to_var(home_text)
	var staging_text: String = data.get("staging", var_to_str(staging))
	staging = str_to_var(staging_text)
	var sizes: Array = data.get("wave_sizes", [])
	wave_sizes.clear()
	for entry: Variant in sizes:
		var size: int = entry
		wave_sizes.append(size)
	var ordered: Dictionary = data.get("last_ordered", {})
	for key: Variant in ordered:
		var tick: int = ordered[key]
		_last_ordered[int(str(key))] = tick
	var refused: Array = data.get("refused", [])
	for entry: Variant in refused:
		var pair: Array = entry
		var area_text: String = pair[0]
		var until: int = pair[1]
		var area: Rect2 = str_to_var(area_text)
		_refused_sites[area] = until
	var attack_data: Dictionary = data.get("attack", {})
	var defence_data: Dictionary = data.get("defence", {})
	var scout_data: Dictionary = data.get("scout", {})
	attack_group = _restore_attack(attack_data)
	defence_group = _restore_attack(defence_data)
	scout = _restore_scout(scout_data)
	var survey_data: Dictionary = data.get("survey", {})
	if not survey_data.is_empty():
		var ids: Array = survey_data.get("members", [])
		survey = SurveyBehaviour.new(port, profile, AiGroup.units_from_ids(ids, world.entity))
		survey.restore(survey_data, world.entity)
	var retrieval_data: Dictionary = data.get("retrieval", {})
	retrieval = _restore_retrieval(retrieval_data)


static func _group_dict(group: AiGroup) -> Dictionary:
	if group == null or group.finished:
		return {}
	return group.to_dict()


func _restore_attack(data: Dictionary) -> AttackGroup:
	var ids: Array = data.get("members", [])
	var units: Array[Unit] = AiGroup.units_from_ids(ids, world.entity)
	if units.is_empty():
		return null
	var mode: String = data.get("mode", String(AttackGroup.MODE_ATTACK))
	var target_text: String = data.get("target", var_to_str(staging))
	var home_text: String = data.get("home", var_to_str(staging))
	var staging_text: String = data.get("staging", var_to_str(staging))
	var target: Vector3 = str_to_var(target_text)
	var group_home: Vector3 = str_to_var(home_text)
	var group_staging: Vector3 = str_to_var(staging_text)
	var group: AttackGroup = _make_attack(
		units, StringName(mode), target, group_home, group_staging
	)
	group.from_dict(data)
	return group


func _restore_scout(data: Dictionary) -> ScoutBehaviour:
	var ids: Array = data.get("members", [])
	var units: Array[Unit] = AiGroup.units_from_ids(ids, world.entity)
	if units.is_empty():
		return null
	var restored: ScoutBehaviour = _make_scout(units[0])
	restored.from_dict(data)
	return restored


## Sends a squad of idle armed units for a carriable prop it knows of (Recovery),
## once the profile's delay has passed; keeps the squad's home up to date.
func _staff_retrieval(tick: int) -> void:
	if not profile.retrieves_cargo:
		return
	if tick < CommanderDifficulty.ticks(profile.retrieve_after_seconds):
		return
	if retrieval != null:
		retrieval.home = home
		return
	var wanted: Prop = null
	for prop: Prop in port.known_cargo():
		wanted = prop
		break
	if wanted == null:
		return
	var busy: Dictionary[Unit, bool] = {}
	for group: AiGroup in [attack_group, defence_group, scout, survey]:
		if group != null:
			for unit: Unit in group.members:
				busy[unit] = true
	var squad: Array[Unit] = []
	for unit: Unit in world.units_of(faction):
		if squad.size() >= profile.retrieve_squad_size:
			break
		if unit.is_dead or unit.weapon == null or busy.has(unit) or unit.is_dormant:
			continue
		if unit.orders != null and unit.orders.is_idle():
			squad.append(unit)
	if squad.is_empty():
		return
	retrieval = RetrieveGroup.new(port, profile, squad, wanted)
	retrieval.home = home
	retrieval.start()
	_log("retrieval squad of %d sent for %s" % [squad.size(), wanted.name])


func _restore_retrieval(data: Dictionary) -> RetrieveGroup:
	var ids: Array = data.get("members", [])
	var units: Array[Unit] = AiGroup.units_from_ids(ids, world.entity)
	var cargo_id: int = data.get("cargo", -1)
	var cargo: Prop = world.entity(cargo_id) as Prop if cargo_id >= 0 else null
	if units.is_empty() or cargo == null:
		return null
	var restored: RetrieveGroup = RetrieveGroup.new(port, profile, units, cargo)
	restored.from_dict(data)
	return restored


## True once the profile's survey may start (it has a surveyor and the delay passed).
func _survey_open(tick: int) -> bool:
	if profile.surveyor == null or profile.surveyors_wanted <= 0:
		return false
	return tick >= CommanderDifficulty.ticks(profile.survey_after_seconds)


## Puts idle units of the surveyor kind to work scanning, keeping one as a builder.
func _staff_survey(tick: int) -> void:
	if not _survey_open(tick):
		return
	if survey == null:
		survey = SurveyBehaviour.new(port, profile, [])
		_log("survey started")
	survey.home = home
	var spare: Array[Unit] = []
	var builders_left: int = 0
	for unit: Unit in world.units_of(faction):
		if unit.is_dead or unit.def != profile.surveyor or survey.has_member(unit):
			continue
		if unit.scanner == null:
			continue
		builders_left += 1
		if unit.orders != null and unit.orders.is_idle():
			spare.append(unit)
	for unit: Unit in spare:
		if survey.members.size() >= profile.surveyors_wanted or builders_left <= 1:
			break
		survey.add(unit)
		builders_left -= 1
		_log("surveyor out (%s)" % unit.def.id)


## Minable deposits the faction has explored within `radius` of `from`.
func _known_deposits(from: Vector3, radius: float) -> Array[ResourceNode]:
	var found: Array[ResourceNode] = []
	for node: ResourceNode in _explored_nodes():
		if not node.is_minable() or node.is_flooded or node.resource() != &"alloy":
			continue
		if AiGroup.flat_distance(node.position, from) > radius:
			continue
		found.append(node)
	return found


## Resource nodes (deposits and vents) on ground the faction has explored.
func _explored_nodes() -> Array[ResourceNode]:
	var found: Array[ResourceNode] = []
	for node: ResourceNode in world.resource_nodes:
		if world.vision == null or world.vision.grid.is_area_explored(faction, node.blocked_area()):
			found.append(node)
	return found


## Placement rules over what the faction may know: terrain, bounds, its own
## buildings, the enemy buildings it remembers seeing, sites refused lately, and the
## resource nodes it has explored. Never the live footprints of unseen buildings; the
## real rules still judge the PlaceBuildingCommand when it runs.
func known_placement_rules() -> PlacementRules:
	var rules: PlacementRules = world.placement_rules()
	rules.footprints = []
	for building: Building in world.buildings_of(faction):
		rules.footprints.append(building.footprint())
	for sighting: AiSighting in knowledge.known_buildings():
		rules.footprints.append(sighting.footprint)
	var now: int = port.now()
	for area: Rect2 in _refused_sites.keys():
		if _refused_sites[area] > now:
			rules.footprints.append(area)
		else:
			_refused_sites.erase(area)
	rules.nodes = _explored_nodes()
	return rules


## A free spot for `def` near `near`: rings outward, the first spot the placement
## rules accept that keeps doors, docks and deposits clear, judged only on what the
## faction knows (`known_placement_rules`). Vector3.INF if none.
func find_site(def: BuildingDef, near: Vector3) -> Vector3:
	var rules: PlacementRules = known_placement_rules()
	var keep_clear: Array[Vector3] = []
	for building: Building in world.buildings_of(faction):
		if building.def.is_producer():
			keep_clear.append(building.door_position())
		if building.def.accepts_alloy:
			keep_clear.append(building.dock_position())
	var outward: Vector3 = staging - home
	var base_angle: float = atan2(outward.z, outward.x) if outward.length() > 0.1 else 0.0
	for ring: float in SITE_RINGS:
		var steps: int = 1 if ring == 0.0 else SITE_DIRECTIONS
		for k: int in steps:
			# Alternate either side of the outward direction: 0, +1, -1, +2, -2 ...
			var side: int = ceili(k * 0.5) * (1 if k % 2 == 1 else -1)
			var angle: float = base_angle + side * TAU / SITE_DIRECTIONS
			var spot: Vector3 = near + Vector3(cos(angle), 0.0, sin(angle)) * ring
			spot = Vector3(snappedf(spot.x, 0.5), spot.y, snappedf(spot.z, 0.5))
			if _site_ok(def, spot, rules, keep_clear):
				return spot
	return Vector3.INF


func _site_ok(
	def: BuildingDef, spot: Vector3, rules: PlacementRules, keep_clear: Array[Vector3]
) -> bool:
	var footprint: Rect2 = def.world_footprint(spot)
	var area: Rect2 = footprint.grow(DOOR_CLEARANCE * 0.5)
	for point: Vector3 in keep_clear:
		if area.has_point(Vector2(point.x, point.z)):
			return false
	for node: ResourceNode in rules.nodes:
		var reach: float = node.def.radius + def.footprint_radius() + 4.0
		if AiGroup.flat_distance(node.position, spot) < reach:
			return false
	var ring: Rect2 = footprint.grow(OPEN_MARGIN)
	return (
		not ring.has_point(Vector2(staging.x, staging.z))
		and (not def.is_producer() or _reachable(spot + def.door, rules))
		and (not def.accepts_alloy or _reachable(spot + def.dock, rules))
		and rules.check(def, spot) == PlacementRules.OK
		and _is_open(ring, rules)
	)


## True if the outline of `ring` is mostly open ground (walkable, no building).
func _is_open(ring: Rect2, rules: PlacementRules) -> bool:
	var samples: int = 0
	var open: int = 0
	for side: int in 4:
		for k: int in 6:
			var t: float = k / 6.0
			var corner: Vector2 = [
				ring.position,
				Vector2(ring.end.x, ring.position.y),
				ring.end,
				Vector2(ring.position.x, ring.end.y)
			][side]
			var next: Vector2 = [
				Vector2(ring.end.x, ring.position.y),
				ring.end,
				Vector2(ring.position.x, ring.end.y),
				ring.position
			][side]
			var at: Vector2 = corner.lerp(next, t)
			samples += 1
			if _reachable(Vector3(at.x, 0.0, at.y), rules):
				open += 1
	return float(open) / samples >= OPEN_SHARE


## True if units can stand at `point`: walkable ground clear of every building in
## `rules` (with the navmesh cut margin around them).
func _reachable(point: Vector3, rules: PlacementRules) -> bool:
	if not world.paths.is_terrain_walkable(point):
		return false
	var at: Vector2 = Vector2(point.x, point.z)
	for footprint: Rect2 in rules.footprints:
		if footprint.grow(NavmeshPathService.CUT_MARGIN + 0.5).has_point(at):
			return false
	return true


## Home is the HQ (else any building left); staging lies out in front, towards the
## middle of the map.
func _update_home() -> void:
	var anchor: Building = null
	for building: Building in world.buildings_of(faction):
		if building.is_dead:
			continue
		if building.def == profile.hq:
			anchor = building
			break
		if anchor == null:
			anchor = building
	if anchor == null:
		return
	var moved: bool = anchor.position.distance_to(home) > 1.0
	home = anchor.position
	if moved or staging == Vector3.ZERO:
		var centre: Vector3 = Vector3(_map_area.get_center().x, 0.0, _map_area.get_center().y)
		var out: Vector3 = centre - home
		out.y = 0.0
		staging = world.paths.closest_point(home + out.normalized() * 24.0)
	_rally_factories()


## Every own factory sends new units to the staging point.
func _rally_factories() -> void:
	var to_rally: Array[Node3D] = []
	for building: Building in world.buildings_of(faction):
		if (
			building.producer != null
			and building.def == profile.factory
			and not building.producer.has_rally_point
			and not building.is_dead
		):
			to_rally.append(building)
	if not to_rally.is_empty():
		port.push(RallyCommand.new(faction, to_rally, staging))


func _log(text: String) -> void:
	logged.emit(text)
	if verbose:
		var seconds: int = floori(context.sim_clock.get_tick() * SimClock.TICK_DELTA)
		print("[commander %d @%d:%02d] %s" % [faction, floori(seconds / 60.0), seconds % 60, text])
