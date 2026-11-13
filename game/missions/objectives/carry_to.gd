class_name CarryToObjective
extends Objective
## Achieved when a carriable prop (of `defs`, or any) is brought into the objective's
## area by a unit of its side, carried there or put down there by one (PLAN 2.6
## Recovery: get the artefact back to the Lander). The progress line says where the
## prop is: waiting, carried by the side, carried by somebody else, or dropped. Fails
## when no such prop is left (destroyed).


func _evaluate() -> void:
	var cargo: Array[Prop] = carried_matches(mission.world, def.defs)
	if cargo.is_empty():
		fail()
		return
	var sides: Array[int] = factions_of(def.side)
	var best: String = "Not yet found"
	for prop: Prop in cargo:
		var at: Vector3 = prop.sim_position()
		var inside: bool = (
			Vector2(at.x - area_center.x, at.z - area_center.z).length() <= area_radius
		)
		var holder: int = prop.carrier_faction()
		if inside and (holder < 0 or sides.has(holder)) and prop.was_moved():
			complete()
			return
		if sides.has(holder):
			best = "Carried: %d m to go" % roundi(_distance_to_area(at))
		elif holder >= 0:
			best = "Taken by the enemy"
		elif prop.was_moved():
			best = "Dropped: %d m from the goal" % roundi(_distance_to_area(at))
	set_progress(best)


func _distance_to_area(at: Vector3) -> float:
	return maxf(Vector2(at.x - area_center.x, at.z - area_center.z).length() - area_radius, 0.0)


## Carriable props in `world` of `defs` (any carriable one when empty).
static func carried_matches(world: SimWorld, defs: Array[EntityDef]) -> Array[Prop]:
	var found: Array[Prop] = []
	for prop: Prop in world.props:
		if not prop.is_carriable():
			continue
		if defs.is_empty() or defs.has(prop.def):
			found.append(prop)
	return found
