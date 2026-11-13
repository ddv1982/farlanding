class_name KeepAliveObjective
extends Objective
## Passive: holds while the guarded things live. It watches what matched when it
## began (side and types, e.g. the player's Lander) and fails when the last of them
## is gone, or, with `require_all`, when any of them is lost. Done when the mission
## is won.

var guarded: Array[Node3D] = []


func _start() -> void:
	passive = true
	guarded = living_matches()


func _evaluate() -> void:
	if guarded.is_empty():
		return
	var alive: int = 0
	for entity: Node3D in guarded:
		if Combat.is_alive(entity):
			alive += 1
	if alive == 0 or (def.require_all and alive < guarded.size()):
		fail()
		return
	if guarded.size() > 1:
		set_progress("%d / %d intact" % [alive, guarded.size()])
