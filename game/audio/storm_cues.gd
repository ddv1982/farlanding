class_name StormCues
extends RefCounted
## Pure rules for the Kessel dust storm (Phase 6). The StormSound node feeds
## it `Events.storm_changed` intensities (0 = clear, 1 = full storm) and asks
## what to hear; nothing here plays anything.
##
## Static mapping, intensity -> sound:
## - Bed layers fade in one after another and follow intensity smoothly: the
##   wind body from 0.05 (full at 0.7), the grit on hulls from 0.3 (full at 1),
##   the low pressure throb from 0.5 (full at 1). Each is an equal-power
##   smoothstep, so a storm building over a minute swells evenly.
## - The muffle (world heard through dust) starts at 0.55 and is full at 0.95:
##   a low-pass on the SFX and Ambience buses closing from 20 kHz to 900 Hz and
##   their level dipping (SFX -4 dB, Ambience -10 dB: the storm replaces the
##   planet's own air). Unit replies, the Advisor, the interface, discovery and
##   stealth stingers are on other buses and stay clear.
## - The score's storm layer: silent below 0.1, then rising to -3 dB at 0.8
##   (the Weather beds carry the storm; the score only leans into it).
## - Gusts from 0.25 and debris from 0.45, more often as the storm grows.
##
## Stateful part (one instance per mission): it remembers the strongest point
## the storm reached, so it can say when a real storm has *passed* (it peaked
## at 0.5 or more and fell below 0.08), and it freezes when the mission ends
## during a storm: the Survey storm does not lift.

const WIND: StringName = &"wind"
const GRIT: StringName = &"grit"
const THROB: StringName = &"throb"
const LAYERS: Array[StringName] = [WIND, GRIT, THROB]
## Layer -> SoundEvent whose first stream is the layer's loop.
const LAYER_EVENTS: Dictionary[StringName, StringName] = {
	WIND: &"amb_storm_wind",
	GRIT: &"amb_storm_grit",
	THROB: &"amb_storm_throb",
}
## Layer -> intensity where it starts, intensity where it is full.
const LAYER_RANGE: Dictionary[StringName, Vector2] = {
	WIND: Vector2(0.05, 0.7),
	GRIT: Vector2(0.3, 1.0),
	THROB: Vector2(0.5, 1.0),
}

const FRONT_RUMBLE: StringName = &"storm_front_rumble"
const GUST: StringName = &"storm_gust"
const DEBRIS: StringName = &"storm_debris"
const PASSED: StringName = &"storm_passed"
const STING_FINAL: StringName = &"mus_sting_storm_final"
const STING_OUTSURVEYED: StringName = &"mus_sting_outsurveyed"
const STING_VICTORY: StringName = &"mus_sting_victory"
const STING_DEFEAT: StringName = &"mus_sting_defeat"

const MUFFLE_RANGE: Vector2 = Vector2(0.55, 0.95)
const MUFFLE_OPEN_HZ: float = 20000.0
const MUFFLE_CLOSED_HZ: float = 900.0
## Bus -> level change at full muffle (dB).
const MUFFLE_DB: Dictionary[StringName, float] = {
	&"SFX": -4.0,
	&"Ambience": -10.0,
}
const MUSIC_RANGE: Vector2 = Vector2(0.1, 0.8)
const MUSIC_FLOOR_DB: float = -14.0
const MUSIC_TOP_DB: float = -3.0
const GUST_FROM: float = 0.25
const DEBRIS_FROM: float = 0.45
## Seconds between gusts at the start of their range .. at full storm.
const GUST_GAP: Vector2 = Vector2(14.0, 3.5)
const DEBRIS_GAP: Vector2 = Vector2(9.0, 1.6)
## A storm "passes" when it falls below CLEAR after peaking at PEAK or more.
const PEAK: float = 0.5
const CLEAR: float = 0.08
## How fast the heard intensity follows the reported one (per second).
const FOLLOW_RATE: float = 0.6
## A storm at least this strong when the mission ends is the final storm.
const FINAL_AT: float = 0.5

var intensity: float = 0.0
var target: float = 0.0
var peak: float = 0.0
var frozen: bool = false


## 0..1 equal-power ramp of `value` across `span`.
static func ramp(value: float, span: Vector2) -> float:
	var u: float = clampf((value - span.x) / maxf(span.y - span.x, 0.0001), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Volume (dB) of a bed layer at `value` (AudioMix.SILENT_DB when silent).
static func layer_db(layer: StringName, value: float) -> float:
	var span: Vector2 = LAYER_RANGE.get(layer, Vector2(0.0, 1.0))
	return AudioMix.linear_to_db_safe(sqrt(ramp(value, span)))


## 0..1 amount of the world muffle at `value`.
static func muffle_amount(value: float) -> float:
	return ramp(value, MUFFLE_RANGE)


## Low-pass cutoff for a muffle amount (exponential, so it sounds even).
static func muffle_cutoff_hz(amount: float) -> float:
	var a: float = clampf(amount, 0.0, 1.0)
	return MUFFLE_OPEN_HZ * pow(MUFFLE_CLOSED_HZ / MUFFLE_OPEN_HZ, a)


## Bus level offset (dB) for a muffle amount; 0 for buses the storm leaves alone.
static func muffle_db(bus: StringName, amount: float) -> float:
	return MUFFLE_DB.get(bus, 0.0) * clampf(amount, 0.0, 1.0)


## Gain (dB) for the score's storm layer at `value`.
static func music_gain_db(value: float) -> float:
	if value < MUSIC_RANGE.x:
		return AudioMix.SILENT_DB
	return lerpf(MUSIC_FLOOR_DB, MUSIC_TOP_DB, ramp(value, MUSIC_RANGE))


## Seconds to the next gust at `value` (INF below GUST_FROM). `roll` in [0, 1).
static func gust_gap(value: float, roll: float) -> float:
	return _gap(value, GUST_FROM, GUST_GAP, roll)


static func debris_gap(value: float, roll: float) -> float:
	return _gap(value, DEBRIS_FROM, DEBRIS_GAP, roll)


## The sting(s) for the end of a mission, best first: a defeat inside a storm
## is the storm's own ending; a defeat while the enemy was banking Intel is the
## out-surveyed phrase; otherwise the generic one.
static func ending_stings(won: bool, storm: float, outsurveyed: bool) -> Array[StringName]:
	if won:
		return [STING_VICTORY]
	if storm >= FINAL_AT:
		return [STING_FINAL, STING_DEFEAT]
	if outsurveyed:
		return [STING_OUTSURVEYED, STING_DEFEAT]
	return [STING_DEFEAT]


static func _gap(value: float, from: float, gaps: Vector2, roll: float) -> float:
	if value < from:
		return INF
	var u: float = clampf((value - from) / (1.0 - from), 0.0, 1.0)
	return lerpf(gaps.x, gaps.y, u) * lerpf(0.6, 1.4, clampf(roll, 0.0, 1.0))


# --- State ------------------------------------------------------------------------


## A new report from the storm system. Once frozen it may only rise.
func report(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	target = maxf(target, clamped) if frozen else clamped


## Moves the heard intensity toward the reported one. Returns &"passed" on
## the step where a real storm clears, else &"".
func step(delta: float) -> StringName:
	intensity = move_toward(intensity, target, FOLLOW_RATE * maxf(delta, 0.0))
	peak = maxf(peak, intensity)
	if not frozen and peak >= PEAK and intensity < CLEAR and target < CLEAR:
		peak = intensity
		return PASSED
	return &""


## The mission ended: whatever storm is up stays up (it keeps building if it
## was building, and never lifts, so it never "passes"). Only
## mission_started resets it.
func freeze() -> void:
	frozen = true


func is_final() -> bool:
	return frozen and maxf(intensity, target) >= FINAL_AT


func reset() -> void:
	intensity = 0.0
	target = 0.0
	peak = 0.0
	frozen = false
