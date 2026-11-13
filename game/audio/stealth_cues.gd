class_name StealthCues
extends RefCounted
## Pure rules for the stealth sounds (Phase 5). Every input is read duck-typed
## with a safe fallback, so stub nodes work whether or not the gameplay classes
## exist yet.
##
## Watchers expose `suspicion: float` (0..1), `is_alerted: bool` and
## `is_visible_to_player: bool`; stealthy units expose `is_cloaked: bool`.
## Alert levels are &"unaware", &"suspicious", &"alerted"; the loudest level
## over all watching factions is what the player hears.

const UNAWARE: StringName = &"unaware"
const SUSPICIOUS: StringName = &"suspicious"
const ALERTED: StringName = &"alerted"

const SUSPICION_LOOP: StringName = &"stealth_suspicion"
const SPOTTED: StringName = &"stealth_spotted"
const ALERT_SUSPICIOUS: StringName = &"stealth_alert_suspicious"
const ALERT_ALARM: StringName = &"stealth_alert_alarm"
const ALL_CLEAR: StringName = &"stealth_all_clear"
const CLOAK_ENGAGE: StringName = &"stealth_cloak_engage"
const CLOAK_DISENGAGE: StringName = &"stealth_cloak_disengage"

## Music states (in the planet's MusicScore) for each alert level.
const MUSIC_UNAWARE: StringName = &"stealth_unaware"
const MUSIC_SUSPICIOUS: StringName = &"stealth_suspicious"
const MUSIC_ALERTED: StringName = &"stealth_alerted"

## A watcher whose suspicion property is missing counts as this suspicious.
const DEFAULT_SUSPICION: float = 0.5
## Watchers below this suspicion make no tone.
const MIN_SUSPICION: float = 0.02
## How much distance (as a share of the tone's range) costs against suspicion
## when ranking watchers: a fully suspicious watcher at the edge of hearing
## still ranks with a half-suspicious one at the listener.
const DISTANCE_WEIGHT: float = 0.5
## Suspicion tone level and pitch, from barely noticed (0) to certain (1).
const TONE_DB: Vector2 = Vector2(-14.0, 0.0)
const TONE_PITCH: Vector2 = Vector2(0.85, 1.3)


static func rank_of(level: StringName) -> int:
	match level:
		ALERTED:
			return 2
		SUSPICIOUS:
			return 1
	return 0


## The more alarmed of two levels.
static func louder(a: StringName, b: StringName) -> StringName:
	return a if rank_of(a) >= rank_of(b) else b


## Stingers for the player-facing alert level moving from `previous` to `level`.
## Rising to Suspicious queries, rising to Alerted sounds the alarm, falling
## back to Unaware is the all-clear. Alerted decaying to Suspicious is left to
## the music.
static func alert_events(level: StringName, previous: StringName) -> Array[StringName]:
	var events: Array[StringName] = []
	var now_rank: int = rank_of(level)
	var before: int = rank_of(previous)
	if now_rank == before:
		return events
	if now_rank == 2:
		events.append(ALERT_ALARM)
	elif now_rank == 1 and before == 0:
		events.append(ALERT_SUSPICIOUS)
	elif now_rank == 0:
		events.append(ALL_CLEAR)
	return events


static func music_state_for(level: StringName) -> StringName:
	match rank_of(level):
		2:
			return MUSIC_ALERTED
		1:
			return MUSIC_SUSPICIOUS
	return MUSIC_UNAWARE


## The watcher's suspicion in 0..1 (DEFAULT_SUSPICION if it has none).
static func suspicion_of(node: Object) -> float:
	if node == null or not is_instance_valid(node):
		return 0.0
	var value: Variant = node.get(&"suspicion")
	if value is float or value is int:
		var suspicion: float = value
		return clampf(suspicion, 0.0, 1.0)
	return DEFAULT_SUSPICION


## A bool property, or `fallback` when the node has none.
static func flag(node: Object, property: StringName, fallback: bool) -> bool:
	if node == null or not is_instance_valid(node):
		return fallback
	var value: Variant = node.get(property)
	if value is bool:
		var result: bool = value
		return result
	return fallback


## True if the node says it is cloaked; null when it has no such property.
static func cloak_state(node: Object) -> Variant:
	if node == null or not is_instance_valid(node):
		return null
	var value: Variant = node.get(&"is_cloaked")
	return value if value is bool else null


## Volume offset (dB) and pitch scale of a suspicion tone.
static func tone_db(suspicion: float) -> float:
	return lerpf(TONE_DB.x, TONE_DB.y, clampf(suspicion, 0.0, 1.0))


static func tone_pitch(suspicion: float) -> float:
	return lerpf(TONE_PITCH.x, TONE_PITCH.y, clampf(suspicion, 0.0, 1.0))


## Which watchers get a suspicion tone: eligible ones within `max_distance`,
## ranked by suspicion minus DISTANCE_WEIGHT * distance / max_distance (ties:
## nearer first), at most `cap`. Returns indices, best first.
static func pick_tones(
	suspicions: PackedFloat32Array,
	distances: PackedFloat32Array,
	eligible: Array[bool],
	cap: int,
	max_distance: float,
) -> PackedInt32Array:
	var order: Array[int] = []
	var scores: Dictionary[int, float] = {}
	for i: int in suspicions.size():
		if not eligible[i] or suspicions[i] < MIN_SUSPICION:
			continue
		if max_distance > 0.0 and distances[i] > max_distance:
			continue
		var reach: float = maxf(max_distance, 1.0)
		scores[i] = suspicions[i] - DISTANCE_WEIGHT * distances[i] / reach
		order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			if not is_equal_approx(scores[a], scores[b]):
				return scores[a] > scores[b]
			return distances[a] < distances[b]
	)
	var picked: PackedInt32Array = []
	for i: int in order:
		if picked.size() >= cap:
			break
		picked.append(i)
	return picked
