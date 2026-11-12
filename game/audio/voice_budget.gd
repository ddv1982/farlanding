class_name VoiceBudget
extends RefCounted
## Pure voice-allocation logic behind the AudioService's player pools.
##
## A fixed number of voices. A request is refused if its event is cooling down
## or already at its instance cap; otherwise it takes a free voice, or steals
## the lowest-priority voice (oldest first among equals) if that voice's
## priority is not higher than the request's. This is what keeps forty units
## acknowledging at once down to a few clean sounds.
##
## Time is passed in, so tests drive it by hand. A voice also frees itself when
## its expected end time passes, in case a player's `finished` signal never
## comes (e.g. the headless dummy audio driver).

## Returned by `request()` when the sound must not play.
const REJECTED: int = -1

## Index of the voice stolen by the last successful request, or -1.
var last_stolen: int = -1

var _event: Array[StringName] = []
var _priority: PackedInt32Array = []
var _started: PackedFloat64Array = []
var _ends: PackedFloat64Array = []
var _last_start: Dictionary[StringName, float] = {}


func _init(voice_count: int) -> void:
	_event.resize(voice_count)
	_event.fill(&"")
	_priority.resize(voice_count)
	_started.resize(voice_count)
	_ends.resize(voice_count)


func size() -> int:
	return _event.size()


## Asks for a voice for `event_id` at time `now` (seconds) that will last
## `duration` seconds. Returns the voice index, or REJECTED.
func request(
	event_id: StringName,
	priority: int,
	max_instances: int,
	cooldown: float,
	duration: float,
	now: float,
) -> int:
	last_stolen = -1
	_expire(now)
	if cooldown > 0.0 and _last_start.has(event_id):
		var since: float = now - _last_start[event_id]
		if since < cooldown:
			return REJECTED
	if active_count(event_id) >= max_instances:
		return REJECTED
	var voice: int = _event.find(&"")
	if voice == -1:
		voice = _steal_candidate(priority)
		if voice == -1:
			return REJECTED
		last_stolen = voice
	_event[voice] = event_id
	_priority[voice] = priority
	_started[voice] = now
	_ends[voice] = now + maxf(duration, 0.0)
	_last_start[event_id] = now
	return voice


## Marks a voice as free (its player finished or was stopped).
func release(voice: int) -> void:
	if voice >= 0 and voice < _event.size():
		_event[voice] = &""


func is_active(voice: int) -> bool:
	return _event[voice] != &""


func event_of(voice: int) -> StringName:
	return _event[voice]


func active_count(event_id: StringName = &"") -> int:
	var count: int = 0
	for active: StringName in _event:
		if active != &"" and (event_id == &"" or active == event_id):
			count += 1
	return count


func _expire(now: float) -> void:
	for i: int in _event.size():
		if _event[i] != &"" and _ends[i] > 0.0 and now >= _ends[i]:
			_event[i] = &""


func _steal_candidate(priority: int) -> int:
	var best: int = -1
	for i: int in _event.size():
		if _priority[i] > priority:
			continue
		if (
			best == -1
			or _priority[i] < _priority[best]
			or (_priority[i] == _priority[best] and _started[i] < _started[best])
		):
			best = i
	return best
