class_name AreaTrigger
extends Trigger
## Fires when a living unit of `faction` (-1: the mission's player) enters the circle.

var center: Vector3 = Vector3.ZERO
var radius: float = 10.0
var faction: int = -1


func _init(
	p_center: Vector3 = Vector3.ZERO,
	p_radius: float = 10.0,
	p_faction: int = -1,
	p_action: Callable = Callable()
) -> void:
	center = p_center
	radius = p_radius
	faction = p_faction
	action = p_action


func _check(mission: Mission) -> bool:
	var wanted: int = faction if faction >= 0 else mission.player_faction
	for unit: Unit in mission.world.units:
		if unit.faction != wanted or unit.is_dead:
			continue
		var at: Vector3 = unit.sim_position()
		if Vector2(at.x - center.x, at.z - center.z).length() <= radius:
			return true
	return false
