class_name Machine
extends Node
## The state of one Antecedent machine (an engine on Hollow Meridian, ADR 0017), a
## component of its Building. The MachinerySystem plays the rule and changes it; this
## node only holds and saves it, and tells presentation what changed:
##
## - dormant: held by nobody (the building belongs to the Custodians), gives nothing;
## - running: works for the building's faction (it is operational and gives power);
## - shut down: its health ran out; it gives nothing and cannot be shot until
##   `shutdown_left` runs out, then it runs again for the same faction.
##
## `progress` (0..1) is the work done on reactivating or taking it over, by
## `claimant` (a faction, -1 for none).

## The machine started running, shut down or went dormant.
signal state_changed(state: StringName)
## Work on it moved: `progress` 0..1 by `claimant` (-1 = nobody).
signal progress_changed(progress: float, claimant: int)

const SAVE_VERSION: int = 1
const DORMANT: StringName = &"dormant"
const RUNNING: StringName = &"running"
const SHUT_DOWN: StringName = &"shut_down"

var state: StringName = DORMANT
## Reactivation or takeover work done, 0..1.
var progress: float = 0.0
## The faction whose units did that work, or -1.
var claimant: int = -1
## Seconds left before a shut-down machine restarts.
var shutdown_left: float = 0.0
## Units working on it this tick (the system clears it after each tick). Not saved:
## workers report again on the first tick after a load.
var workers: Array[Unit] = []


func is_running() -> bool:
	return state == RUNNING


func is_dormant() -> bool:
	return state == DORMANT


func is_shut_down() -> bool:
	return state == SHUT_DOWN


## Changes the state and announces it (quietly does nothing when unchanged).
func set_state(next: StringName) -> void:
	if next == state:
		return
	state = next
	state_changed.emit(state)


## Sets the work done and by whom, and announces it when it changed.
func set_progress(amount: float, faction: int) -> void:
	var clamped: float = clampf(amount, 0.0, 1.0)
	var who: int = faction if clamped > 0.0 else -1
	if clamped == progress and who == claimant:
		return
	progress = clamped
	claimant = who
	progress_changed.emit(progress, claimant)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"state": String(state),
		"progress": progress,
		"claimant": claimant,
		"shutdown_left": shutdown_left,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Machine save version")
	state = StringName(str(data.get("state", String(DORMANT))))
	progress = data.get("progress", 0.0)
	claimant = data.get("claimant", -1)
	shutdown_left = data.get("shutdown_left", 0.0)
