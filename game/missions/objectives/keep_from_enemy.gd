class_name KeepFromEnemyObjective
extends Objective
## Passive: fails when the enemy brings a carriable prop (of `defs`, or any) into the
## objective's area (its base), carried there or dropped there by one of its units
## (PLAN 2.6 Recovery: the Combine takes the artefact home and the mission is lost).

## Who last carried each prop (instance id -> faction), so a prop the enemy dropped in
## its base still counts.
var _last_holder: Dictionary[int, int] = {}


func _evaluate() -> void:
	var enemies: Array[int] = factions_of(def.side)
	var held: bool = false
	for prop: Prop in CarryToObjective.carried_matches(mission.world, def.defs):
		var holder: int = prop.carrier_faction()
		if holder >= 0:
			_last_holder[prop.entity_id] = holder
		var last: int = _last_holder.get(prop.entity_id, -1)
		if not enemies.has(last):
			continue
		held = held or holder >= 0
		var at: Vector3 = prop.sim_position()
		if Vector2(at.x - area_center.x, at.z - area_center.z).length() <= area_radius:
			fail()
			return
	set_progress("The enemy has it!" if held else "")


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	var holders: Dictionary = {}
	for id: int in _last_holder:
		holders[str(id)] = _last_holder[id]
	data["holders"] = holders
	return data


func from_dict(data: Dictionary) -> void:
	super(data)
	var holders: Dictionary = data.get("holders", {})
	for key: Variant in holders:
		var faction: int = holders[key]
		_last_holder[int(str(key))] = faction
