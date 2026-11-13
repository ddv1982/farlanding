class_name HoldoutCues
extends RefCounted
## Pure rules for the Holdout mission's survival timer (Phase 8b): "hold the
## site until extraction". Unlike a deadline (Survey's storm, which fails the
## mission), the timer running out is the goal, so its cues sound like help
## arriving, never like doom.
##
## A survival timer is a known objective with `countdown_tick` >= 0 and
## `countdown_fails` false (SurviveObjective), still active. Stages by the
## seconds left on the soonest one:
##
## | stage | seconds left    | heard                                             |
## |-------|-----------------|---------------------------------------------------|
## | 0     | > LAYER_SECONDS | nothing                                           |
## | 1     | <= LAYER_SECONDS| the score's `holdout` layer comes in (-6 dB)      |
## | 2     | <= MINUTE       | `mus_holdout_minute` (a far engine, a horn call), |
## |       |                 | the holdout layer at full                         |
## | 3     | <= FINAL        | `mus_holdout_engine` loops on its own player,     |
## |       |                 | rising in level and pitch as it nears             |
##
## Arrival (`advisor_alert` &"extraction_arrived", or the survival objective
## completing, whichever comes first, once): `mus_holdout_arrived` (the
## engine's C# and G# lift into the Concord's D and A), the engine fades out
## over ENGINE_RELEASE, the holdout layer goes. Failing the objective stops it
## all without a resolution.

const MINUTE_CUE: StringName = &"mus_holdout_minute"
const ENGINE: StringName = &"mus_holdout_engine"
const ARRIVED: StringName = &"mus_holdout_arrived"
const ARRIVED_ALERT: StringName = &"extraction_arrived"

const LAYER_SECONDS: float = 120.0
const MINUTE: float = 60.0
const FINAL: float = 10.0
## The holdout layer's gain in stage 1 (dB); full (0 dB) from stage 2.
const LAYER_EARLY_DB: float = -6.0
## The engine's level and pitch with FINAL seconds left, and at zero.
const ENGINE_DB: Vector2 = Vector2(-14.0, 0.0)
const ENGINE_PITCH: Vector2 = Vector2(0.94, 1.0)
## Seconds for the engine to fade out once help has arrived.
const ENGINE_RELEASE: float = 0.8
## Seconds for the engine to fade in when the last stage starts.
const ENGINE_ATTACK: float = 0.4


## The stage for `seconds_left` (INF: no timer).
static func stage_for(seconds_left: float) -> int:
	if seconds_left <= FINAL:
		return 3
	if seconds_left <= MINUTE:
		return 2
	if seconds_left <= LAYER_SECONDS:
		return 1
	return 0


## The score's holdout layer gain (dB) at `stage`.
static func layer_gain_db(stage: int) -> float:
	if stage <= 0:
		return AudioMix.SILENT_DB
	return LAYER_EARLY_DB if stage == 1 else 0.0


## 0 with FINAL seconds left .. 1 at zero.
static func approach(seconds_left: float) -> float:
	return 1.0 - clampf(seconds_left / FINAL, 0.0, 1.0)


static func engine_db(seconds_left: float) -> float:
	return lerpf(ENGINE_DB.x, ENGINE_DB.y, approach(seconds_left))


static func engine_pitch(seconds_left: float) -> float:
	return lerpf(ENGINE_PITCH.x, ENGINE_PITCH.y, approach(seconds_left))


## True for a known, active objective whose countdown is survival, not failure.
static func is_survival(objective: Object) -> bool:
	if objective == null or not is_instance_valid(objective):
		return false
	var tick: Variant = objective.get(&"countdown_tick")
	if not tick is int:
		return false
	var due: int = tick
	if due < 0:
		return false
	var fails: Variant = objective.get(&"countdown_fails")
	if not (fails is bool) or fails:
		return false
	var state: Variant = objective.get(&"state")
	var text: String = str(state) if state != null else ""
	return text == "" or text == "active"
