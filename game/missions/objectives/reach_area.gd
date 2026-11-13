class_name ReachAreaObjective
extends Objective
## Achieved when `amount` units of the objective's side (and types) stand inside its
## area, or with `require_all` every one of them still alive (at least one). Fails
## when too few are left alive to do it.


func _evaluate() -> void:
	var living: Array[Node3D] = living_matches(true, false)
	var needed: int = maxi(living.size(), 1) if def.require_all else maxi(def.amount, 1)
	if living.size() < needed or living.is_empty():
		fail()
		return
	var inside: int = 0
	for entity: Node3D in living:
		var at: Vector3 = AttackCommand.position_of(entity)
		if Vector2(at.x - area_center.x, at.z - area_center.z).length() <= area_radius:
			inside += 1
	set_progress("%d / %d in the area" % [inside, needed])
	if inside >= needed:
		complete()
