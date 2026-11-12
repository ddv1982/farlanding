class_name Construction
extends Node
## Construction state of a building. Builders add work each tick; the site is
## finished once the work reaches the build time. Several builders add up, so more
## builders finish sooner.

const SAVE_VERSION: int = 1

## Seconds of work needed with one builder at full power.
var build_time: float = 10.0
## Seconds of work done so far.
var work: float = 0.0
## Builders that worked on the site during the last finished tick.
var builders: int = 0

var _builders_this_tick: int = 0


## Starts a site (`complete` = false) or marks the building as already standing.
func start(p_build_time: float, complete: bool) -> void:
	build_time = maxf(p_build_time, 0.01)
	work = build_time if complete else 0.0
	builders = 0
	_builders_this_tick = 0


## One builder's work for this tick, in seconds (already scaled by its build rate
## and the faction's power).
func add_work(seconds: float) -> void:
	if is_complete():
		return
	work = minf(work + maxf(seconds, 0.0), build_time)
	_builders_this_tick += 1


func is_complete() -> bool:
	return work >= build_time


## Done share in [0, 1].
func progress() -> float:
	return clampf(work / build_time, 0.0, 1.0)


## Closes the tick: records how many builders worked on it.
func end_tick() -> void:
	builders = _builders_this_tick
	_builders_this_tick = 0


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "build_time": build_time, "work": work}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Construction save version")
	build_time = data.get("build_time", build_time)
	work = data.get("work", 0.0)
