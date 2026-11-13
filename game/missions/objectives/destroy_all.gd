class_name DestroyAllObjective
extends Objective
## Achieved when every unit and building of the objective's side (and types, if
## listed) is destroyed. Custodians never count for the enemy side. The progress line
## counts the structures the player knows of, so it gives nothing unseen away.


func _evaluate() -> void:
	var remaining: Array[Node3D] = living_matches()
	if remaining.is_empty():
		complete()
		return
	var known: int = 0
	for entity: Node3D in remaining:
		var building: Building = entity as Building
		if building != null and building.seen_by_player:
			known += 1
	if def.defs.is_empty():
		set_progress("%d known structures standing" % known)
	else:
		set_progress("%d left" % remaining.size())
