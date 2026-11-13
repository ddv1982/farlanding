class_name Cloak
extends Node
## Lets a unit (the Wisp) hide. In stealth mode, on by default, the unit creeps at
## no more than its def's `cloak_max_speed`, and once it has held still or crept for
## `cloak_delay` seconds the cloak closes: its signature drops to `cloak_signature`.
## Leaving stealth mode (a CloakCommand) gives back full speed and opens the cloak.
## A hit opens the cloak for BREAK_SECONDS. Read by the stealth system through
## `signature()`, by presentation through `Unit.is_cloaked`.

## The cloak closed (true) or opened (false).
signal changed(cloaked: bool)

const SAVE_VERSION: int = 1
## A hit opens the cloak for this long.
const BREAK_SECONDS: float = 2.0
## Slack on the creeping speed (the mover settles a little above its cap).
const SPEED_SLACK: float = 0.15

var unit: Unit = null
## Creeping and cloaking (true) or running in the open (false).
var stealth_mode: bool = true
var is_cloaked: bool = false

var _quiet_seconds: float = 0.0
var _broken_seconds: float = 0.0


func setup(p_unit: Unit) -> void:
	unit = p_unit
	_apply_speed()


## Switches stealth mode on or off (the unit's top speed follows).
func set_stealth_mode(enabled: bool) -> void:
	if enabled == stealth_mode:
		return
	stealth_mode = enabled
	_quiet_seconds = 0.0
	_apply_speed()
	if not enabled:
		_set_cloaked(false)


## Opens the cloak for `seconds` (hit, or revealed by firing).
func break_cloak(seconds: float = BREAK_SECONDS) -> void:
	_broken_seconds = maxf(_broken_seconds, seconds)
	_quiet_seconds = 0.0
	_set_cloaked(false)


## One sim tick at the unit's current `speed`.
func tick(dt: float, speed: float) -> void:
	_broken_seconds = maxf(_broken_seconds - dt, 0.0)
	if not stealth_mode or _broken_seconds > 0.0:
		_quiet_seconds = 0.0
		_set_cloaked(false)
		return
	if speed <= unit.def.cloak_max_speed + SPEED_SLACK:
		_quiet_seconds += dt
	else:
		_quiet_seconds = 0.0
	_set_cloaked(_quiet_seconds >= unit.def.cloak_delay)


## The unit's signature now: the cloaked one while cloaked, else the def's own.
func signature() -> float:
	return unit.def.cloak_signature if is_cloaked else unit.def.signature


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"stealth_mode": stealth_mode,
		"cloaked": is_cloaked,
		"quiet": _quiet_seconds,
		"broken": _broken_seconds,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Cloak save version")
	stealth_mode = data.get("stealth_mode", true)
	_quiet_seconds = data.get("quiet", 0.0)
	_broken_seconds = data.get("broken", 0.0)
	_apply_speed()
	var cloaked: bool = data.get("cloaked", false)
	_set_cloaked(cloaked)


func _apply_speed() -> void:
	if unit != null and unit.locomotion != null:
		unit.locomotion.set_speed_limit(unit.def.cloak_max_speed if stealth_mode else INF)


func _set_cloaked(cloaked: bool) -> void:
	if cloaked == is_cloaked:
		return
	is_cloaked = cloaked
	changed.emit(cloaked)
