extends Node3D
## The world behind the menus: the Kessel basin seen from a camera that drifts
## slowly round it, low and close enough to feel like arriving. Holds no game
## state; instance it while a menu is up and free it before a mission loads.

## Point the camera circles and looks at.
@export var focus: Vector3 = Vector3(0.0, 2.0, 0.0)
@export var distance: float = 78.0
@export var height: float = 26.0
## Seconds for one full circle.
@export var orbit_seconds: float = 240.0
@export var camera: Camera3D

var _angle: float = 0.6


func _ready() -> void:
	_place()


func _process(delta: float) -> void:
	_angle = wrapf(_angle + delta * TAU / orbit_seconds, 0.0, TAU)
	_place()


func _place() -> void:
	if camera == null:
		return
	# A slow breath in height keeps the horizon from sitting still.
	var lift: float = height + 3.0 * sin(_angle * 3.0)
	camera.position = focus + Vector3(cos(_angle) * distance, lift, sin(_angle) * distance)
	camera.look_at(focus, Vector3.UP)
