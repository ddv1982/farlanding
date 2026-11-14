class_name Difficulty
extends RefCounted
## The difficulty the player chooses (Easy, Normal, Hard): for a new campaign, for
## a single mission, and between landings aboard the Meridian. It picks which of the
## enemy commander's CommanderDifficulty resources plays (PLAN 3.5): decision speed,
## attack timing and mistakes, never resource cheats.
##
## Each mission names the level it was designed for (`MissionDef.enemy_difficulty`);
## the player's choice shifts that by one step: Normal plays every mission as
## designed, Easy one step gentler, Hard one step harder (clamped to the three
## levels). So the first landing stays a gentle introduction on Normal.

const EASY: StringName = &"easy"
const NORMAL: StringName = &"normal"
const HARD: StringName = &"hard"
const LEVELS: Array[StringName] = [EASY, NORMAL, HARD]
const LABELS: Dictionary[StringName, String] = {
	EASY: "Easy",
	NORMAL: "Normal",
	HARD: "Hard",
}
const DESCRIPTIONS: Dictionary[StringName, String] = {
	EASY: "The Combine thinks slowly, attacks late and makes more mistakes.",
	NORMAL: "Every landing plays as designed.",
	HARD: "The Combine decides quickly, attacks early and rarely slips.",
}


## `value` when it names a level, otherwise NORMAL (older saves, bad files).
static func sanitize(value: Variant) -> StringName:
	var id: StringName = StringName(str(value)) if value != null else &""
	return id if LEVELS.has(id) else NORMAL


## "Easy", "Normal" or "Hard".
static func label(id: StringName) -> String:
	return LABELS.get(sanitize(id), "Normal")


## The commander level a mission designed for `authored` plays at when the player
## chose `chosen` (empty = as designed).
static func effective(authored: StringName, chosen: StringName) -> StringName:
	var base: int = LEVELS.find(sanitize(authored))
	if chosen == &"":
		return LEVELS[base]
	var step: int = LEVELS.find(sanitize(chosen)) - LEVELS.find(NORMAL)
	return LEVELS[clampi(base + step, 0, LEVELS.size() - 1)]
