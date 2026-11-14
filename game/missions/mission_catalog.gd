class_name MissionCatalog
extends Resource
## The missions offered on the mission select screen, in order. They open one by
## one: the first always, each other once the one before it was won (`is_open`).

@export var missions: Array[MissionDef] = []


## True when `mission` may be played, given the ids of the missions won (`won`): the
## first mission always, a mission already won, and any other once the mission
## before it in the catalog was won. A mission not in the catalog is not open; ids
## in `won` that the catalog does not have change nothing.
func is_open(mission: MissionDef, won: PackedStringArray) -> bool:
	if mission == null or not missions.has(mission):
		return false
	if won.has(String(mission.id)):
		return true
	var previous: MissionDef = previous_of(mission)
	return previous == null or won.has(String(previous.id))


## The mission before `mission` in the catalog (the one to win first), or null for
## the first one or a mission not in the catalog.
func previous_of(mission: MissionDef) -> MissionDef:
	var index: int = missions.find(mission)
	for i: int in range(index - 1, -1, -1):
		if missions[i] != null:
			return missions[i]
	return null
