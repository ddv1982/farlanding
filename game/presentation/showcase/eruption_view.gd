extends Node3D
## Showcase: an Emberfall vent warning and erupting on a loop, to judge the look.

const WARNING: float = 5.0
const PERIOD: float = 9.0
const RADIUS: float = 9.0

@export var vent: Node3D

var _time: float = PERIOD - 1.0
var _warned: bool = false


func _process(delta: float) -> void:
	_time += delta
	if not _warned and _time >= PERIOD - WARNING:
		_warned = true
		Events.eruption_warning.emit(vent, WARNING, RADIUS)
	if _time >= PERIOD:
		_time = 0.0
		_warned = false
		Events.eruption.emit(vent, RADIUS)
