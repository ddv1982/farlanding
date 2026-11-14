class_name DestroyAllObjective
extends Objective
## Achieved when every unit and building of the objective's side (and types, if
## listed) is destroyed. Custodians never count for the enemy side. Without listed
## types, a side with no building, no armed unit and no builder left counts as
## destroyed: a last unarmed harvester somewhere does not hold the mission open (the
## progress line already said no structure stood; found by the balance harness, ADR
## 0018). The progress line counts the structures the player knows of, so it gives
## nothing unseen away.


func _evaluate() -> void:
	var remaining: Array[Node3D] = living_matches()
	if remaining.is_empty() or (def.defs.is_empty() and not _can_carry_on(remaining)):
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


## True if any of `remaining` is a building, an armed unit or a builder.
static func _can_carry_on(remaining: Array[Node3D]) -> bool:
	for entity: Node3D in remaining:
		var unit: Unit = entity as Unit
		if unit == null or unit.def == null:
			return true
		if unit.def.weapon != null or not unit.def.builds.is_empty():
			return true
	return false
