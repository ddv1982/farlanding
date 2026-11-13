class_name AdvisorQueue
extends RefCounted
## Alert discipline for the Advisor (PLAN §5.3). Pure logic, no playback.
##
## - Throttle: an alert kind is not accepted again within `throttle_of(kind)`
##   seconds of its last acceptance (a nagging "insufficient resources" teaches
##   players to ignore the Advisor).
## - No stacking: while a phrase plays (plus a short gap) nothing else starts;
##   new alerts wait in a short queue, highest priority first, oldest among
##   equals. An alert that waited longer than MAX_WAIT is stale and dropped.
## - Opposites cancel: power restored arriving while a low-power warning still
##   waits drops both (and the other way round); the state flapped unheard.
## - Seen already: alerts about a place (under attack) are dropped while the
##   listener focus is within ON_SCREEN_RADIUS of it; the player is looking at
##   the fight. A dropped alert does not start the throttle, so the warning
##   still comes once the camera moves away.
## - Families: kinds in one FAMILY share their throttle (a primary and a
##   secondary objective completing together, or gameplay raising
##   objective_new as the objective signal arrives, speak once).
##
## Use: `push(kind, now, position)` when an alert arrives (set `focus` first);
## every frame, `pop_ready(now)` and, if it returns a kind, play it and call
## `started(now, seconds)`.

const DEFAULT_THROTTLE: float = 6.0
const THROTTLE: Dictionary[StringName, float] = {
	&"insufficient_resources": 15.0,
	&"low_power": 15.0,
	&"power_restored": 8.0,
	&"deposit_depleted": 10.0,
	&"construction_complete": 3.0,
	&"unit_ready": 4.0,
	&"building_placed": 3.0,
	&"under_attack": 20.0,
	&"discovery": 4.0,
	&"field_option_ready": 20.0,
	&"objective_new": 2.5,
	&"objective_hidden": 2.5,
	&"objective_done": 2.0,
	&"objective_done_secondary": 2.0,
	&"objective_failed": 2.0,
	&"storm_warning": 8.0,
	&"storm_final": 8.0,
	&"objective_time_low": 10.0,
	&"detected": 10.0,
}
const DEFAULT_PRIORITY: int = 50
const PRIORITY: Dictionary[StringName, int] = {
	&"under_attack": 120,
	&"low_power": 100,
	&"power_restored": 80,
	&"construction_complete": 60,
	&"unit_ready": 60,
	&"deposit_depleted": 50,
	&"insufficient_resources": 40,
	&"building_placed": 20,
	&"discovery": 70,
	&"field_option_ready": 45,
	&"detected": 115,
	&"storm_final": 112,
	&"storm_warning": 110,
	&"objective_failed": 105,
	&"objective_time_low": 100,
	&"objective_done": 90,
	&"objective_hidden": 85,
	&"objective_done_secondary": 75,
	&"objective_new": 72,
}
## Kind -> the family whose throttle it shares (kinds not listed are their own).
const FAMILY: Dictionary[StringName, StringName] = {
	&"objective_hidden": &"objective_new",
	&"objective_done_secondary": &"objective_done",
}
## Kind -> the queued kind it makes stale.
const SUPERSEDES: Dictionary[StringName, StringName] = {
	&"power_restored": &"low_power",
	&"low_power": &"power_restored",
}
## Silence after a phrase before the next may start.
const GAP: float = 0.35
## Queued alerts older than this are dropped instead of played late.
const MAX_WAIT: float = 4.0
const MAX_QUEUED: int = 3
## Alert kinds about a place, skipped while the camera already shows it.
const PLACE_KINDS: Array[StringName] = [&"under_attack"]
## Ground distance (m) from the listener focus within which a place is on screen.
const ON_SCREEN_RADIUS: float = 40.0

## Listener focus (the camera's ground point); INF when unknown.
var focus: Vector3 = Vector3.INF

var _last_accepted: Dictionary[StringName, float] = {}
var _kinds: Array[StringName] = []
var _times: PackedFloat64Array = []
var _busy_until: float = -INF


static func throttle_of(kind: StringName) -> float:
	var seconds: float = THROTTLE.get(kind, DEFAULT_THROTTLE)
	return seconds


static func family_of(kind: StringName) -> StringName:
	var family: StringName = FAMILY.get(kind, kind)
	return family


static func priority_of(kind: StringName) -> int:
	var priority: int = PRIORITY.get(kind, DEFAULT_PRIORITY)
	return priority


## True if `position` is known and within ON_SCREEN_RADIUS of the focus.
func is_on_screen(position: Vector3) -> bool:
	if not position.is_finite() or not focus.is_finite():
		return false
	return Vector2(position.x - focus.x, position.z - focus.z).length() <= ON_SCREEN_RADIUS


## Offers an alert, optionally about a world `position`. Returns true if it was
## queued, false if throttled, already on screen, or the queue is full of more
## important alerts.
func push(kind: StringName, now: float, position: Vector3 = Vector3.INF) -> bool:
	if kind == &"":
		return false
	var last: float = _last_accepted.get(family_of(kind), -INF)
	if now - last < throttle_of(kind):
		return false
	if kind in PLACE_KINDS and is_on_screen(position):
		return false
	_expire(now)
	var stale: StringName = SUPERSEDES.get(kind, &"")
	if stale != &"" and _kinds.has(stale):
		# The opposite alert was never heard: both are moot now.
		_remove_kind(stale)
		_last_accepted.erase(stale)
		return false
	if _kinds.size() >= MAX_QUEUED:
		var weakest: int = _weakest()
		if priority_of(_kinds[weakest]) >= priority_of(kind):
			return false
		_remove_at(weakest)
	_kinds.append(kind)
	_times.append(now)
	_last_accepted[family_of(kind)] = now
	return true


## The alert to play now, or &"" if a phrase is still sounding or none waits.
## The returned alert leaves the queue.
func pop_ready(now: float) -> StringName:
	if now < _busy_until:
		return &""
	_expire(now)
	if _kinds.is_empty():
		return &""
	var best: int = 0
	for i: int in range(1, _kinds.size()):
		if priority_of(_kinds[i]) > priority_of(_kinds[best]):
			best = i
	var kind: StringName = _kinds[best]
	_remove_at(best)
	return kind


## Marks a phrase of `seconds` as started at `now`.
func started(now: float, seconds: float) -> void:
	_busy_until = now + maxf(seconds, 0.0) + GAP


func is_busy(now: float) -> bool:
	return now < _busy_until


func queued() -> Array[StringName]:
	return _kinds.duplicate()


func _expire(now: float) -> void:
	for i: int in range(_kinds.size() - 1, -1, -1):
		if now - _times[i] > MAX_WAIT:
			_remove_at(i)


## Lowest priority, newest among equals (the oldest equal keeps its place).
func _weakest() -> int:
	var weakest: int = 0
	for i: int in range(1, _kinds.size()):
		if priority_of(_kinds[i]) <= priority_of(_kinds[weakest]):
			weakest = i
	return weakest


func _remove_kind(kind: StringName) -> void:
	var i: int = _kinds.find(kind)
	if i != -1:
		_remove_at(i)


func _remove_at(i: int) -> void:
	_kinds.remove_at(i)
	_times.remove_at(i)
