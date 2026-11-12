class_name MusicState
extends Resource
## A music state the director can be asked for (&"explore", &"tension", ...):
## which clip plays and how loud each of its layers is.

@export var name: StringName = &""
@export var clip: StringName = &""
## Per-layer volume in dB, in the clip's layer order. Missing entries are 0 dB;
## -80 silences a layer.
@export var layer_volumes_db: PackedFloat32Array = []
## Higher is more intense. Moving to a lower intensity waits for the score's
## `min_hold`, so the music does not flap when a threat comes and goes.
@export_range(0, 10, 1) var intensity: int = 0
