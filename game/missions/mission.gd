class_name Mission
extends Node
## Runs one mission (PLAN 3.6, ADR 0010): puts the MissionDef's forces on the map,
## starts the enemy (base commander, guards and their alert meter), evaluates every
## objective and trigger on the sim tick and announces objective changes on
## `Events`. It decides the outcome: every non-passive primary objective done = won,
## any primary failed = lost; then `Events.mission_ended` and `finished` (with the
## debrief numbers). The conquest win/lose rules are ordinary objectives here.
##
## Order of use: `setup()`, `spawn_structures()`, (the map cuts its navmesh),
## `spawn_units()`, `start()`. Registered on the MissionContext as SERVICE_KEY.

## The mission is over; `result` holds what the debrief shows.
signal finished(result: MissionResult)

const SERVICE_KEY: StringName = &"mission"
const SAVE_VERSION: int = 1
## Seconds left on a countdown when the Advisor warns about it (once).
const TIME_LOW_SECONDS: float = 60.0

var def: MissionDef
var context: MissionContext
var world: SimWorld
var player_faction: int = 0
var map_area: Rect2 = Rect2(-120.0, -120.0, 240.0, 240.0)
var objectives: Array[Objective] = []
var triggers: Array[Trigger] = []
var script_instance: MissionScript = null
var commander: Commander = null
var guards: GuardCommander = null
## The player's HQ once spawned, or null.
var player_hq: Building = null
## Set once the mission is over.
var result: MissionResult = null
var started_tick: int = 0
var intel_earned: int = 0
var units_lost: int = 0
var buildings_lost: int = 0
var enemies_destroyed: int = 0
## Prints the commander's notable decisions (play-testing).
var log_enemy_ai: bool = false
## What the player brings from outside the landing (campaign tech and loadout), or
## null. Set before `setup()`.
var modifiers: LandingModifiers = null

var _last_intel: int = 0
var _warned: Dictionary[StringName, bool] = {}


## Prepares `p_def` in a set-up world (services, vision already on).
func setup(
	p_def: MissionDef, p_context: MissionContext, p_world: SimWorld, p_map_area: Rect2
) -> void:
	def = p_def
	context = p_context
	world = p_world
	player_faction = def.player_faction
	map_area = p_map_area
	context.set_service(SERVICE_KEY, self)
	if def.enemy_alert_meter and world.stealth != null:
		world.stealth.add_guard_faction(def.hostile_faction)
	var pile: Stockpile = world.economy.stockpile(player_faction)
	if def.start_alloy >= 0 or def.start_flux >= 0:
		pile.alloy = def.start_alloy if def.start_alloy >= 0 else pile.alloy
		pile.flux = def.start_flux if def.start_flux >= 0 else pile.flux
		Events.resources_changed.emit(player_faction, pile.alloy, pile.flux)
	if def.start_intel > 0:
		world.economy.add_intel(player_faction, def.start_intel)
	if modifiers != null:
		modifiers.apply_to_world(world, player_faction)
	# After the perks: a rule may add to them (Hollow Meridian locks the Reactor).
	if def.planet != null and def.planet.rule != null:
		PlanetRuleSystem.start(world, def.planet.rule)
	_last_intel = pile.intel


## Places the buildings: the player's HQ and the enemy base; then the mission's props.
func spawn_structures() -> void:
	if def.player_hq != null:
		player_hq = world.spawn_building(def.player_hq, player_faction, def.player_start, true)
	if def.hostile_hq != null:
		world.spawn_building(def.hostile_hq, def.hostile_faction, def.hostile_hq_position, true)
	for i: int in mini(def.hostile_buildings.size(), def.hostile_building_positions.size()):
		world.spawn_building(
			def.hostile_buildings[i], def.hostile_faction, def.hostile_building_positions[i], true
		)
	if def.props != null:
		for placement: PropPlacement in def.props.placements:
			if placement != null and placement.def != null:
				world.spawn_prop(placement.def, placement.position, placement.quarter_turns)


## Places the units: the player's crew or squad, the enemy crew and the guards.
func spawn_units() -> void:
	var crew_at: Vector3 = def.player_start
	var facing: Vector3 = def.player_facing
	if player_hq != null:
		crew_at = player_hq.door_position() + Vector3(0.0, 0.0, -5.0)
		facing = Vector3.FORWARD
	var crew: Array[UnitDef] = def.player_roster.duplicate()
	if modifiers != null:
		crew.append_array(modifiers.extra_roster)
	for unit: Unit in spawn_group(crew, player_faction, crew_at, facing):
		if unit.harvester != null:
			world.auto_harvest(unit, unit.sim_position())
	var hostile: Array[Unit] = spawn_group(
		def.hostile_roster, def.hostile_faction, def.hostile_start, def.hostile_facing
	)
	for unit: Unit in hostile:
		if unit.harvester != null:
			world.auto_harvest(unit, unit.sim_position())
	if not def.patrols.is_empty():
		guards = GuardCommander.new()
		guards.name = &"Guards"
		add_child(guards)
		guards.setup(context, world, def.hostile_faction)
		for route: PatrolRoute in def.patrols:
			if route == null or route.unit == null or route.waypoints.is_empty():
				continue
			var roster: Array[UnitDef] = []
			for i: int in route.count:
				roster.append(route.unit)
			guards.add_patrol(
				route, spawn_group(roster, def.hostile_faction, route.waypoints[0], route.facing)
			)


## Starts the enemy AI, the objectives and the script.
func start() -> void:
	started_tick = now()
	_start_commander()
	if def.enemy_alert_meter:
		# Tells presentation and audio that this is a stealth mission from the first frame.
		Events.alert_level_changed.emit(
			def.hostile_faction, StealthSystem.LEVEL_UNAWARE, StealthSystem.LEVEL_UNAWARE
		)
	_listen()
	for objective_def: ObjectiveDef in def.starting_objectives():
		add_objective_def(objective_def)
	_schedule_climax()
	_make_script()
	if script_instance != null:
		script_instance.on_started()


## Picks up a saved game instead of `spawn_units()` and `start()` (ADR 0013): the
## world was restored from its save first (forces, buildings, sites, the storm). Brings
## back the enemy AI, the guards, the objectives, the triggers and the script as
## `to_dict()` saved them, then announces the restored state on `Events` (objectives,
## alert level) so the HUD, markers and audio follow it.
func resume(data: Dictionary) -> void:
	started_tick = data.get("started_tick", now())
	intel_earned = data.get("intel_earned", 0)
	units_lost = data.get("units_lost", 0)
	buildings_lost = data.get("buildings_lost", 0)
	enemies_destroyed = data.get("enemies_destroyed", 0)
	_last_intel = data.get("last_intel", world.economy.stockpile(player_faction).intel)
	var warned: Array = data.get("warned", [])
	for entry: Variant in warned:
		_warned[StringName(str(entry))] = true
	var hq_id: int = data.get("hq", -1)
	player_hq = world.entity(hq_id) as Building if hq_id >= 0 else null
	_start_commander()
	var commander_data: Dictionary = data.get("commander", {})
	if commander != null and not commander_data.is_empty():
		commander.from_dict(commander_data)
	var guards_data: Dictionary = data.get("guards", {})
	if not guards_data.is_empty():
		guards = GuardCommander.new()
		guards.name = &"Guards"
		add_child(guards)
		guards.setup(context, world, def.hostile_faction)
		guards.from_dict(guards_data, def.patrols)
		if commander != null:
			commander.guards = guards
	_listen()
	_make_script()
	var saved_objectives: Array = data.get("objectives", [])
	for entry: Variant in saved_objectives:
		var objective_data: Dictionary = entry
		var objective_id: String = objective_data.get("id", "")
		var objective_def: ObjectiveDef = _objective_def(objective_id)
		var restored: Objective = (
			ObjectiveFactory.create(objective_def) if objective_def != null else null
		)
		if restored == null:
			continue
		restored.mission = self
		restored.from_dict(objective_data)
		objectives.append(restored)
	if script_instance != null:
		var script_data: Dictionary = data.get("script", {})
		script_instance.from_dict(script_data)
		script_instance.on_resumed()
	var saved_triggers: Array = data.get("triggers", [])
	for i: int in mini(saved_triggers.size(), triggers.size()):
		var trigger_data: Dictionary = saved_triggers[i]
		triggers[i].from_dict(trigger_data)
	for found: Objective in objectives:
		if found.is_known:
			Events.objective_added.emit(found)
	if def.enemy_alert_meter and world.stealth != null:
		var level: StringName = world.stealth.alert_level(def.hostile_faction)
		Events.alert_level_changed.emit(def.hostile_faction, level, level)


## The mission's run-time state for a saved game (the world saves itself).
func to_dict() -> Dictionary:
	var saved_objectives: Array[Dictionary] = []
	for found: Objective in objectives:
		saved_objectives.append(found.to_dict())
	var saved_triggers: Array[Dictionary] = []
	for trigger: Trigger in triggers:
		saved_triggers.append(trigger.to_dict())
	var warned: Array[String] = []
	for key: StringName in _warned:
		warned.append(String(key))
	return {
		"version": SAVE_VERSION,
		"mission": String(def.id),
		"started_tick": started_tick,
		"intel_earned": intel_earned,
		"units_lost": units_lost,
		"buildings_lost": buildings_lost,
		"enemies_destroyed": enemies_destroyed,
		"last_intel": _last_intel,
		"warned": warned,
		"hq": Order.entity_id_of(player_hq),
		"objectives": saved_objectives,
		"triggers": saved_triggers,
		"script": script_instance.to_dict() if script_instance != null else {},
		"commander": commander.to_dict() if commander != null else {},
		"guards": guards.to_dict(def.patrols) if guards != null else {},
	}


## Spawns `defs` as one formation centred on `center`, facing `facing`.
func spawn_group(
	defs: Array[UnitDef], faction: int, center: Vector3, facing: Vector3
) -> Array[Unit]:
	var spawned: Array[Unit] = []
	if defs.is_empty():
		return spawned
	var radii: PackedFloat32Array = PackedFloat32Array()
	for unit_def: UnitDef in defs:
		radii.append(unit_def.radius)
	var formation: Formation = Formation.new(
		defs.size(), center, facing, Formation.spacing_for(radii), world.paths.is_walkable
	)
	var yaw: float = Mover.yaw_for(formation.forward)
	for i: int in defs.size():
		spawned.append(world.spawn_unit(defs[i], faction, formation.slots[i], yaw))
	return spawned


## The current sim tick.
func now() -> int:
	return context.sim_clock.get_tick()


## Game seconds since the mission started.
func elapsed_seconds() -> float:
	return float(now() - started_tick) / SimClock.TICK_RATE


## The factions the player fights (Custodians are neutral and never listed).
func enemy_factions() -> Array[int]:
	return [def.hostile_faction]


## Creates and starts the objective `objective_def` describes.
func add_objective_def(objective_def: ObjectiveDef) -> Objective:
	var objective: Objective = ObjectiveFactory.create(objective_def)
	if objective != null:
		add_objective(objective)
	return objective


## Starts `objective` and announces it (unless hidden).
func add_objective(objective: Objective) -> void:
	objectives.append(objective)
	objective.start(self)
	if objective.is_known:
		Events.objective_added.emit(objective)
	objective.evaluate()


## The objective with `objective_id`, or null.
func objective(objective_id: StringName) -> Objective:
	for found: Objective in objectives:
		if found.id == objective_id:
			return found
	return null


## Known objectives, in the order they were added.
func known_objectives() -> Array[Objective]:
	var known: Array[Objective] = []
	for found: Objective in objectives:
		if found.is_known:
			known.append(found)
	return known


## Starts checking `trigger` every sim tick.
func add_trigger(trigger: Trigger) -> Trigger:
	triggers.append(trigger)
	trigger.start(self)
	return trigger


## Called by an objective when its progress or area changed.
func on_objective_progress(changed: Objective) -> void:
	if changed.is_known and objectives.has(changed):
		Events.objective_updated.emit(changed)


## Called by an objective when it was achieved or failed.
func on_objective_finished(changed: Objective) -> void:
	if changed.state == Objective.STATE_DONE:
		if not changed.is_known:
			changed.is_known = true
			Events.objective_added.emit(changed)
		Events.objective_completed.emit(changed)
	elif changed.is_known:
		Events.objective_failed.emit(changed)
	if script_instance != null and result == null:
		script_instance.on_objective_finished(changed)


## The outcome the objectives call for now: 1 won, -1 lost, 0 still open.
func evaluate_outcome() -> int:
	var open_primaries: int = 0
	var primaries: int = 0
	for found: Objective in objectives:
		if found.kind != Objective.KIND_PRIMARY:
			continue
		primaries += 1
		if found.state == Objective.STATE_FAILED:
			return -1
		if found.state == Objective.STATE_ACTIVE and not found.passive:
			open_primaries += 1
	if primaries > 0 and open_primaries == 0 and _has_goal():
		return 1
	return 0


## Ends the mission now (`won` decides), as if the objectives had called it.
func finish(won: bool) -> void:
	if result != null:
		return
	if won:
		for found: Objective in objectives.duplicate():
			found.on_mission_won()
	result = MissionResult.new()
	result.mission_id = def.id
	result.title = def.title
	result.won = won
	result.seconds = elapsed_seconds()
	result.intel_earned = intel_earned
	result.units_lost = units_lost
	result.buildings_lost = buildings_lost
	result.enemies_destroyed = enemies_destroyed
	result.difficulty = (
		Difficulty.sanitize(modifiers.difficulty)
		if modifiers != null and modifiers.difficulty != &""
		else &""
	)
	result.intel_held = world.economy.stockpile(player_faction).intel
	if world.discovery != null:
		for found: DiscoveryDef in world.discovery.codex(player_faction):
			result.discoveries.append(found.id)
	for found: Objective in objectives:
		if found.is_known:
			result.objectives.append(
				{"title": found.title, "kind": found.kind, "state": found.state}
			)
	_stop_listening()
	Events.mission_ended.emit(won)
	finished.emit(result)


func _exit_tree() -> void:
	_stop_listening()


## The CommanderDifficulty id the enemy commander plays at: the mission's own level
## shifted by the player's choice (Difficulty.effective).
func commander_level() -> StringName:
	var chosen: StringName = modifiers.difficulty if modifiers != null else &""
	return Difficulty.effective(StringName(def.enemy_difficulty), chosen)


func _start_commander() -> void:
	if def.commander_profile == null:
		return
	commander = Commander.new()
	commander.name = &"Commander"
	add_child(commander)
	commander.verbose = log_enemy_ai
	commander.setup(
		context, world, def.hostile_faction, def.commander_profile, commander_level(), map_area
	)
	# Units on patrol are the guards', not the commander's army.
	commander.guards = guards


func _listen() -> void:
	context.sim_clock.ticked.connect(_on_ticked)
	Events.entity_died.connect(_on_entity_died)
	Events.intel_changed.connect(_on_intel_changed)
	Events.alert_level_changed.connect(_on_alert_level_changed)


func _make_script() -> void:
	if def.mission_script == null:
		return
	var source: GDScript = def.mission_script as GDScript
	var instance: Variant = source.new() if source != null else null
	script_instance = instance if instance is MissionScript else null
	if script_instance == null:
		push_error("Mission %s: its script is not a MissionScript" % def.id)
	else:
		script_instance.setup(self)


## The definition of objective `objective_id`: the mission's, or one its script adds.
func _objective_def(objective_id: String) -> ObjectiveDef:
	var candidates: Array[ObjectiveDef] = def.objectives.duplicate()
	if script_instance != null:
		candidates.append_array(script_instance.objective_defs())
	for candidate: ObjectiveDef in candidates:
		if candidate != null and String(candidate.id) == objective_id:
			return candidate
	return null


func _on_ticked(_tick: int) -> void:
	if result != null:
		return
	for trigger: Trigger in triggers.duplicate():
		trigger.update(self)
	for found: Objective in objectives.duplicate():
		found.evaluate()
		_warn_if_time_low(found)
	if script_instance != null:
		script_instance.on_tick(now())
	_resolve()


## The climax objective's deadline is when the planet's climax arrives.
func _schedule_climax() -> void:
	if def.climax_objective == &"" or world.planet == null:
		return
	var found: Objective = objective(def.climax_objective)
	if found != null and found.countdown_tick >= 0:
		world.planet.schedule_climax(found.countdown_tick)


func _resolve() -> void:
	var outcome: int = evaluate_outcome()
	if outcome != 0:
		finish(outcome > 0)


func _warn_if_time_low(found: Objective) -> void:
	if not found.is_active() or not found.is_known or found.countdown_tick < 0:
		return
	if _warned.has(found.id) or found.seconds_left(now()) > TIME_LOW_SECONDS:
		return
	_warned[found.id] = true
	Events.advisor_alert.emit(&"objective_time_low")


## A win needs a goal reached, not only things kept alive.
func _has_goal() -> bool:
	for found: Objective in objectives:
		if found.kind == Objective.KIND_PRIMARY and not found.passive:
			return true
	return false


func _on_entity_died(entity: Node3D) -> void:
	if result != null or not is_instance_valid(entity):
		return
	var faction: int = Combat.faction_of(entity)
	if faction == player_faction:
		if entity is Building:
			buildings_lost += 1
		else:
			units_lost += 1
	elif enemy_factions().has(faction):
		enemies_destroyed += 1
	for found: Objective in objectives.duplicate():
		if found.is_active():
			found.on_entity_died(entity)


func _on_intel_changed(faction: int, intel: int) -> void:
	if faction != player_faction:
		return
	if intel > _last_intel:
		intel_earned += intel - _last_intel
	_last_intel = intel


func _on_alert_level_changed(faction: int, level: StringName, previous: StringName) -> void:
	if script_instance != null and result == null:
		script_instance.on_alert_changed(faction, level, previous)


func _stop_listening() -> void:
	for trigger: Trigger in triggers:
		trigger.stop()
	if script_instance != null:
		script_instance.stop()
	if context != null and context.sim_clock.ticked.is_connected(_on_ticked):
		context.sim_clock.ticked.disconnect(_on_ticked)
	for connection: Array in [
		[Events.entity_died, _on_entity_died],
		[Events.intel_changed, _on_intel_changed],
		[Events.alert_level_changed, _on_alert_level_changed],
	]:
		var source: Signal = connection[0]
		var target: Callable = connection[1]
		if source.is_connected(target):
			source.disconnect(target)
