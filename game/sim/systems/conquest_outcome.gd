class_name ConquestOutcome
extends RefCounted
## Win/lose rules of a conquest skirmish: the player loses when their last
## headquarters (a building of `headquarters`) is destroyed and wins when every
## unit and building of every other faction is destroyed. The neutral Custodians
## (Factions.CUSTODIANS) do not count: they need not be destroyed. `check()` is called after
## each death and announces the result once on `Events.mission_ended`.

enum Result { NONE, WON, LOST }

const SAVE_VERSION: int = 1

var player_faction: int = 0
## The player's HQ type (the Lander); null = the player cannot lose this way.
var headquarters: BuildingDef = null
## The result once the mission ended, else NONE.
var result: Result = Result.NONE


func _init(p_player_faction: int = 0, p_headquarters: BuildingDef = null) -> void:
	player_faction = p_player_faction
	headquarters = p_headquarters


## Result for these entities (dead or dying ones do not count). Losing wins over
## winning when both happen on the same tick.
static func evaluate(
	units: Array[Unit], buildings: Array[Building], faction: int, hq: BuildingDef
) -> Result:
	var has_hq: bool = hq == null
	var enemies: int = 0
	for building: Building in buildings:
		if not Combat.is_alive(building):
			continue
		if building.faction == faction:
			has_hq = has_hq or building.def == hq
		elif not Factions.is_custodian(building.faction):
			enemies += 1
	if not has_hq:
		return Result.LOST
	for unit: Unit in units:
		if (
			unit.faction != faction
			and not Factions.is_custodian(unit.faction)
			and Combat.is_alive(unit)
		):
			enemies += 1
	return Result.WON if enemies == 0 else Result.NONE


## Re-evaluates `world`; on the first decisive result emits `mission_ended`.
func check(world: SimWorld) -> Result:
	if result != Result.NONE:
		return result
	result = evaluate(world.units, world.buildings, player_faction, headquarters)
	if result != Result.NONE:
		Events.mission_ended.emit(result == Result.WON)
	return result


func is_over() -> bool:
	return result != Result.NONE


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "result": result}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported ConquestOutcome save version")
	var saved: int = data.get("result", Result.NONE)
	result = saved as Result
