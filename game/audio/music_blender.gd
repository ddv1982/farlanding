class_name MusicBlender
extends RefCounted
## Pure smoothing logic for the music director.
##
## State changes: a more intense (or equal) state applies at once; a calmer one
## waits until the current state has been held for `min_hold` seconds, and the
## latest such request wins. Layer volumes glide linearly in amplitude so a full
## fade takes `fade_seconds`.

var min_hold: float = 8.0
var fade_seconds: float = 3.0
var current_state: StringName = &""
var current_intensity: int = 0

var _since: float = -INF
var _pending: StringName = &""
var _pending_intensity: int = 0
var _levels: PackedFloat32Array = []
var _targets: PackedFloat32Array = []


## Asks for `state`. Returns true if it should be applied now; otherwise it is
## remembered and returned by `poll()` once the hold time has passed.
func request(state: StringName, intensity: int, now: float) -> bool:
	if state == current_state:
		_pending = &""
		return false
	if current_state == &"" or intensity >= current_intensity or now - _since >= min_hold:
		_enter(state, intensity, now)
		return true
	_pending = state
	_pending_intensity = intensity
	return false


## Returns a deferred state that is now due (and enters it), or &"".
func poll(now: float) -> StringName:
	if _pending == &"" or now - _since < min_hold:
		return &""
	var state: StringName = _pending
	_enter(state, _pending_intensity, now)
	return state


func pending_state() -> StringName:
	return _pending


## Sets layer targets in dB. Layers that did not exist yet start silent and fade in.
func set_targets(volumes_db: PackedFloat32Array) -> void:
	var count: int = volumes_db.size()
	var previous: int = _levels.size()
	_levels.resize(count)
	_targets.resize(count)
	for i: int in count:
		if i >= previous:
			_levels[i] = 0.0
		_targets[i] = db_to_linear(volumes_db[i]) if volumes_db[i] > AudioMix.SILENT_DB else 0.0


## Jumps every layer to its target (used when the music starts).
func snap() -> void:
	_levels = _targets.duplicate()


## Advances the fades by `delta` seconds and returns the layer volumes in dB.
func step(delta: float) -> PackedFloat32Array:
	var amount: float = delta / maxf(fade_seconds, 0.001)
	var out: PackedFloat32Array = []
	out.resize(_levels.size())
	for i: int in _levels.size():
		_levels[i] = move_toward(_levels[i], _targets[i], amount)
		out[i] = AudioMix.linear_to_db_safe(_levels[i])
	return out


func _enter(state: StringName, intensity: int, now: float) -> void:
	current_state = state
	current_intensity = intensity
	_since = now
	_pending = &""
