class_name GoalScorer
extends RefCounted
## Scores the commander's four goals for one decision (PLAN 3.5). Pure functions of a
## CommanderView: higher means more urgent; about 1 is "do it now", 0 is "nothing to
## do". Each score is multiplied by the profile's weight for that goal.

const ECONOMY: StringName = &"economy"
const DEFENCE: StringName = &"defence"
const SCOUT: StringName = &"scout"
const ATTACK: StringName = &"attack"
const GOALS: Array[StringName] = [ECONOMY, DEFENCE, SCOUT, ATTACK]


## Every goal's score, keyed by goal name.
static func score_all(
	view: CommanderView,
	profile: CommanderProfile,
	difficulty: CommanderDifficulty,
	memory: CommanderMemory,
) -> Dictionary[StringName, float]:
	return {
		ECONOMY: economy(view, profile),
		DEFENCE: defence(view, profile, memory),
		SCOUT: scout(view, profile, difficulty, memory),
		ATTACK: attack(view, profile, difficulty, memory),
	}


## Goal names, best first (ties keep GOALS order).
static func ranked(scores: Dictionary[StringName, float]) -> Array[StringName]:
	var names: Array[StringName] = GOALS.duplicate()
	names.sort_custom(
		func(a: StringName, b: StringName) -> bool: return scores.get(a, 0.0) > scores.get(b, 0.0)
	)
	return names


## The best goal, or &"" when nothing scores above zero.
static func best(scores: Dictionary[StringName, float]) -> StringName:
	var top: StringName = ranked(scores)[0]
	return top if scores.get(top, 0.0) > 0.0 else &""


## Harvesters wanted: per known deposit near home, capped; at least two while an HQ
## stands (the opening ones keep working nearby deposits).
static func wanted_harvesters(view: CommanderView, profile: CommanderProfile) -> int:
	if view.count_of(profile.hq) == 0:
		return 0
	var wanted: int = ceili(view.deposits_near_home * profile.harvesters_per_deposit)
	return clampi(wanted, 2, profile.max_harvesters)


## Defence towers wanted: one, plus one per `attacks_per_defence` attacks suffered.
static func wanted_defences(
	profile: CommanderProfile, memory: CommanderMemory, alloy: int = 0
) -> int:
	var wanted: int = (
		1 + floori(float(memory.attacks_on_base) / maxi(profile.attacks_per_defence, 1))
	)
	# Alloy piling up in the bank goes into towers as well.
	wanted += floori(alloy / (profile.factory_bank * 2.0))
	return mini(profile.max_defences, wanted)


## Economy: missing harvesters, a missing builder, a missing or wanted factory. Being
## poor (little Alloy and harvesters missing) adds urgency.
static func economy(view: CommanderView, profile: CommanderProfile) -> float:
	var score: float = 0.0
	var wanted: int = wanted_harvesters(view, profile)
	var deficit: float = 0.0
	if wanted > 0:
		deficit = clampf(float(wanted - view.count_of(profile.harvester)) / wanted, 0.0, 1.0)
	score = deficit
	var has_hq: bool = view.count_of(profile.hq) > 0
	if has_hq and view.count_of(profile.builder) == 0:
		score = maxf(score, 0.9)
	if not view.builders.is_empty() or view.count_of(profile.builder) > 0:
		var factories: int = view.count_of(profile.factory)
		if factories == 0:
			score = maxf(score, 1.0)
		elif factories < profile.max_factories and view.alloy >= profile.factory_bank:
			score = maxf(score, 0.5)
	if deficit > 0.0 and view.alloy < profile.poor_alloy:
		score += 0.3
	return score * profile.economy_weight


## Defence: enemies near home (more urgent the more they outweigh the home guard), and
## fewer towers than wanted.
static func defence(
	view: CommanderView, profile: CommanderProfile, memory: CommanderMemory
) -> float:
	var score: float = 0.0
	if view.threat_strength > 0.0:
		var ratio: float = view.threat_strength / maxf(view.guard_strength, 50.0)
		score = clampf(0.6 + ratio * 0.4, 0.6, 1.6)
	var missing: int = wanted_defences(profile, memory, view.alloy) - view.count_of(profile.defence)
	if missing > 0 and not view.builders.is_empty():
		score = maxf(score, 0.3 + 0.1 * missing)
	return score * profile.defence_weight


## Scouting: worth more while no target is known and the map is little explored.
static func scout(
	view: CommanderView,
	profile: CommanderProfile,
	difficulty: CommanderDifficulty,
	memory: CommanderMemory,
) -> float:
	if view.scout_active or view.tick < CommanderDifficulty.ticks(difficulty.first_scout_seconds):
		return 0.0
	if (
		view.tick - memory.last_scout_tick
		< CommanderDifficulty.ticks(profile.scout_cooldown_seconds)
	):
		return 0.0
	var score: float = 0.85 if not view.has_target else 0.3
	score *= 1.0 - view.explored_share * 0.5
	return score * profile.scout_weight


## Attack: how close the free army (beyond the home guard) is to the next wave's size,
## once the first-attack time and the interval since the last wave have passed and a
## target has been seen.
static func attack(
	view: CommanderView,
	profile: CommanderProfile,
	difficulty: CommanderDifficulty,
	memory: CommanderMemory,
) -> float:
	if view.attack_active or not view.has_target:
		return 0.0
	if view.tick < CommanderDifficulty.ticks(difficulty.first_attack_seconds):
		return 0.0
	if (
		view.tick - memory.last_attack_tick
		< CommanderDifficulty.ticks(difficulty.attack_interval_seconds)
	):
		return 0.0
	var size: int = difficulty.wave_size(memory.waves_launched)
	var free: int = view.guards.size() - profile.home_guard_size
	return clampf(float(free) / maxf(size, 1.0), 0.0, 1.5) * profile.attack_weight
