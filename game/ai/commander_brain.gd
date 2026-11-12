class_name CommanderBrain
extends RefCounted
## The commander's decision for one tick, as a pure function of a CommanderView: it
## plays the opening from data, then scores the goals and turns them, best first, into
## AiActions. It keeps its own budget while deciding, so it never asks for more than
## the faction can pay for at that moment.

## Free army units are sent home when the base faces this many times their strength.
const RECALL_RATIO: float = 1.2
## Factories keep this many units queued.
const FACTORY_QUEUE: int = 2
## A wave takes at most this many times its planned size.
const WAVE_SLACK: float = 1.5
## Seconds before a building type whose spot could not be found is tried again.
const BACKOFF_SECONDS: float = 20.0

var profile: CommanderProfile
var difficulty: CommanderDifficulty
var memory: CommanderMemory
var rng: RandomNumberGenerator
## The last decision's goal scores (for logs and tests).
var last_scores: Dictionary[StringName, float] = {}

var _alloy: int = 0
var _flux: int = 0


func _init(
	p_profile: CommanderProfile,
	p_difficulty: CommanderDifficulty,
	p_memory: CommanderMemory = null,
	p_rng: RandomNumberGenerator = null,
) -> void:
	profile = p_profile
	difficulty = p_difficulty
	memory = p_memory if p_memory != null else CommanderMemory.new()
	rng = p_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = profile.random_seed


## Everything to do now.
func decide(view: CommanderView) -> Array[AiAction]:
	_alloy = view.alloy
	_flux = view.flux
	var actions: Array[AiAction] = []
	_note_threat(view)
	_housekeeping(view, actions)
	if not view.has_production() and view.sites.is_empty():
		_last_stand(view, actions)
		return actions
	_answer_threat(view, actions)
	if memory.opening_index < profile.opening.size():
		_play_opening(view, actions)
		return actions
	last_scores = GoalScorer.score_all(view, profile, difficulty, memory)
	for goal: StringName in GoalScorer.ranked(last_scores):
		if last_scores[goal] <= 0.0:
			continue
		match goal:
			GoalScorer.ECONOMY:
				_grow_economy(view, actions)
			GoalScorer.DEFENCE:
				_build_defence(view, actions)
			GoalScorer.SCOUT:
				_scout(view, actions)
			GoalScorer.ATTACK:
				_attack(view, actions)
	_build_army(view, actions)
	return actions


## True if `def` can be paid for from what is left this decision.
func can_afford(def: EntityDef) -> bool:
	return def != null and _alloy >= def.cost_alloy and _flux >= def.cost_flux


## Alloy left to spend in the current decision.
func budget_alloy() -> int:
	return _alloy


## A new attack on the base starts when enemies appear near home after a quiet spell.
func _note_threat(view: CommanderView) -> void:
	var threatened: bool = view.threat_strength > 0.0
	if threatened and not memory.threatened:
		memory.attacks_on_base += 1
		memory.recalled = false
	memory.threatened = threatened


## Free work that costs nothing: idle harvesters back to mining, idle builders onto
## unfinished sites.
func _housekeeping(view: CommanderView, actions: Array[AiAction]) -> void:
	if not view.idle_harvesters.is_empty():
		var harvest: AiAction = AiAction.new(AiAction.HARVEST, &"economy")
		harvest.units = view.idle_harvesters.duplicate()
		actions.append(harvest)
	if view.sites.is_empty():
		return
	for builder: Unit in view.idle_builders:
		var assist: AiAction = AiAction.new(AiAction.ASSIST, &"economy")
		assist.building = view.sites[0]
		assist.units = [builder]
		actions.append(assist)
	view.idle_builders.clear()


## No production left: everything armed goes for the enemy (or out to find it), so the
## game ends one way or the other instead of the remnants hiding.
func _last_stand(view: CommanderView, actions: Array[AiAction]) -> void:
	if view.attack_active or view.guards.is_empty():
		return
	var attack: AiAction = AiAction.new(AiAction.ATTACK, &"last_stand")
	attack.units = view.guards.duplicate()
	attack.position = view.attack_target if view.has_target else Vector3.INF
	actions.append(attack)


## Enemies near home: the home guard answers (unless it slips this time), and a wave
## that is out is called back when the base is badly outweighed.
func _answer_threat(view: CommanderView, actions: Array[AiAction]) -> void:
	if view.threat_strength <= 0.0:
		return
	if (
		view.attack_active
		and not memory.recalled
		and view.threat_strength > view.guard_strength * RECALL_RATIO
	):
		memory.recalled = true
		actions.append(AiAction.new(AiAction.RECALL, &"defence"))
	if view.defence_active or view.guards.is_empty():
		return
	if rng.randf() < difficulty.mistake_chance:
		return
	var defend: AiAction = AiAction.new(AiAction.DEFEND, &"defence")
	defend.units = view.guards.duplicate()
	defend.position = view.threat_position
	actions.append(defend)
	view.guards = []
	view.defence_active = true


## Plays the opening in data order; stops at the first step that has to wait.
func _play_opening(view: CommanderView, actions: Array[AiAction]) -> void:
	while memory.opening_index < profile.opening.size():
		var step: EntityDef = profile.opening[memory.opening_index]
		var outcome: StringName = _try_step(view, step, &"opening", actions)
		if outcome == &"wait":
			return
		memory.opening_index += 1


## Tries to produce or build `def` now: &"done", &"wait" (later: money, queue, a
## builder) or &"skip" (nothing can make it, or no power for it).
func _try_step(
	view: CommanderView, def: EntityDef, reason: StringName, actions: Array[AiAction]
) -> StringName:
	if def is UnitDef:
		return _try_unit(view, def as UnitDef, reason, actions)
	if def is BuildingDef:
		return _try_building(view, def as BuildingDef, reason, actions)
	return &"skip"


func _try_unit(
	view: CommanderView, def: UnitDef, reason: StringName, actions: Array[AiAction]
) -> StringName:
	var makers: Array[Building] = view.producers_of(def)
	if makers.is_empty():
		return &"skip"
	if not can_afford(def):
		return &"wait"
	for maker: Building in makers:
		if maker.producer.queue.size() + _queued_now(actions, maker) < maker.producer.limit:
			actions.append(_produce(view, maker, def, reason))
			return &"done"
	return &"wait"


func _try_building(
	view: CommanderView, def: BuildingDef, reason: StringName, actions: Array[AiAction]
) -> StringName:
	if view.builders_of(def).is_empty() or def.power_use > view.power_free:
		return &"skip"
	if not can_afford(def) or memory.is_backed_off(def, view.tick):
		return &"wait"
	var action: AiAction = _build(view, def, view.home, reason)
	if action == null:
		return &"wait"
	actions.append(action)
	return &"done"


func _grow_economy(view: CommanderView, actions: Array[AiAction]) -> void:
	if view.count_of(profile.builder) == 0:
		_try_step(view, profile.builder, &"economy", actions)
	if view.count_of(profile.factory) == 0:
		_try_step(view, profile.factory, &"economy", actions)
		return
	if view.count_of(profile.harvester) < GoalScorer.wanted_harvesters(view, profile):
		_try_step(view, profile.harvester, &"economy", actions)
	if (
		view.count_of(profile.factory) < profile.max_factories
		and _alloy >= profile.factory_bank
		and view.sites.is_empty()
	):
		_try_step(view, profile.factory, &"economy", actions)
	if (
		view.count_of(profile.builder) < profile.max_builders
		and view.count_of(profile.factory) >= 2
	):
		_try_step(view, profile.builder, &"economy", actions)


func _build_defence(view: CommanderView, actions: Array[AiAction]) -> void:
	if view.count_of(profile.defence) >= GoalScorer.wanted_defences(profile, memory, _alloy):
		return
	if not view.sites.is_empty():
		return
	var toward: Vector3 = view.threat_position if view.threat_strength > 0.0 else view.staging
	var near: Vector3 = view.home + (toward - view.home).limit_length(22.0)
	if not can_afford(profile.defence) or memory.is_backed_off(profile.defence, view.tick):
		return
	if view.builders_of(profile.defence).is_empty():
		return
	if profile.defence.power_use > view.power_free:
		return
	var action: AiAction = _build(view, profile.defence, near, &"defence")
	if action != null:
		actions.append(action)


## Sends a scout: a free guard of the scout type, or orders one from a factory.
func _scout(view: CommanderView, actions: Array[AiAction]) -> void:
	for unit: Unit in view.guards:
		if unit.def == profile.scout:
			var scout: AiAction = AiAction.new(AiAction.SCOUT, &"scout")
			scout.units = [unit]
			actions.append(scout)
			view.guards.erase(unit)
			memory.last_scout_tick = view.tick
			return
	for maker: Building in view.producers_of(profile.scout):
		if maker.producer.queue.has(profile.scout):
			return
	_try_step(view, profile.scout, &"scout", actions)


## Launches the next wave when the free army is big enough. Sometimes (a mistake) a
## wave leaves early with only part of the planned size.
func _attack(view: CommanderView, actions: Array[AiAction]) -> void:
	if memory.wave_rolled != memory.waves_launched:
		memory.wave_rolled = memory.waves_launched
		memory.wave_premature = rng.randf() < difficulty.mistake_chance
	var size: int = difficulty.wave_size(memory.waves_launched)
	if memory.wave_premature:
		size = maxi(ceili(size * difficulty.early_wave_share), 1)
	var free: Array[Unit] = _free_army(view)
	if free.size() < size:
		return
	# Units beyond half again the planned size stay home as extra guard.
	var most: int = mini(
		ceili(difficulty.wave_size(memory.waves_launched) * WAVE_SLACK), difficulty.max_wave_size
	)
	free = free.slice(0, mini(free.size(), most))
	var attack: AiAction = AiAction.new(AiAction.ATTACK, &"attack")
	attack.units = free
	attack.position = view.attack_target
	actions.append(attack)
	for unit: Unit in free:
		view.guards.erase(unit)
	view.attack_active = true
	memory.waves_launched += 1
	memory.last_attack_tick = view.tick


## Guards beyond the home guard; the cheapest units stay home.
func _free_army(view: CommanderView) -> Array[Unit]:
	var sorted: Array[Unit] = view.guards.duplicate()
	sorted.sort_custom(func(a: Unit, b: Unit) -> bool: return a.def.cost_alloy > b.def.cost_alloy)
	var keep: int = mini(profile.home_guard_size, sorted.size())
	return sorted.slice(0, sorted.size() - keep)


## Keeps every factory's queue topped up with the army mix from what is left over
## (keeping the economy reserve while the economy still wants something). Sometimes
## (a mistake) the factories are left idle for this decision.
func _build_army(view: CommanderView, actions: Array[AiAction]) -> void:
	if profile.army.is_empty() or rng.randf() < difficulty.mistake_chance * 0.5:
		return
	if view.threat_strength <= 0.0 and view.guards.size() >= army_cap():
		return
	var reserve: int = 0
	if last_scores.get(GoalScorer.ECONOMY, 0.0) >= 0.3:
		reserve = profile.economy_reserve
	for maker: Building in view.producers:
		if maker.def != profile.factory or maker.producer == null:
			continue
		while maker.producer.queue.size() + _queued_now(actions, maker) < FACTORY_QUEUE:
			var choice: UnitDef = pick_army_unit(view.enemy_heavy_share)
			if choice == null or _alloy - choice.cost_alloy < reserve or not can_afford(choice):
				return
			actions.append(_produce(view, maker, choice, &"army"))


## Free army size at which factories pause (see CommanderProfile.army_cap_waves).
func army_cap() -> int:
	var wave: int = difficulty.wave_size(memory.waves_launched)
	return profile.home_guard_size + ceili(wave * profile.army_cap_waves)


## One unit type from the army mix, weighted; the anti-heavy unit counts more the more
## heavy armour the enemy fields.
func pick_army_unit(heavy_share: float) -> UnitDef:
	var total: float = 0.0
	var weights: Array[float] = []
	for def: UnitDef in profile.army:
		var weight: float = profile.weight_of(def)
		if def == profile.anti_heavy:
			weight *= 1.0 + heavy_share * 2.0
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return profile.army[i]
	return profile.army[profile.army.size() - 1]


func _produce(view: CommanderView, maker: Building, def: UnitDef, reason: StringName) -> AiAction:
	var action: AiAction = AiAction.new(AiAction.PRODUCE, reason)
	action.def = def
	action.building = maker
	_charge(action, def)
	view.unit_counts[def.id] = view.count_of(def) + 1
	return action


## A build action for the first suitable builder, or null if there is none.
func _build(view: CommanderView, def: BuildingDef, near: Vector3, reason: StringName) -> AiAction:
	var candidates: Array[Unit] = view.builders_of(def)
	if candidates.is_empty() or not view.idle_builders.has(candidates[0]):
		return null
	var action: AiAction = AiAction.new(AiAction.BUILD, reason)
	action.def = def
	action.units = [candidates[0]]
	action.position = near
	_charge(action, def)
	view.idle_builders.erase(candidates[0])
	view.builders.erase(candidates[0])
	view.power_free -= def.power_use
	view.building_counts[def.id] = view.count_of(def) + 1
	return action


func _charge(action: AiAction, def: EntityDef) -> void:
	action.cost_alloy = def.cost_alloy
	action.cost_flux = def.cost_flux
	_alloy -= def.cost_alloy
	_flux -= def.cost_flux


static func _queued_now(actions: Array[AiAction], maker: Building) -> int:
	var count: int = 0
	for action: AiAction in actions:
		if action.kind == AiAction.PRODUCE and action.building == maker:
			count += 1
	return count
