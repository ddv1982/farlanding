extends Node3D
## Showcase only: loops the combat effects so their look can be checked without
## staging a fight. Not used by the game.

@export var vfx: CombatVfx

## Slow motion, so a screenshot can catch the short-lived parts of an effect.
@export var time_scale: float = 0.12

var _time: float = 0.0
var _shots: Array[Node3D] = []


func _ready() -> void:
	Engine.time_scale = time_scale


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	for shot: Node3D in _shots:
		shot.position.z -= 30.0 * delta
	_time += delta
	if _time < 1.2:
		return
	_time = 0.0
	for shot: Node3D in _shots:
		shot.queue_free()
	_shots.clear()
	vfx.explosion(Vector3(-6, 0.6, 0), 1.0)
	vfx.explosion(Vector3(0, 0.6, -2), 2.2)
	vfx.explosion(Vector3(8, 0.6, 0), 3.5)
	vfx.sparks(Vector3(-3, 1.0, 4), CombatVfx.FIRE_COLOR, 8)
	vfx.flash(Vector3(3, 1.0, 4), CombatVfx.CONCORD_COLOR, 0.9, 0.3)
	for index: int in 3:
		var shot := Node3D.new()
		add_child(shot)
		shot.position = Vector3(-4.0 + index * 4.0, 1.2, 10.0)
		_shots.append(shot)
		Events.projectile_launched.emit(shot, null)
