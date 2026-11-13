class_name EruptionCues
extends RefCounted
## Pure rules for Emberfall's eruptions (Phase 8b). The EruptionSound node feeds
## it what gameplay reports (`Events.eruption_warning(vent, seconds, radius)`,
## `Events.eruption(vent, radius)`) and asks what to hear; nothing here plays.
##
## The build-up is heard as a clock. Everything about it is a function of the
## seconds left, never of how long the warning was, so the same moment always
## sounds the same (a restored mission that re-emits a warning half-way picks
## up exactly where the sound was):
## - Pitch: both build loops play from PITCH.x with BUILD_SPAN seconds or more
##   left to PITCH.y at the eruption, in equal steps per second (exponential).
## - Brightness: the deep growl (BUILD_LOW) crossfades with equal power into the
##   pressurised hiss and whistle (BUILD_HIGH) over the same span.
## - Level: LEVEL_DB.x with FAR_SPAN or more seconds left, LEVEL_DB.y at
##   BUILD_SPAN, 0 dB at the eruption.
## - Knocks (KNOCK, a rock knock and a burp of gas) come every
##   `seconds_left * KNOCK_RATIO` seconds (within KNOCK_GAP): about 7 per second
##   divided by the seconds left, so a player who counts them knows how long
##   remains (one every 1.5 s: ten seconds; a rattle: one or two).
##
## Several vents at once never stack into noise: at most MAX_BUILDS build-ups
## sound (ranked by `weight`: the largest radius over the nearest distance),
## at most MAX_BLASTS blasts ring at a time (a new one replaces the weakest
## only if it weighs more). A vent the player cannot see is quieter
## (UNSEEN_DB) and duller (UNSEEN_CUTOFF_HZ), never silent.
##
## The score's pressure layer follows the most pressing vent near the player's
## base (`music_gain_db` of its progress): silent below MUSIC_RANGE.x.

const BUILD_LOW: StringName = &"eruption_build_low"
const BUILD_HIGH: StringName = &"eruption_build_high"
const KNOCK: StringName = &"eruption_knock"
const BLAST: StringName = &"eruption_blast"
## The two build loops, in the order a slot's players hold them.
const LAYERS: Array[StringName] = [BUILD_LOW, BUILD_HIGH]

## Seconds over which pitch, brightness and most of the level rise.
const BUILD_SPAN: float = 30.0
## Further out than this the build-up sits at LEVEL_DB.x.
const FAR_SPAN: float = 60.0
## Playback pitch with BUILD_SPAN seconds or more left, and at the eruption.
const PITCH: Vector2 = Vector2(0.65, 1.7)
## Build level (dB) with FAR_SPAN and with BUILD_SPAN seconds left (0 dB at 0).
const LEVEL_DB: Vector2 = Vector2(-18.0, -12.0)
const KNOCK_RATIO: float = 0.15
const KNOCK_GAP: Vector2 = Vector2(0.12, 2.5)
## Seconds for a new (or restored) build-up to fade in.
const ARRIVE: float = 1.5
## A warning whose deadline passed this long ago without an eruption is dropped.
const OVERDUE: float = 2.0
const MAX_BUILDS: int = 2
const MAX_BLASTS: int = 2
## Distances closer than this weigh the same (m).
const MIN_DISTANCE: float = 8.0
## A vent the player cannot see: this much quieter, and this dull (Hz).
const UNSEEN_DB: float = -8.0
const UNSEEN_CUTOFF_HZ: float = 900.0
## The positional players' own distance filter when the vent is seen (Godot's default).
const SEEN_CUTOFF_HZ: float = 5000.0
## Blast level (dB) for a radius of RADIUS_SPAN.x and of RADIUS_SPAN.y metres.
const BLAST_DB: Vector2 = Vector2(-3.0, 2.0)
const RADIUS_SPAN: Vector2 = Vector2(6.0, 26.0)
## A seen blast ducks the mix (BusDucker) for this long; not twice within MIN_DUCK_GAP.
const DUCK_HOLD: float = 0.9
const MIN_DUCK_GAP: float = 1.5
## A vent counts as near the player's base within its radius plus this (m).
const BASE_MARGIN: float = 25.0
const MUSIC_RANGE: Vector2 = Vector2(0.1, 0.9)
const MUSIC_FLOOR_DB: float = -14.0
const MUSIC_TOP_DB: float = -2.0
const MUSIC_STEP_DB: float = 0.5


## 0 with BUILD_SPAN or more seconds left .. 1 at the eruption.
static func progress(seconds_left: float) -> float:
	return 1.0 - clampf(seconds_left / BUILD_SPAN, 0.0, 1.0)


## Playback pitch of the build loops with `seconds_left`.
static func pitch(seconds_left: float) -> float:
	return PITCH.x * pow(PITCH.y / PITCH.x, progress(seconds_left))


## Overall build level (dB) with `seconds_left`, before arrival and visibility.
static func level_db(seconds_left: float) -> float:
	var s: float = maxf(seconds_left, 0.0)
	if s >= BUILD_SPAN:
		return lerpf(
			LEVEL_DB.y, LEVEL_DB.x, clampf((s - BUILD_SPAN) / (FAR_SPAN - BUILD_SPAN), 0.0, 1.0)
		)
	return lerpf(0.0, LEVEL_DB.y, s / BUILD_SPAN)


## Volume (dB) of one build loop with `seconds_left`, `presence` (0..1, the
## arrival fade) and visibility. AudioMix.SILENT_DB when silent.
static func layer_db(layer: StringName, seconds_left: float, presence: float, seen: bool) -> float:
	var p: float = progress(seconds_left)
	var weight: float = cos(p * PI * 0.5) if layer == BUILD_LOW else sin(p * PI * 0.5)
	if weight <= 0.0001 or presence <= 0.0:
		return AudioMix.SILENT_DB
	var db: float = AudioMix.linear_to_db_safe(weight) + level_db(seconds_left)
	db += AudioMix.linear_to_db_safe(presence) + (0.0 if seen else UNSEEN_DB)
	return maxf(db, AudioMix.SILENT_DB)


## Seconds to the next knock with `seconds_left`.
static func knock_gap(seconds_left: float) -> float:
	return clampf(seconds_left * KNOCK_RATIO, KNOCK_GAP.x, KNOCK_GAP.y)


## How much a vent matters to the listener: its radius over its distance.
static func weight(radius: float, distance: float) -> float:
	return maxf(radius, 0.1) / maxf(distance, MIN_DISTANCE)


## Blast level (dB) for an eruption of `radius` metres.
static func blast_db(radius: float, seen: bool) -> float:
	var t: float = clampf((radius - RADIUS_SPAN.x) / (RADIUS_SPAN.y - RADIUS_SPAN.x), 0.0, 1.0)
	return lerpf(BLAST_DB.x, BLAST_DB.y, t) + (0.0 if seen else UNSEEN_DB)


static func cutoff_hz(seen: bool) -> float:
	return SEEN_CUTOFF_HZ if seen else UNSEEN_CUTOFF_HZ


## Gain (dB) for the score's pressure layer at `amount` (0..1), in MUSIC_STEP_DB steps.
static func music_gain_db(amount: float) -> float:
	if amount < MUSIC_RANGE.x:
		return AudioMix.SILENT_DB
	var db: float = lerpf(MUSIC_FLOOR_DB, MUSIC_TOP_DB, StormCues.ramp(amount, MUSIC_RANGE))
	return snappedf(db, MUSIC_STEP_DB)


## The indices of the `count` heaviest of `weights`, heaviest first (ties: the
## earlier one).
static func strongest(weights: PackedFloat32Array, count: int) -> PackedInt32Array:
	var order: Array[int] = []
	for i: int in weights.size():
		order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return weights[a] > weights[b] or (weights[a] == weights[b] and a < b)
	)
	var out: PackedInt32Array = []
	for i: int in mini(count, order.size()):
		out.append(order[i])
	return out
