class_name MusicClip
extends Resource
## One clip of a planet's score: synchronised layers (same length and tempo)
## that start together and loop together, so each can fade independently.

@export var name: StringName = &""
@export var layers: Array[AudioStream] = []
## Names for the layers, same order (for tools and debugging).
@export var layer_names: PackedStringArray = []
## Variant group per layer, same order ("" = not a variant). Layers sharing a
## group take turns: the MusicDirector plays one of them per loop, so a long
## stretch in one state moves through different material.
@export var layer_groups: PackedStringArray = []
## Length of the clip's loop in beats (for picking variants on the loop).
@export_range(0, 1024, 1) var loop_beats: int = 0
