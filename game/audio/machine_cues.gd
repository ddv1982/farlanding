class_name MachineCues
extends RefCounted
## Pure rules for Hollow Meridian's old engines (Phase 8d). The MachineSound
## node feeds it `Events.machine_reactivated(machine, faction)` and
## `machine_lost(machine, faction)` and asks what to hear; nothing here plays.
##
## | Signal                              | Heard (at the machine)                     |
## |-------------------------------------|--------------------------------------------|
## | reactivated by the player's faction | SPINUP, then the RUN loop while it runs    |
## | reactivated by another faction      | SEIZED (colder), only if the player can    |
## |                                     | see it and it is within VIEW_RADIUS        |
## | lost by the player's faction        | WINDDOWN; the RUN loop stops               |
## | lost by another faction             | nothing (a takeover's spin-up says it)     |
##
## A takeover arrives as lost (old owner) then reactivated (new owner). When the
## enemy takes one of the player's engines, the wind-down has already told it:
## a seizure of the same machine within FOLD_SECONDS of the player's loss is
## not played on top. The RUN loop starts RUN_DELAY after the spin-up (whose
## end already carries the hum), on at most MAX_HUMS running engines nearest
## the camera's focus within HUM_RADIUS.

const SPINUP: StringName = &"machine_spinup"
const WINDDOWN: StringName = &"machine_winddown"
const SEIZED: StringName = &"machine_seized"
const RUN: StringName = &"loop_engine_run"
## Another faction's seizure is only heard this close to the camera's focus (m).
const VIEW_RADIUS: float = 90.0
const FOLD_SECONDS: float = 1.0
const MAX_HUMS: int = 3
const HUM_RADIUS: float = 55.0
## Seconds from the spin-up to the run loop taking over.
const RUN_DELAY: float = 2.5
## Seconds for a run loop to fade in or out.
const HUM_FADE: float = 1.2


## The one-shot for a reactivation by `faction`: the spin-up for the player's
## faction, the colder seizure for another one the player can see (`seen`),
## else nothing.
static func reactivated_event(faction: int, player_faction: int, seen: bool) -> StringName:
	if faction == player_faction:
		return SPINUP
	return SEIZED if seen else &""


## The one-shot when `faction` loses a machine: the wind-down for the player's.
static func lost_event(faction: int, player_faction: int) -> StringName:
	return WINDDOWN if faction == player_faction else &""


## Whether a seizure at `now` folds into a wind-down of the same machine heard
## at `lost_at` (-INF if none).
static func folds(now: float, lost_at: float) -> bool:
	return now - lost_at < FOLD_SECONDS


static func in_view(at: Vector3, focus: Vector3, radius: float = VIEW_RADIUS) -> bool:
	return Vector2(at.x - focus.x, at.z - focus.z).length() <= radius
