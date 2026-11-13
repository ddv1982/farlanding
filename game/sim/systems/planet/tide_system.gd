class_name TideSystem
extends PlanetRuleSystem
## Thalassa Low's tide (PLAN 2.5, ADR 0014), played from a TideRule.
##
## low -> (rise announced) -> rising -> high -> (fall announced) -> falling -> low ...
##
## Each turn is announced `warning_seconds` ahead (`Events.tide_turning`, the Advisor's
## `tide_rising` / `tide_falling`); the holds vary at random (the RNG state is saved).
## The sea's height, the tide level and what is known about the next turn go into the
## WorldConditions every tick; the world's FloodSystem turns the sea into closed ground,
## wading and flooded deposits. `Events.tide_changed` follows the tide level (0 low ..
## 1 high) a few times a second at most while it moves.

const SAVE_VERSION: int = 1
const STATE_LOW: StringName = &"low"
const STATE_RISING: StringName = &"rising"
const STATE_HIGH: StringName = &"high"
const STATE_FALLING: StringName = &"falling"
## `tide_changed` is emitted when the level moved this much (or hit 0 or 1) ...
const EMIT_STEP: float = 0.02
## ... and no more often than every this many ticks.
const EMIT_TICKS: int = 3

var state: StringName = STATE_LOW
## 0 = low water, 1 = high water.
var level: float = 0.0
## True once the next turn (out of the current hold) was announced.
var announced: bool = false

var _tide: TideRule = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _now: int = 0
## Tick the current hold ends (the next rise or fall starts).
var _turn_at: int = 0
## Tick the current rise or fall began and ends.
var _phase_start: int = 0
var _phase_end: int = 0
var _emitted: float = 0.0
var _emitted_tick: int = -1000


static func ticks(seconds: float) -> int:
	return roundi(seconds * SimClock.TICK_RATE)


func _setup() -> void:
	_tide = rule as TideRule
	assert(_tide != null, "TideSystem needs a TideRule")
	_rng.seed = rule.random_seed
	_now = world.context.sim_clock.get_tick() if world.context != null else 0
	_turn_at = _now + maxi(ticks(_tide.first_rise_seconds + _variation()), 1)
	_apply_conditions()


## Seconds until the next turn starts (the end of the current hold); 0 while the sea
## moves.
func seconds_until_turn(tick_number: int) -> float:
	if state == STATE_RISING or state == STATE_FALLING:
		return 0.0
	return maxf(float(_turn_at - tick_number) / SimClock.TICK_RATE, 0.0)


## The tick the current hold ends (tests, AI).
func turn_tick() -> int:
	return _turn_at


func indicator_title() -> String:
	return "TIDE"


func indicator_text(tick_number: int) -> String:
	var left: int = ceili(seconds_until_turn(tick_number))
	var clock: String = "%d:%02d" % [floori(left / 60.0), left % 60]
	match state:
		STATE_LOW:
			return "RISING IN " + clock if announced else "LOW"
		STATE_RISING:
			return "RISING"
		STATE_HIGH:
			return "FALLING IN " + clock if announced else "HIGH"
		STATE_FALLING:
			return "FALLING"
	return ""


func indicator_level() -> float:
	return level


func indicator_alarm() -> bool:
	return state == STATE_RISING or (state == STATE_LOW and announced)


func _tick(tick_number: int, _dt: float) -> void:
	_now = tick_number
	match state:
		STATE_LOW:
			_hold(STATE_RISING, ticks(_tide.rise_seconds), true)
		STATE_RISING:
			level = _progress()
			if _now >= _phase_end:
				level = 1.0
				_begin_hold(STATE_HIGH, _tide.high_hold_seconds)
		STATE_HIGH:
			_hold(STATE_FALLING, ticks(_tide.fall_seconds), false)
		STATE_FALLING:
			level = 1.0 - _progress()
			if _now >= _phase_end:
				level = 0.0
				_begin_hold(STATE_LOW, _tide.low_hold_seconds)
	_apply_conditions()
	_emit_level()


## Holding at low or high water: announce the turn in time, then begin it.
func _hold(next: StringName, length: int, rising: bool) -> void:
	if not announced and _now >= _turn_at - ticks(_tide.warning_seconds):
		announced = true
		var seconds: float = maxf(float(_turn_at - _now) / SimClock.TICK_RATE, 0.0)
		Events.tide_turning.emit(seconds, rising)
		Events.advisor_alert.emit(&"tide_rising" if rising else &"tide_falling")
	if _now >= _turn_at:
		state = next
		announced = false
		_phase_start = _now
		_phase_end = _now + maxi(length, 1)


func _begin_hold(next: StringName, seconds: float) -> void:
	state = next
	announced = false
	var wait: float = maxf(seconds + _variation(), _tide.warning_seconds + 1.0)
	_turn_at = _now + ticks(wait)


## How far through the current rise or fall, 0..1.
func _progress() -> float:
	if _phase_end <= _phase_start:
		return 1.0
	return clampf(float(_now - _phase_start) / (_phase_end - _phase_start), 0.0, 1.0)


func _variation() -> float:
	var spread: float = _tide.hold_variation
	return _rng.randf_range(-spread, spread) if spread > 0.0 else 0.0


func _apply_conditions() -> void:
	conditions.sea_level = _tide.sea_level(level)
	conditions.low_water = _tide.low_water
	conditions.high_water = _tide.high_water
	conditions.wading_depth = _tide.wading_depth
	conditions.wading_speed_factor = _tide.wading_speed_factor
	conditions.wading_damage_per_second = _tide.wading_damage_per_second
	conditions.tide_level = level
	conditions.tide_rising = state == STATE_LOW or state == STATE_RISING
	conditions.tide_eta_seconds = seconds_until_turn(_now) if announced else INF
	conditions.shallows_close_seconds = seconds_until_turn(_now) if state == STATE_LOW else 0.0


func _emit_level() -> void:
	if is_equal_approx(level, _emitted):
		return
	var at_end: bool = level <= 0.0 or level >= 1.0
	if not at_end and absf(level - _emitted) < EMIT_STEP:
		return
	if not at_end and _now - _emitted_tick < EMIT_TICKS:
		return
	_emitted = level
	_emitted_tick = _now
	Events.tide_changed.emit(level)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"state": String(state),
		"level": level,
		"announced": announced,
		"tick": _now,
		"turn_at": _turn_at,
		"phase_start": _phase_start,
		"phase_end": _phase_end,
		"emitted": _emitted,
		"rng_state": str(_rng.state),
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported TideSystem save version")
	var saved_state: String = data.get("state", String(STATE_LOW))
	state = StringName(saved_state)
	level = data.get("level", 0.0)
	announced = data.get("announced", false)
	_now = data.get("tick", _now)
	_turn_at = data.get("turn_at", _turn_at)
	_phase_start = data.get("phase_start", 0)
	_phase_end = data.get("phase_end", 0)
	_emitted = data.get("emitted", level)
	var rng_text: String = data.get("rng_state", "")
	if rng_text != "":
		_rng.state = int(rng_text)
	_apply_conditions()
	Events.tide_changed.emit(level)
