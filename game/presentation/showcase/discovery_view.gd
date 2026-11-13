extends Node3D
## Showcase only: loops the exploration effects (resolve pulse, heal field,
## field options) so their look can be checked without playing a mission.

@export var vfx: DiscoveryVfx

var _time: float = 99.0


func _process(delta: float) -> void:
	_time += delta
	if _time < 4.0:
		return
	_time = 0.0
	vfx.field(Vector3(-14, 0.5, 0), Color(0.45, 0.95, 0.5), 8.0, 4.0)
	vfx.pulse(Vector3(-14, 0.5, 0), Color(0.45, 0.95, 0.5), 9.0, 1.1)
	vfx.pulse(Vector3(2, 0.5, -4), DiscoveryVfx.SCAN_COLOR, 12.0, 3.0)
	vfx.beam(Vector3(14, 0.5, 2), DiscoveryVfx.STRIKE_COLOR, 1.6, 2.5)
	vfx.pulse(Vector3(14, 0.5, 2), DiscoveryVfx.STRIKE_COLOR, 7.0, 2.5)
