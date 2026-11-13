class_name FluxExtractor
extends Node
## Taps a Flux vent: yields `amount` Flux every `interval` seconds of work. A rich vent
## shortens the interval (`ResourceNodeDef.flux_rate_scale`). An eruption knocks it
## out, and venting stalls it briefly: while `stalled_seconds` runs it yields nothing
## (ADR 0015).

## The Tap was knocked out (an eruption, a controlled vent) or works again.
signal knocked_out_changed(knocked_out: bool)

## 2: the stall and the rate scale.
const SAVE_VERSION: int = 2

var amount: int = 5
var interval: float = 4.0
var elapsed: float = 0.0
## Seconds it still yields nothing.
var stalled_seconds: float = 0.0

var _base_interval: float = 4.0


func setup(p_amount: int, p_interval: float) -> void:
	amount = p_amount
	_base_interval = maxf(p_interval, 0.01)
	interval = _base_interval


## Draws on a vent `scale` times as rich as an ordinary one.
func set_rate_scale(scale: float) -> void:
	interval = maxf(_base_interval / maxf(scale, 0.01), 0.01)


## True while knocked out (it yields nothing).
func is_stalled() -> bool:
	return stalled_seconds > 0.0


## Yields nothing for `seconds` (the longer of this and a stall already running).
func stall(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var was: bool = is_stalled()
	stalled_seconds = maxf(stalled_seconds, seconds)
	if not was:
		knocked_out_changed.emit(true)


## Advances by `dt` seconds (already scaled by the power rate). Returns Flux produced.
## A stall runs down in game seconds (`real_dt`), whatever the power.
func tick(dt: float, real_dt: float = -1.0) -> int:
	if stalled_seconds > 0.0:
		stalled_seconds = maxf(stalled_seconds - (real_dt if real_dt >= 0.0 else dt), 0.0)
		if stalled_seconds <= 0.0:
			knocked_out_changed.emit(false)
		return 0
	elapsed += dt
	var produced: int = 0
	while elapsed >= interval:
		elapsed -= interval
		produced += amount
	return produced


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"elapsed": elapsed,
		"stalled": stalled_seconds,
		"interval": interval,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported FluxExtractor save version")
	elapsed = data.get("elapsed", 0.0)
	stalled_seconds = data.get("stalled", 0.0)
	interval = data.get("interval", interval)
	if stalled_seconds > 0.0:
		knocked_out_changed.emit(true)
