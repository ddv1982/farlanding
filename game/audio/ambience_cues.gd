class_name AmbienceCues
extends RefCounted
## Pure rules for a planet's ambience (Phase 6; data-driven since Phase 8a).
## The AmbienceDirector measures where the listener is (how near a Flux vent, a
## Combine base the player has seen, an Antecedent site; how strong the storm
## is; how high the tide) and asks these rules what to play. The planet's beds
## and details are data (AmbienceSet); without a set the rules use Kessel
## Reach's. Nothing here plays anything.
##
## Beds loop together at different lengths and never line up the same way
## twice; each wanders slowly to a new level every 7-15 s within its own range.
## Near an Antecedent site a hush bed rises (up to 0 dB) and the other beds and
## the details step back: the place is still. The storm covers all of it
## (StormSound's `cover`); the tide moves each bed between its low- and
## high-water level (TideSound).
##
## Details: one positional one-shot every 6-14 s (longer under the hush, much
## longer in a storm), picked by weight from what is near (AmbienceDetail). The
## same kind never plays twice in a row when another is possible.
##
## Kessel Reach: the base wind (-5..0 dB), a high air bed (-9..-1 dB) and the
## hush; settling rock always, dust devils in clear weather, Flux vents near
## Flux, far Combine industry near a base the player has seen.

const ROCK: StringName = &"amb_rock_settle"
const VENT: StringName = &"amb_flux_vent"
const DEVIL: StringName = &"amb_dust_devil"
const INDUSTRY: StringName = &"amb_combine_industry"

const BED_WIND: StringName = &"amb_kessel_wind"
const BED_AIR: StringName = &"amb_kessel_air"
const BED_HUSH: StringName = &"amb_kessel_hush"
## Kessel Reach's set: the one used when nothing names another.
const KESSEL_SET: String = "res://data/sounds/ambience/sets/kessel_reach.tres"
## Seconds between new wander targets, and the glide to each.
const WANDER_GAP: Vector2 = Vector2(7.0, 15.0)
const WANDER_GLIDE: float = 8.0
## Detail gap range (s) in clear air away from anything.
const DETAIL_GAP: Vector2 = Vector2(6.0, 14.0)
## Near radii (m): fully near inside x, not near beyond y.
const NEAR_VENT: Vector2 = Vector2(10.0, 60.0)
const NEAR_BASE: Vector2 = Vector2(40.0, 140.0)
const NEAR_SITE: Vector2 = Vector2(15.0, 70.0)
## Ring around the listener where free details (rock, devils) land (m).
const DETAIL_RING: Vector2 = Vector2(14.0, 55.0)
const HUSH_FLOOR_DB: float = -30.0

## Context keys.
const VENT_NEAR: StringName = &"vent"
const BASE_NEAR: StringName = &"base"
const SITE_NEAR: StringName = &"site"
const STORM: StringName = &"storm"
## The water level, 0 low .. 1 high (0 on planets without a tide).
const TIDE: StringName = &"tide"
const CONTEXT_KEYS: Array[StringName] = [VENT_NEAR, BASE_NEAR, SITE_NEAR, STORM, TIDE]

static var _kessel: AmbienceSet


## Kessel Reach's set (loaded once).
static func kessel() -> AmbienceSet:
	if _kessel == null:
		_kessel = load(KESSEL_SET) as AmbienceSet
	return _kessel


## 1 inside `radii.x`, 0 beyond `radii.y`, smooth between.
static func nearness(distance: float, radii: Vector2) -> float:
	if distance == INF:
		return 0.0
	var u: float = clampf((distance - radii.x) / maxf(radii.y - radii.x, 0.001), 0.0, 1.0)
	return 1.0 - u * u * (3.0 - 2.0 * u)


## Weight of each detail kind of `amb` (Kessel's when null) in a context (the
## CONTEXT_KEYS, each 0..1; missing keys are 0). In the set's detail order.
static func detail_weights(
	context: Dictionary, amb: AmbienceSet = null
) -> Dictionary[StringName, float]:
	var vent: float = context.get(VENT_NEAR, 0.0)
	var base: float = context.get(BASE_NEAR, 0.0)
	var site: float = context.get(SITE_NEAR, 0.0)
	var storm: float = context.get(STORM, 0.0)
	var tide: float = context.get(TIDE, 0.0)
	var calm: float = 1.0 - 0.75 * site
	var out: Dictionary[StringName, float] = {}
	for detail: AmbienceDetail in _or_kessel(amb).details:
		var weight: float = (
			detail.weight
			+ detail.vent * vent
			+ detail.base * base
			+ detail.flood * tide
			+ detail.ebb * (1.0 - tide)
		)
		out[detail.event] = maxf(weight, 0.0) * (1.0 - storm * detail.storm_cover) * calm
	return out


## Picks a kind by weight with `roll` in [0, 1), avoiding `last` while any
## other kind has weight. Returns &"" when nothing has weight. Kinds are
## considered in the order of `weights`.
static func pick(
	weights: Dictionary[StringName, float], roll: float, last: StringName
) -> StringName:
	var candidates: Array[StringName] = []
	for kind: StringName in weights:
		if kind != last and weights[kind] > 0.0:
			candidates.append(kind)
	if candidates.is_empty() and weights.get(last, 0.0) > 0.0:
		candidates.append(last)
	var total: float = 0.0
	for kind: StringName in candidates:
		total += weights[kind]
	var at: float = clampf(roll, 0.0, 0.9999) * total
	for kind: StringName in candidates:
		if at < weights[kind]:
			return kind
		at -= weights[kind]
	if candidates.is_empty():
		return &""
	var fallback: StringName = candidates[candidates.size() - 1]
	return fallback


## Seconds to the next detail. `roll` in [0, 1).
static func detail_gap(context: Dictionary, roll: float) -> float:
	var site: float = context.get(SITE_NEAR, 0.0)
	var storm: float = context.get(STORM, 0.0)
	var gap: float = lerpf(DETAIL_GAP.x, DETAIL_GAP.y, clampf(roll, 0.0, 1.0))
	return gap * (1.0 + site) * (1.0 + 3.0 * storm)


## A new wander target (dB) for a bed of `amb`. `roll` in [0, 1).
static func wander_target_db(bed: StringName, roll: float, amb: AmbienceSet = null) -> float:
	var found: AmbienceBed = _or_kessel(amb).find_bed(bed)
	var range_db: Vector2 = found.wander_db if found != null else Vector2.ZERO
	return lerpf(range_db.x, range_db.y, clampf(roll, 0.0, 1.0))


static func wander_gap(roll: float) -> float:
	return lerpf(WANDER_GAP.x, WANDER_GAP.y, clampf(roll, 0.0, 1.0))


## Level (dB) of a bed from its wander level and the context: a hush bed rises
## near a site, the others step back there and follow the tide, the storm
## covers them all.
static func bed_db(
	bed: StringName, wander_db: float, context: Dictionary, amb: AmbienceSet = null
) -> float:
	var site: float = context.get(SITE_NEAR, 0.0)
	var storm: float = context.get(STORM, 0.0)
	var tide: float = context.get(TIDE, 0.0)
	var cover: float = AudioMix.linear_to_db_safe(1.0 - 0.85 * clampf(storm, 0.0, 1.0))
	var found: AmbienceBed = _or_kessel(amb).find_bed(bed)
	if found != null and found.hush:
		if site <= 0.0:
			return AudioMix.SILENT_DB
		return lerpf(HUSH_FLOOR_DB, 0.0, site) + cover
	var tide_db: float = 0.0
	if found != null:
		tide_db = lerpf(found.tide_db.x, found.tide_db.y, clampf(tide, 0.0, 1.0))
	return wander_db - 6.0 * site + cover + tide_db


static func _or_kessel(amb: AmbienceSet) -> AmbienceSet:
	if amb != null:
		return amb
	var fallback: AmbienceSet = kessel()
	return fallback if fallback != null else AmbienceSet.new()
