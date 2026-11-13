class_name StayUndetectedObjective
extends Objective
## Passive: holds while no enemy faction with an alert meter has been alerted. Fails
## the moment one is (being seen changes the mission; it does not end it).


func _start() -> void:
	passive = true


func _evaluate() -> void:
	var stealth: StealthSystem = mission.world.stealth
	if stealth == null:
		return
	for faction: int in factions_of(def.side):
		if stealth.alert_level(faction) == StealthSystem.LEVEL_ALERTED:
			fail()
			return
