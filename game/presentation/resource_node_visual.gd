class_name ResourceNodeVisual
extends Node3D
## A deposit or vent in the world. Deposits visibly shrink as they are mined.

const MIN_SCALE := 0.35

@export var model_scene: PackedScene

var _model: Node3D


func _ready() -> void:
	if model_scene != null:
		_model = model_scene.instantiate() as Node3D
		add_child(_model)


## 1 = untouched, 0 = exhausted.
func set_remaining(fraction: float) -> void:
	if _model == null:
		return
	var size := lerpf(MIN_SCALE, 1.0, clampf(fraction, 0.0, 1.0))
	_model.scale = Vector3(lerpf(0.75, 1.0, size), size, lerpf(0.75, 1.0, size))
