class_name EntityDef
extends Resource
## Data definition shared by every entity type. One `.tres` per entity type.

@export var id: StringName = &""
@export var display_name: String = ""
## One line for tooltips: what this entity is for.
@export_multiline var description: String = ""
@export var faction: int = 0
@export var scene: PackedScene
@export var icon: Texture2D
@export var sound_set: StringName = &""
@export_group("Cost")
## Paid when the entity is queued (units) or placed (buildings).
@export_range(0, 100000, 1) var cost_alloy: int = 0
@export_range(0, 100000, 1) var cost_flux: int = 0
## Seconds to produce (units) or construct with one builder (buildings) at full power.
@export_range(0.1, 600.0, 0.1, "suffix:s") var build_time: float = 10.0
