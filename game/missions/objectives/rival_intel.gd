class_name RivalIntelObjective
extends Objective
## The Survey race (ADR 0011): fails as soon as the rival faction (`side`, usually the
## enemy) has banked `amount` Intel. Passive: it holds until the player wins. Its bar
## shows the rival's progress; the Advisor speaks up (&"enemy_intel") whenever the
## rival banks more.

var _last_banked: int = 0


func _start() -> void:
	progress_side = ObjectiveDef.SIDE_ENEMY
	_last_banked = _banked()


func _evaluate() -> void:
	var banked: int = _banked()
	if banked > _last_banked:
		Events.advisor_alert.emit(&"enemy_intel")
	_last_banked = banked
	set_ratio(float(banked) / maxf(def.amount, 1.0))
	set_progress("Combine: %d / %d Intel" % [mini(banked, def.amount), def.amount])
	if banked >= def.amount:
		fail()


func _banked() -> int:
	var total: int = 0
	for faction: int in factions_of(def.side):
		total = maxi(total, mission.world.economy.stockpile(faction).intel)
	return total
