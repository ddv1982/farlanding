class_name AmbienceSet
extends Resource
## A planet's ambience as data: its beds and its details. The AmbienceDirector
## plays whichever set the planet names (PlanetAudio); AmbienceCues holds the
## rules. One file per planet in `res://data/sounds/ambience/sets/`.

@export var id: StringName = &""
@export var beds: Array[AmbienceBed] = []
## Pick order matters for the random pick (same roll, same detail).
@export var details: Array[AmbienceDetail] = []


func find_bed(event: StringName) -> AmbienceBed:
	for bed: AmbienceBed in beds:
		if bed.event == event:
			return bed
	return null


func find_detail(event: StringName) -> AmbienceDetail:
	for detail: AmbienceDetail in details:
		if detail.event == event:
			return detail
	return null


func bed_events() -> Array[StringName]:
	var out: Array[StringName] = []
	for bed: AmbienceBed in beds:
		out.append(bed.event)
	return out
