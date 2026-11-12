class_name EntityDef
extends Resource
## Data definition shared by every entity type. One `.tres` per entity type.

@export var id: StringName = &""
@export var display_name: String = ""
@export var faction: int = 0
@export var scene: PackedScene
@export var icon: Texture2D
@export var sound_set: StringName = &""
