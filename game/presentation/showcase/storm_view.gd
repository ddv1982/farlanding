extends Node3D
## Showcase only: holds a storm at a fixed strength so its look can be checked.

@export_range(0.0, 1.0) var intensity: float = 1.0


func _ready() -> void:
	Events.storm_changed.emit(intensity)
