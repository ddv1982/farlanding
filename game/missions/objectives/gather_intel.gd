class_name GatherIntelObjective
extends Objective
## Achieved when the player's banked Intel reaches `amount` (Intel spent at the Survey
## Lab no longer counts: banking is the goal).


func _evaluate() -> void:
	var banked: int = mission.world.economy.stockpile(mission.player_faction).intel
	set_ratio(float(banked) / maxf(def.amount, 1.0))
	set_progress("%d / %d Intel banked" % [mini(banked, def.amount), def.amount])
	if banked >= def.amount:
		complete()
