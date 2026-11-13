class_name Trigger
extends RefCounted
## Something a mission script waits for (PLAN 3.6): checked by the Mission every sim
## tick; when it fires its `action` runs (once, unless `repeat`). Subclasses: area,
## timer and event triggers.

## What to do when it fires: `func() -> void`.
var action: Callable = Callable()
## Fires again every time its condition holds anew (an area trigger re-arms when the
## area is empty again).
var repeat: bool = false
var fired_count: int = 0

var _armed: bool = true


## Checks the condition once (called by the Mission each tick).
func update(mission: Mission) -> void:
	if not _armed:
		if repeat and not _check(mission):
			_armed = true
		return
	if not _check(mission):
		return
	_armed = false
	fired_count += 1
	if action.is_valid():
		action.call()


## True once it fired (and is not armed again).
func has_fired() -> bool:
	return fired_count > 0


## Begins in `mission` (timers start counting here).
func start(_mission: Mission) -> void:
	pass


## Ends: lets go of anything it listens to.
func stop() -> void:
	pass


## Run-time state for a saved game. Triggers are code (a mission script adds them),
## so a load re-creates them through the script and restores this by position.
func to_dict() -> Dictionary:
	return {"fired": fired_count, "armed": _armed}


func from_dict(data: Dictionary) -> void:
	fired_count = data.get("fired", 0)
	_armed = data.get("armed", true)


## Override: true while the condition holds.
func _check(_mission: Mission) -> bool:
	return false
