class_name SimClock
extends Node
## Fixed-rate simulation clock. Gameplay advances in 10 Hz ticks driven from
## `_physics_process`; visuals use `interpolation_fraction` to blend between ticks.

## Emitted once per simulation tick, before `Events.sim_ticked`.
signal ticked(tick: int)

const SAVE_VERSION: int = 1
const TICK_RATE: int = 10
const TICK_DELTA: float = 1.0 / TICK_RATE
## Cap on catch-up ticks per physics frame so a long hitch cannot spiral.
const MAX_TICKS_PER_STEP: int = 5
## Absorbs float drift so six 1/60 s steps reliably make one 0.1 s tick.
const EPSILON: float = 1e-6

## While paused no ticks happen and `interpolation_fraction` holds still.
var paused: bool = false

var _tick: int = 0
var _accumulator: float = 0.0


func _physics_process(delta: float) -> void:
	advance(delta)


## Number of ticks since the clock started.
func get_tick() -> int:
	return _tick


## Simulation seconds per tick.
func get_tick_delta() -> float:
	return TICK_DELTA


## How far real time has progressed toward the next tick, in [0, 1).
func get_interpolation_fraction() -> float:
	return clampf(_accumulator / TICK_DELTA, 0.0, 1.0)


## Advances the clock by `delta` seconds and runs any due ticks. Returns how many ran.
func advance(delta: float) -> int:
	if paused:
		return 0
	_accumulator += delta
	var ran: int = 0
	while _accumulator + EPSILON >= TICK_DELTA and ran < MAX_TICKS_PER_STEP:
		_accumulator = maxf(_accumulator - TICK_DELTA, 0.0)
		_tick += 1
		ran += 1
		ticked.emit(_tick)
		Events.sim_ticked.emit(_tick)
	if ran == MAX_TICKS_PER_STEP:
		_accumulator = minf(_accumulator, TICK_DELTA - EPSILON)
	return ran


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "tick": _tick, "paused": paused}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported SimClock save version")
	_tick = data.get("tick", 0)
	paused = data.get("paused", false)
	_accumulator = 0.0
