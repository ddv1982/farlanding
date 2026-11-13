class_name SabotageObjective
extends Objective
## Achieved when every enemy building of the listed types is sabotaged (or
## destroyed). Fails when the player has no unit left that can sabotage.

var targets: Array[Building] = []


func _start() -> void:
	for entity: Node3D in living_matches(false, true):
		targets.append(entity as Building)


func _evaluate() -> void:
	var open: int = 0
	for building: Building in targets:
		if Combat.is_alive(building) and not building.is_sabotaged:
			open += 1
	if open == 0:
		complete()
		return
	var saboteurs: int = 0
	for unit: Unit in mission.world.units_of(mission.player_faction):
		if unit.saboteur != null and not unit.is_dead:
			saboteurs += 1
	if saboteurs == 0:
		fail()
		return
	set_progress("%d to go" % open if targets.size() > 1 else "")


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	data["targets"] = Objective.ids_of(targets)
	return data


## Targets destroyed before the save are gone; they no longer count as open.
func from_dict(data: Dictionary) -> void:
	super(data)
	targets.clear()
	var ids: Array = data.get("targets", [])
	for entry: Variant in ids:
		var id: int = entry
		var found: Building = mission.world.entity(id) as Building if mission != null else null
		if found != null:
			targets.append(found)
