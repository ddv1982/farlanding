class_name KeepAliveObjective
extends Objective
## Passive: holds while the guarded things live. It watches what matched when it
## began (side and types, e.g. the player's Lander) and fails when the last of them
## is gone, or, with `require_all`, when any of them is lost. Done when the mission
## is won.

var guarded: Array[Node3D] = []

## Guarded things already gone when a saved game was made (they are not restored).
var _lost_before_save: int = 0


func _start() -> void:
	passive = true
	guarded = living_matches()


func _evaluate() -> void:
	var total: int = guarded.size() + _lost_before_save
	if total == 0:
		return
	var alive: int = 0
	for entity: Node3D in guarded:
		if Combat.is_alive(entity):
			alive += 1
	if alive == 0 or (def.require_all and alive < total):
		fail()
		return
	if total > 1:
		set_progress("%d / %d intact" % [alive, total])


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	data["guarded"] = Objective.ids_of(guarded)
	data["guarded_count"] = guarded.size() + _lost_before_save
	return data


func from_dict(data: Dictionary) -> void:
	super(data)
	passive = true
	guarded.clear()
	var ids: Array = data.get("guarded", [])
	for entry: Variant in ids:
		var id: int = entry
		var found: Node3D = mission.world.entity(id) if mission != null else null
		if found != null:
			guarded.append(found)
	var count: int = data.get("guarded_count", guarded.size())
	_lost_before_save = maxi(count - guarded.size(), 0)
