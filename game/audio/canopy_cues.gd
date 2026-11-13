class_name CanopyCues
extends RefCounted
## Pure rules for Verdance's canopy (Phase 8c). The CanopySound node feeds it
## what gameplay reports (`Events.canopy_cover_changed(unit, covered)`) and asks
## what to hear; nothing here plays.
##
## - Rustles: the player's own units going under a crown play RUSTLE_IN (a soft
##   swell of leaves closing over them), coming out RUSTLE_OUT (lighter,
##   brighter). Only for units within VIEW_RADIUS of the camera's ground focus.
## - One gesture per group: a rustle in one direction folds every further
##   report in that direction into it while they keep coming less than
##   GESTURE_GAP apart (a squad filing under a crown over two seconds is one
##   rustle), for at most GESTURE_MAX; after that the next report starts a new
##   gesture. In and out are separate gestures, but never closer than MIN_GAP.
## - Shade: while the camera's focus is under a crown the Ambience bus's high
##   band closes a little (the leaves overhead), from OPEN_CUTOFF_HZ to
##   SHADE_CUTOFF_HZ, gliding at SHADE_RATE per second.

const RUSTLE_IN: StringName = &"canopy_rustle_in"
const RUSTLE_OUT: StringName = &"canopy_rustle_out"
## Rustles further than this from the camera's focus are not played (m).
const VIEW_RADIUS: float = 55.0
## Reports closer together than this belong to the same gesture (s).
const GESTURE_GAP: float = 0.5
## A gesture never lasts longer than this (s).
const GESTURE_MAX: float = 2.5
## No two rustles start closer together than this, whatever their direction (s).
const MIN_GAP: float = 0.2
## Without a canopy map, a covered unit this close to the focus means the focus
## is under a crown (m).
const SHADE_RADIUS: float = 8.0
## Shade glide per second (0 open .. 1 under a crown).
const SHADE_RATE: float = 0.8
const OPEN_CUTOFF_HZ: float = 20000.0
const SHADE_CUTOFF_HZ: float = 6000.0

## Per direction (true = in): when its gesture started and its last report.
var _started: Dictionary[bool, float] = {true: -INF, false: -INF}
var _last: Dictionary[bool, float] = {true: -INF, false: -INF}
var _last_rustle: float = -INF


static func event_for(covered: bool) -> StringName:
	return RUSTLE_IN if covered else RUSTLE_OUT


## True if a sound at `at` is close enough to the focus to be heard as a rustle.
static func in_view(at: Vector3, focus: Vector3) -> bool:
	return Vector2(at.x - focus.x, at.z - focus.z).length() <= VIEW_RADIUS


## Ambience bus low-pass cutoff (Hz) at `shade` (0 open .. 1 under a crown).
static func shade_cutoff_hz(shade: float) -> float:
	var amount: float = clampf(shade, 0.0, 1.0)
	return OPEN_CUTOFF_HZ * pow(SHADE_CUTOFF_HZ / OPEN_CUTOFF_HZ, amount)


## A player unit in view went under a crown (`covered`) or came out at `now`.
## Returns true if this starts a new rustle, false if it folds into one.
func offer(covered: bool, now: float) -> bool:
	var continuing: bool = (
		now - _last[covered] < GESTURE_GAP and now - _started[covered] < GESTURE_MAX
	)
	_last[covered] = now
	if continuing:
		return false
	if now - _last_rustle < MIN_GAP:
		# Too close to the other direction's rustle: it carries this one too.
		_started[covered] = now
		return false
	_started[covered] = now
	_last_rustle = now
	return true


func reset() -> void:
	for direction: bool in [true, false]:
		_started[direction] = -INF
		_last[direction] = -INF
	_last_rustle = -INF
