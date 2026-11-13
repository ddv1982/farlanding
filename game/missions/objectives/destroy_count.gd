class_name DestroyCountObjective
extends Objective
## Achieved once `amount` units or buildings of the objective's side and types have
## been destroyed during the mission (e.g. "silence a Custodian Warden").

var destroyed: int = 0


func _start() -> void:
	set_progress("0 / %d" % def.amount)


func on_entity_died(entity: Node3D) -> void:
	if state != STATE_ACTIVE or not is_instance_valid(entity) or not matches_dead(entity):
		return
	destroyed += 1
	set_progress("%d / %d" % [mini(destroyed, def.amount), def.amount])
	if destroyed >= def.amount:
		complete()


## Like `matches`, for an entity that just died.
func matches_dead(entity: Node3D) -> bool:
	return matches(entity)


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	data["destroyed"] = destroyed
	return data


func from_dict(data: Dictionary) -> void:
	super(data)
	destroyed = data.get("destroyed", 0)
