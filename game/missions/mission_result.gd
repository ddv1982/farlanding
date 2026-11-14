class_name MissionResult
extends RefCounted
## What the debrief shows: the outcome, every known objective's result and the
## mission's numbers.

var mission_id: StringName = &""
var title: String = ""
var won: bool = false
## The difficulty the player chose (Difficulty.LEVELS), or &"" (as designed).
var difficulty: StringName = &""
## One entry per objective the player knew of: { title, kind, state }.
var objectives: Array[Dictionary] = []
var seconds: float = 0.0
var intel_earned: int = 0
var units_lost: int = 0
var buildings_lost: int = 0
var enemies_destroyed: int = 0
## Intel in the player's stockpile when the mission ended (what a campaign banks).
var intel_held: int = 0
## Ids of the discoveries the player made, in the order found.
var discoveries: Array[StringName] = []


## "12:05" for `seconds`.
static func clock_text(p_seconds: float) -> String:
	var whole: int = floori(maxf(p_seconds, 0.0))
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]
