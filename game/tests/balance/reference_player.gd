class_name ReferencePlayer
extends Node
## A scripted stand-in for the player in balance runs (ADR 0018). It is the enemy
## `Commander` playing the Concord through the same command queue a player uses, at a
## "competent casual" setting (`reference_difficulty()`), with a Concord profile built
## for the mission type (`build_profile()`): it scans sites on every mission, carries
## the artefact home on Recovery, vents its Taps on Emberfall, reactivates engines on
## Hollow Meridian, and on the finale links a Surveyor at the Core once it runs enough
## engines (the one objective the commander has no part for: `_drive_core()`).
## Infiltration is not driven: a squad that must stay unseen is not a commander's game.

const UNITS: String = "res://data/units/concord_%s.tres"
const BUILDINGS: String = "res://data/buildings/concord_%s.tres"
## Sim ticks between two looks of the finale's linker driver.
const CORE_TICKS: int = 20
## Sim ticks between two trace lines (`--log`).
const TRACE_TICKS: int = 300
## Units that can link kept on the finale (the linker and a spare).
const SCANNERS_KEPT: int = 2
## The smallest escort sent with the linker.
const ESCORT_MIN: int = 6
## The linker sets out once an escort member is this close to the Core, in metres ...
const ESCORT_REACH: float = 30.0
## ... or goes on regardless once it is this close, or has waited this long, in ticks.
const LINK_REACH: float = 30.0
const ESCORT_WAIT_TICKS: int = 600

var commander: Commander = null
var mission: Mission = null
## The finale's linker (entity id, -1 = none) and the group escorting it.
var linker_id: int = -1
var escort: AttackGroup = null
## The army mix, kept aside while production waits for a Surveyor.
var _army_mix: Array[UnitDef] = []
## Sim tick the linker began waiting for its escort (-1 = not waiting).
var _waiting_since: int = -1


## True if the reference player can play `def` (everything but Infiltration).
static func can_play(def: MissionDef) -> bool:
	return def.mission_type != MissionDef.TYPE_INFILTRATION and def.player_hq != null


## Starts playing the player's side of `runner`; `run_seed` varies its dice.
func setup(runner: Mission, run_seed: int) -> void:
	mission = runner
	var profile: CommanderProfile = build_profile(runner.def, run_seed)
	commander = Commander.new()
	commander.name = &"ReferencePlayer"
	add_child(commander)
	commander.setup(
		runner.context, runner.world, runner.player_faction, profile, &"normal", runner.map_area
	)
	runner.context.sim_clock.ticked.connect(_on_ticked)


## The player's side as a commander: a casual human's pace, waves of eight and more
## from minute seven, one mistake in ten.
static func reference_difficulty() -> CommanderDifficulty:
	var level: CommanderDifficulty = CommanderDifficulty.new()
	level.id = &"reference"
	level.display_name = "Reference player"
	level.decision_interval_ticks = 30
	level.first_attack_seconds = 420.0
	level.attack_interval_seconds = 100.0
	level.first_wave_size = 8
	level.wave_growth = 3
	level.max_wave_size = 24
	level.mistake_chance = 0.1
	level.early_wave_share = 0.6
	level.first_scout_seconds = 60.0
	return level


## The Concord roster as a commander profile, with the parts `def`'s type needs.
static func build_profile(def: MissionDef, run_seed: int) -> CommanderProfile:
	var profile: CommanderProfile = CommanderProfile.new()
	profile.display_name = "Reference player"
	profile.random_seed = 1000 + run_seed * 7919
	profile.hq = _building("lander")
	profile.factory = _building("foundry")
	profile.defence = _building("sentry")
	profile.power_plant = _building("reactor")
	profile.power_margin = 6
	profile.harvester = _unit("hauler")
	profile.builder = _unit("fabricator")
	profile.scout = _unit("ranger")
	var ranger: UnitDef = _unit("ranger")
	var lancer: UnitDef = _unit("lancer")
	profile.army = [ranger, lancer, _unit("kite"), _unit("bulwark"), _unit("arc")]
	profile.army_weights = PackedFloat32Array([0.32, 0.26, 0.16, 0.16, 0.10])
	profile.anti_heavy = lancer
	profile.anti_air = ranger
	profile.opening = [
		_unit("hauler"),
		_building("reactor"),
		_building("muster_bay"),
		ranger,
		ranger,
		_unit("hauler"),
		_building("foundry"),
		lancer,
	]
	profile.harvesters_per_deposit = 1.5
	profile.max_harvesters = 6
	profile.max_builders = 2
	profile.max_factories = 2
	profile.factory_bank = 400
	profile.home_guard_size = 4
	profile.max_defences = 3
	profile.extractor = _building("flux_tap")
	profile.extractors_wanted = 2
	profile.vent_at_pressure = 0.7
	profile.surveyor = _unit("surveyor")
	profile.surveyors_wanted = 1
	profile.survey_after_seconds = 20.0
	profile.normal = reference_difficulty()
	match def.mission_type:
		MissionDef.TYPE_SURVEY:
			profile.surveyors_wanted = 3
			profile.attack_weight = 0.5
		MissionDef.TYPE_RECOVERY:
			profile.retrieves_cargo = true
			# A squad that can fight its way in, once there is one.
			profile.retrieve_squad_size = 8
			profile.retrieve_after_seconds = 180.0
		MissionDef.TYPE_HOLDOUT:
			# What the briefing asks for: turrets by the Lander first, then infantry.
			profile.attack_weight = 0.0
			profile.max_defences = 5
			profile.home_guard_size = 30
			profile.extractors_wanted = 1
			profile.opening = [
				_building("sentry"),
				_unit("hauler"),
				_building("sentry"),
				_building("muster_bay"),
				ranger,
				ranger,
				_building("reactor"),
				_building("sentry"),
				ranger,
			]
		MissionDef.TYPE_POWER, MissionDef.TYPE_FINALE:
			profile.machines_wanted = 6
			profile.machine_escort = 4
			# No Reactors and a Lander at 7 power: the Muster Bay (4 power, Flux-free
			# Rangers) is the factory it keeps standing; the Foundry needs an engine.
			profile.factory = _building("muster_bay")
	return profile


func _on_ticked(tick: int) -> void:
	if mission.result != null:
		return
	if commander.verbose and tick % TRACE_TICKS == 0:
		_trace()
	if tick % CORE_TICKS == 0 and mission.def.mission_type == MissionDef.TYPE_FINALE:
		_drive_core(tick)


## One line of what the reference player is doing (with `--log`).
func _trace() -> void:
	var view: CommanderView = commander.last_view()
	if view == null:
		return
	var core: String = ""
	var script: CoreScript = mission.script_instance as CoreScript
	if script != null and script.core() != null:
		var linker: Unit = mission.world.entity(linker_id) as Unit
		var away: float = -1.0
		if linker != null and not linker.is_dead:
			away = AiGroup.flat_distance(linker.sim_position(), script.core().position)
		core = (
			" core %d%%/%d%% linker %dm"
			% [
				roundi(script.charge_of(mission.player_faction) * 100.0),
				roundi(script.charge_of(mission.def.hostile_faction) * 100.0),
				roundi(away),
			]
		)
	var index: int = commander.memory.opening_index
	var step: String = "done"
	if index < commander.profile.opening.size():
		step = String(commander.profile.opening[index].id)
	print(
		(
			(
				"[reference @%ds] opening %d (%s) alloy %d flux %d power %d builders %d/%d"
				+ " guards %d army %d units %s buildings %s%s"
			)
			% [
				roundi(mission.elapsed_seconds()),
				index,
				step,
				view.alloy,
				view.flux,
				view.power_free,
				view.idle_builders.size(),
				view.builders.size(),
				view.guards.size(),
				view.army.size(),
				str(view.unit_counts),
				str(view.building_counts),
				core,
			]
		)
	)


## Finale: it keeps a spare scanner, and once it runs enough engines a Surveyor walks
## to the dais behind an escort of the free army and stays there; a fallen linker is
## replaced, a spent escort sent again. The dais is guarded: a linker alone, or ahead of
## its escort, dies there (found by the balance harness, ADR 0018).
func _drive_core(tick: int) -> void:
	var script: CoreScript = mission.script_instance as CoreScript
	if script == null or script.core() == null:
		return
	if escort != null:
		escort.tick(tick)
		if escort.finished:
			escort = null
	_keep_scanners()
	var faction: int = mission.player_faction
	if script.engines_of(faction) < script.rules.engines_needed:
		return
	var core_at: Vector3 = script.core().position
	var linker: Unit = mission.world.entity(linker_id) as Unit
	if linker == null or linker.is_dead:
		linker = _pick_linker()
		if linker == null:
			return
		linker_id = linker.entity_id
		commander.hands_off[linker_id] = true
		if commander.survey != null:
			commander.survey.members.erase(linker)
	if escort == null:
		_send_escort(core_at)
	var linked: bool = AiGroup.flat_distance(linker.sim_position(), core_at) <= LINK_REACH
	if linked or _escort_near(core_at):
		_waiting_since = -1
	elif _waiting_since < 0:
		_waiting_since = tick
	# It waits for its escort, but not for good: with the army out hunting, no escort
	# formed and the linker stood 42 m from the Core to the cap (ADR 0018).
	if _waiting_since >= 0 and tick - _waiting_since < ESCORT_WAIT_TICKS:
		return
	var stand: Vector3 = mission.world.paths.closest_point(
		core_at + (mission.def.player_start - core_at).normalized() * CoreScript.LINK_STAND
	)
	var far: bool = AiGroup.flat_distance(linker.sim_position(), core_at) > script.rules.link_radius
	if far and not linker.locomotion.is_travelling():
		commander.port.push(
			MoveCommand.new(MoveCommand.KIND_MOVE, faction, [linker] as Array[Node3D], stand)
		)


## True while a member of the escort is within ESCORT_REACH of the Core.
func _escort_near(core_at: Vector3) -> bool:
	if escort == null:
		return false
	for unit: Unit in escort.members:
		if is_instance_valid(unit) and not unit.is_dead:
			if AiGroup.flat_distance(unit.sim_position(), core_at) <= ESCORT_REACH:
				return true
	return false


## Keeps SCANNERS_KEPT units that can link: Surveyors are ordered at a Foundry, and with
## no Foundry standing the Foundry becomes the factory the commander keeps (it rebuilds
## a missing factory). While it saves for one, the army waits. Found by the balance
## harness (ADR 0018): with six engines, an army of fifty and the Combine wiped out,
## finales timed out because the last Surveyor had died and nothing made another.
func _keep_scanners() -> void:
	var surveyor: UnitDef = commander.profile.surveyor
	if surveyor == null:
		return
	var short: bool = _scanners() < SCANNERS_KEPT
	var waiting: bool = false
	if short:
		waiting = not _order_surveyor(surveyor)
	if waiting and not commander.profile.army.is_empty():
		_army_mix = commander.profile.army.duplicate()
		commander.profile.army = []
	elif not waiting and commander.profile.army.is_empty() and not _army_mix.is_empty():
		commander.profile.army = _army_mix.duplicate()


## Orders a Surveyor where one can be made. False while it has to save for one.
func _order_surveyor(surveyor: UnitDef) -> bool:
	var makers: Array[Building] = []
	for building: Building in mission.world.buildings_of(mission.player_faction):
		if building.is_dead or building.producer == null or not building.is_operational():
			continue
		if building.producer.options.has(surveyor):
			makers.append(building)
	# The Foundry is the factory it keeps only while none stands and there is the power
	# and the money to build one now; otherwise the Muster Bay stays the one it rebuilds
	# (with the Foundry kept on the Lander's power alone a lost Muster Bay was never
	# rebuilt, and kept unaffordable it held the last Fabricator home for good).
	var foundry: BuildingDef = _building("foundry")
	var pile: Stockpile = mission.world.economy.stockpile(mission.player_faction)
	if makers.is_empty():
		var free: int = pile.power_produced - pile.power_used
		var muster_bay: BuildingDef = _building("muster_bay")
		var spare: int = free if _standing(muster_bay) else free - muster_bay.power_use
		var can_build: bool = (
			spare >= foundry.power_use
			and pile.alloy >= foundry.cost_alloy
			and pile.flux >= foundry.cost_flux
		)
		commander.profile.factory = foundry if can_build else muster_bay
		return true
	commander.profile.factory = _building("muster_bay")
	for maker: Building in makers:
		if maker.producer.queue.has(surveyor):
			return true
	if pile.alloy < surveyor.cost_alloy or pile.flux < surveyor.cost_flux:
		return false
	commander.port.push(ProduceCommand.new(mission.player_faction, makers[0], surveyor))
	return true


## True if a building of `def` of the player's stands (finished or not).
func _standing(def: BuildingDef) -> bool:
	for building: Building in mission.world.buildings_of(mission.player_faction):
		if building.def == def and not building.is_dead:
			return true
	return false


## Units of the player's that can link (scanners on foot that are not builders).
func _scanners() -> int:
	var count: int = 0
	for unit: Unit in mission.world.units_of(mission.player_faction):
		if not unit.is_dead and unit.scanner != null and not unit.flies and unit.builder == null:
			count += 1
	return count


func _pick_linker() -> Unit:
	for unit: Unit in mission.world.units_of(mission.player_faction):
		if unit.is_dead or unit.scanner == null or unit.flies or unit.builder != null:
			continue
		return unit
	return null


func _send_escort(core_at: Vector3) -> void:
	if escort != null:
		return
	var view: CommanderView = commander.last_view()
	if view == null:
		return
	var squad: Array[Unit] = []
	for unit: Unit in view.guards:
		if not unit.is_dead:
			squad.append(unit)
	if squad.size() < ESCORT_MIN:
		return
	for unit: Unit in squad:
		commander.hands_off[unit.entity_id] = true
	escort = AttackGroup.new(
		commander.port,
		commander.profile,
		squad,
		AttackGroup.MODE_LAST_STAND,
		core_at,
		commander.staging,
		commander.staging
	)
	escort.next_target = func(_from: Vector3) -> Vector3: return core_at
	escort.start()


static func _unit(id: String) -> UnitDef:
	return load(UNITS % id) as UnitDef


static func _building(id: String) -> BuildingDef:
	return load(BUILDINGS % id) as BuildingDef
