class_name SurviveObjective
extends Objective
## Achieved when `seconds` have passed since it began (hold out until extraction).


func _start() -> void:
	countdown_tick = started_tick + CommanderDifficulty.ticks(def.seconds)
	countdown_fails = false


func _evaluate() -> void:
	if mission.now() >= countdown_tick:
		complete()
