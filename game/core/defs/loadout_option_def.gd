class_name LoadoutOptionDef
extends Resource
## One choice for a loadout slot (an escort squad, a pre-charged ship ability, cargo).

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
## Techs that must be owned before it can be chosen.
@export var requires_tech: Array[StringName] = []
@export var effects: Array[PerkEffect] = []
