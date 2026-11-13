class_name DustStormSystem
extends PlanetRuleSystem
## Kessel Reach's dust storms (PLAN 2.5, ADR 0011), played from a DustStormRule.
##
## Clear -> warning (announced: `Events.storm_incoming`, the Advisor's
## `storm_warning`, or `storm_final` for the climax) -> building -> full -> fading
## -> clear, then the next storm is drawn. While a storm blows, the WorldConditions
## scale vision, ground speed (hover units less), sight cones and long weapon ranges
## by its intensity, for every faction. `Events.storm_changed` follows the intensity
## (a few times a second at most). A climax (`schedule_climax`) is a storm that
## reaches full strength at a given tick and never lifts; regular storms that would
## run into it are skipped.

const SAVE_VERSION: int = 1
const STATE_CLEAR: StringName = &"clear"
const STATE_WARNING: StringName = &"warning"
const STATE_BUILDING: StringName = &"building"
const STATE_FULL: StringName = &"full"
const STATE_FADING: StringName = &"fading"
## `storm_changed` is emitted when the intensity moved this much (or hit 0 or 1) ...
const EMIT_STEP: float = 0.04
## ... and no more often than every this many ticks.
const EMIT_TICKS: int = 3
## A regular storm must end this long before the climax is announced.
const CLIMAX_MARGIN_SECONDS: float = 30.0
const NEVER: int = 1 << 60

var state: StringName = STATE_CLEAR
## 0 = clear, 1 = full storm.
var intensity: float = 0.0
## True once the climax storm is under way (it will not lift).
var is_final: bool = false

var _storm: DustStormRule = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _now: int = 0
## Tick the next storm starts building (NEVER = none drawn).
var _next_start: int = NEVER
## Tick the current phase (building, full, fading) ends.
var _phase_start: int = 0
var _phase_end: int = 0
## Intensity when the current phase began (a fade that turns into a climax).
var _phase_from: float = 0.0
## Tick the climax reaches full strength (-1 = none).
var _climax_tick: int = -1
var _emitted: float = 0.0
var _emitted_tick: int = -1000


static func ticks(seconds: float) -> int:
	return roundi(seconds * SimClock.TICK_RATE)


func _setup() -> void:
	_storm = rule as DustStormRule
	assert(_storm != null, "DustStormSystem needs a DustStormRule")
	_rng.seed = rule.random_seed
	_now = world.context.sim_clock.get_tick() if world.context != null else 0
	_next_start = _now + ticks(_storm.first_storm_seconds + _variation(_storm.interval_variation))
	_apply_conditions()


## The storm that ends the mission: full strength at `at_tick`, never lifting.
func schedule_climax(at_tick: int) -> void:
	_climax_tick = at_tick
	if state == STATE_CLEAR and _next_start != NEVER and not _fits_before_climax(_next_start):
		_next_start = NEVER


## Seconds until an announced storm starts building; INF if none is announced.
func seconds_until_storm(tick_number: int) -> float:
	if state != STATE_WARNING:
		return INF
	return maxf(float(_storm_start() - tick_number) / SimClock.TICK_RATE, 0.0)


## The tick the next (regular) storm starts building, NEVER if none (tests, AI).
func next_storm_tick() -> int:
	return _next_start


func indicator_title() -> String:
	return "DUST STORM"


func indicator_text(tick_number: int) -> String:
	match state:
		STATE_WARNING:
			var left: int = ceili(seconds_until_storm(tick_number))
			var clock: String = "%d:%02d" % [floori(left / 60.0), left % 60]
			return ("FINAL IN " if is_final else "IN ") + clock
		STATE_BUILDING:
			return "BUILDING"
		STATE_FULL:
			return "BURIED" if is_final else "FULL"
		STATE_FADING:
			return "PASSING"
	return "CLEAR"


func indicator_level() -> float:
	return intensity


func indicator_alarm() -> bool:
	return state != STATE_CLEAR


func _tick(tick_number: int, _dt: float) -> void:
	_now = tick_number
	_check_climax()
	match state:
		STATE_CLEAR:
			if _next_start != NEVER and _now >= _next_start - ticks(_storm.warning_seconds):
				_announce(_next_start)
		STATE_WARNING:
			if _now >= _storm_start():
				_begin_phase(STATE_BUILDING, ticks(_storm.build_seconds))
		STATE_BUILDING:
			intensity = _progress()
			if _now >= _phase_end:
				intensity = 1.0
				var hold: int = ticks(_storm.hold_seconds + _variation(_storm.hold_variation))
				_begin_phase(STATE_FULL, NEVER if is_final else maxi(hold, 1))
		STATE_FULL:
			intensity = 1.0
			if not is_final and _now >= _phase_end:
				_begin_phase(STATE_FADING, ticks(_storm.fade_seconds))
		STATE_FADING:
			intensity = 1.0 - _progress()
			if _now >= _phase_end:
				intensity = 0.0
				state = STATE_CLEAR
				_draw_next()
				Events.advisor_alert.emit(&"storm_passed")
	_apply_conditions()
	_emit_intensity()


## The climax is due to be announced (or a storm already blowing turns into it).
func _check_climax() -> void:
	if _climax_tick < 0 or is_final:
		return
	var start: int = _climax_tick - ticks(_storm.build_seconds)
	if _now < start - ticks(_storm.warning_seconds):
		return
	is_final = true
	_next_start = start
	match state:
		STATE_CLEAR, STATE_WARNING:
			_announce(start)
		STATE_FADING:
			# Turn back: it builds again from where it is, into the storm that stays.
			_begin_phase(STATE_BUILDING, maxi(_climax_tick - _now, 1))
			_phase_from = intensity
		STATE_FULL:
			_phase_end = NEVER


func _announce(start: int) -> void:
	state = STATE_WARNING
	_next_start = start
	var seconds: float = maxf(float(start - _now) / SimClock.TICK_RATE, 0.0)
	Events.storm_incoming.emit(seconds)
	# The storm that ends the mission has its own, sterner warning.
	Events.advisor_alert.emit(&"storm_final" if is_final else &"storm_warning")


func _storm_start() -> int:
	return _next_start


func _begin_phase(next: StringName, length: int) -> void:
	state = next
	_phase_start = _now
	_phase_end = _now + length if length < NEVER else NEVER
	_phase_from = intensity if next == STATE_BUILDING else 1.0


## How far through the current phase, 0..1 (building rises from `_phase_from`).
func _progress() -> float:
	if _phase_end == NEVER or _phase_end <= _phase_start:
		return 1.0
	var t: float = clampf(float(_now - _phase_start) / (_phase_end - _phase_start), 0.0, 1.0)
	if state == STATE_BUILDING:
		return lerpf(_phase_from, 1.0, t)
	return t


func _draw_next() -> void:
	var wait: float = maxf(
		_storm.interval_seconds + _variation(_storm.interval_variation),
		_storm.warning_seconds + 1.0
	)
	var start: int = _now + ticks(wait)
	_next_start = start if _fits_before_climax(start) else NEVER


## True if a regular storm starting at `start` is over before the climax is announced.
func _fits_before_climax(start: int) -> bool:
	if _climax_tick < 0:
		return true
	var longest: float = (
		_storm.build_seconds
		+ _storm.hold_seconds
		+ _storm.hold_variation
		+ _storm.fade_seconds
		+ CLIMAX_MARGIN_SECONDS
	)
	var climax_warning: int = (
		_climax_tick - ticks(_storm.build_seconds) - ticks(_storm.warning_seconds)
	)
	return start + ticks(longest) < climax_warning


func _variation(spread: float) -> float:
	return _rng.randf_range(-spread, spread) if spread > 0.0 else 0.0


func _apply_conditions() -> void:
	var i: float = intensity
	conditions.storm_intensity = i
	conditions.storm_is_final = is_final
	conditions.storm_eta_seconds = seconds_until_storm(_now)
	conditions.set_vision(lerpf(1.0, _storm.vision_factor, i))
	conditions.set_speed(
		lerpf(1.0, _storm.ground_speed_factor, i), lerpf(1.0, _storm.hover_speed_factor, i)
	)
	conditions.sight_factor = lerpf(1.0, _storm.sight_factor, i)
	conditions.long_range_from = _storm.long_range_from
	conditions.range_factor = lerpf(1.0, _storm.long_range_factor, i)


func _emit_intensity() -> void:
	if is_equal_approx(intensity, _emitted):
		return
	var at_end: bool = intensity <= 0.0 or intensity >= 1.0
	if not at_end and absf(intensity - _emitted) < EMIT_STEP:
		return
	if not at_end and _now - _emitted_tick < EMIT_TICKS:
		return
	_emitted = intensity
	_emitted_tick = _now
	Events.storm_changed.emit(intensity)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"state": String(state),
		"intensity": intensity,
		"final": is_final,
		"tick": _now,
		"next_start": _next_start,
		"phase_start": _phase_start,
		"phase_end": _phase_end,
		"phase_from": _phase_from,
		"climax": _climax_tick,
		"emitted": _emitted,
		"rng_state": str(_rng.state),
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported DustStormSystem save version")
	var saved_state: String = data.get("state", String(STATE_CLEAR))
	state = StringName(saved_state)
	intensity = data.get("intensity", 0.0)
	is_final = data.get("final", false)
	_now = data.get("tick", _now)
	_next_start = data.get("next_start", _next_start)
	_phase_start = data.get("phase_start", 0)
	_phase_end = data.get("phase_end", 0)
	_phase_from = data.get("phase_from", 0.0)
	_climax_tick = data.get("climax", -1)
	_emitted = data.get("emitted", intensity)
	var rng_text: String = data.get("rng_state", "")
	if rng_text != "":
		_rng.state = int(rng_text)
	_apply_conditions()
	Events.storm_changed.emit(intensity)
