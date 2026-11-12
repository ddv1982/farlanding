class_name MusicClip
extends Resource
## One clip of a planet's score: synchronised layers (same length and tempo)
## that start together and loop together, so each can fade independently.

@export var name: StringName = &""
@export var layers: Array[AudioStream] = []
## Names for the layers, same order (for tools and debugging).
@export var layer_names: PackedStringArray = []
