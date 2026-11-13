extends Node3D
## Showcase: the Thalassa tide going in and out on a loop, to judge the water.

const PERIOD: float = 16.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	Events.tide_changed.emit(0.5 - 0.5 * cos(_time * TAU / PERIOD))
