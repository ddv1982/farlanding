class_name FluxExtractor
extends Node
## Taps a Flux vent: yields `amount` Flux every `interval` seconds of work.

const SAVE_VERSION: int = 1

var amount: int = 5
var interval: float = 4.0
var elapsed: float = 0.0


func setup(p_amount: int, p_interval: float) -> void:
	amount = p_amount
	interval = maxf(p_interval, 0.01)


## Advances by `dt` seconds (already scaled by the power rate). Returns Flux produced.
func tick(dt: float) -> int:
	elapsed += dt
	var produced: int = 0
	while elapsed >= interval:
		elapsed -= interval
		produced += amount
	return produced


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "elapsed": elapsed}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported FluxExtractor save version")
	elapsed = data.get("elapsed", 0.0)
