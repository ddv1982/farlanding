class_name LoadoutSlotDef
extends Resource
## One loadout slot: the player picks one of its options before a landing. The first
## option is the default and should need no tech.

@export var id: StringName = &""
@export var title: String = ""
@export var options: Array[LoadoutOptionDef] = []


## The option with `option_id`, or null.
func option(option_id: StringName) -> LoadoutOptionDef:
	for found: LoadoutOptionDef in options:
		if found != null and found.id == option_id:
			return found
	return null
