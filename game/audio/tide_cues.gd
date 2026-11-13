class_name TideCues
extends RefCounted
## Pure rules for the Thalassa tide (Phase 8a). The TideSound node feeds it
## `Events.tide_changed` levels (0 = low water, 1 = high water) and asks what to
## hear; nothing here plays anything.
##
## Static mapping, level -> sound:
## - The water bed is two loops crossfaded with equal power: dark, distant water
##   at low water, bright close lapping at high water (that is the bed's
##   brightness), the whole bed rising from -9 dB at low water to 0 dB at high.
## - Motion: the rate the heard level moves at (level per second, smoothed over
##   MOTION_SMOOTH) brings in the rising rush while it climbs and the draining,
##   pebbly pull while it falls, from MOTION_FROM, full at MOTION_FULL. A still
##   sea (slack water) has neither.
## - The score's tide layer: silent below 0.15, then rising to -2 dB at 0.9.
## - tide_turning plays a warning: TURN_RISING (three bell tones going up,
##   short-short-long) or TURN_FALLING (going down, long-short-long).
##
## Stateful part (one instance per mission): the heard level follows reports at
## FOLLOW_RATE at most, so a jump in the reports glides. The first report after
## a reset is where the sea already is (a fresh landing at low water, or a
## restored one mid-tide): the level takes it at once, without motion, and the
## whole tide sound fades in over ARRIVE seconds, so a loaded save picks up
## mid-level without a jump cut and without a false rush. Until a first report
## the tide is silent: a planet without a tide never hears it.

const LOW: StringName = &"low"
const HIGH: StringName = &"high"
const RUSH: StringName = &"rush"
const PULL: StringName = &"pull"
const LAYERS: Array[StringName] = [LOW, HIGH, RUSH, PULL]
## Layer -> SoundEvent whose first stream is the layer's loop.
const LAYER_EVENTS: Dictionary[StringName, StringName] = {
	LOW: &"amb_tide_low",
	HIGH: &"amb_tide_high",
	RUSH: &"amb_tide_rush",
	PULL: &"amb_tide_pull",
}
const TURN_RISING: StringName = &"tide_turn_rising"
const TURN_FALLING: StringName = &"tide_turn_falling"

## The water bed's level at low water and at high water (dB).
const WATER_DB: Vector2 = Vector2(-9.0, 0.0)
## Rush and pull: level speed (per second) where they start and where they are full.
const MOTION_FROM: float = 0.002
const MOTION_FULL: float = 0.012
## Their level when full (dB): under the water bed.
const MOTION_TOP_DB: float = -2.0
## Seconds over which the motion is averaged (reports come a few times a second).
const MOTION_SMOOTH: float = 1.5
## How fast the heard level may follow the reported one (per second).
const FOLLOW_RATE: float = 0.25
## Seconds for the whole tide sound to fade in after a reset.
const ARRIVE: float = 3.0
const MUSIC_RANGE: Vector2 = Vector2(0.15, 0.9)
const MUSIC_FLOOR_DB: float = -14.0
const MUSIC_TOP_DB: float = -2.0
## The score's layer gain moves in steps this big (dB), so a slow tide does not
## ask the MusicDirector for a new fade every frame.
const MUSIC_STEP_DB: float = 0.5

## Heard level (0..1), reported target, smoothed speed (per second), presence
## (0..1: the arrival fade).
var level: float = 0.0
var target: float = 0.0
var speed: float = 0.0
var presence: float = 0.0
## True once a report arrived since the last reset.
var primed: bool = false


## 0..1 smoothstep of `value` across `span`.
static func ramp(value: float, span: Vector2) -> float:
	return StormCues.ramp(value, span)


## Volume (dB) of a water layer (LOW or HIGH) at `value` (AudioMix.SILENT_DB when silent).
static func water_db(layer: StringName, value: float) -> float:
	var v: float = clampf(value, 0.0, 1.0)
	var weight: float = cos(v * PI * 0.5) if layer == LOW else sin(v * PI * 0.5)
	if weight <= 0.0001:
		return AudioMix.SILENT_DB
	return AudioMix.linear_to_db_safe(weight) + lerpf(WATER_DB.x, WATER_DB.y, v)


## Volume (dB) of RUSH or PULL at speed `rate` (per second; positive = rising).
static func motion_db(layer: StringName, rate: float) -> float:
	var directed: float = rate if layer == RUSH else -rate
	var amount: float = ramp(directed, Vector2(MOTION_FROM, MOTION_FULL))
	if amount <= 0.0:
		return AudioMix.SILENT_DB
	return AudioMix.linear_to_db_safe(sqrt(amount)) + MOTION_TOP_DB


## Volume (dB) of any layer for a level, speed and presence.
static func layer_db(layer: StringName, value: float, rate: float, arrive: float) -> float:
	var base: float = motion_db(layer, rate) if layer in [RUSH, PULL] else water_db(layer, value)
	if base <= AudioMix.SILENT_DB or arrive <= 0.0:
		return AudioMix.SILENT_DB
	return maxf(base + AudioMix.linear_to_db_safe(arrive), AudioMix.SILENT_DB)


## Gain (dB) for the score's tide layer at `value`, in MUSIC_STEP_DB steps.
static func music_gain_db(value: float) -> float:
	if value < MUSIC_RANGE.x:
		return AudioMix.SILENT_DB
	var db: float = lerpf(MUSIC_FLOOR_DB, MUSIC_TOP_DB, ramp(value, MUSIC_RANGE))
	return snappedf(db, MUSIC_STEP_DB)


## The warning for a turn: rising or falling.
static func turn_cue(rising: bool) -> StringName:
	return TURN_RISING if rising else TURN_FALLING


# --- State ------------------------------------------------------------------------


## A new report from the tide. The first after a reset is taken at once.
func report(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	target = clamped
	if not primed:
		primed = true
		level = clamped
		speed = 0.0


## Moves the heard level toward the reported one and updates speed and presence.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	var before: float = level
	level = move_toward(level, target, FOLLOW_RATE * delta)
	var now_speed: float = (level - before) / delta
	speed += (now_speed - speed) * (1.0 - exp(-delta / MOTION_SMOOTH))
	presence = move_toward(presence, 1.0 if primed else 0.0, delta / ARRIVE)


func reset() -> void:
	level = 0.0
	target = 0.0
	speed = 0.0
	presence = 0.0
	primed = false
