class_name AmbienceCues
extends RefCounted
## Pure rules for the Kessel Reach ambience (Phase 6). The AmbienceDirector
## measures where the listener is (how near a Flux vent, a Combine base the
## player has seen, an Antecedent site; how strong the storm is) and asks
## these rules what to play. Nothing here plays anything.
##
## Beds: the base wind (48 s) and a high air bed (37 s) loop together and never
## line up the same way twice; each wanders slowly to a new level every 7-15 s
## (wind -5..0 dB, air -9..-1 dB). Near an Antecedent site the hush bed rises
## (up to 0 dB) and the wind and the details step back: the place is still.
## The storm covers all of it (StormSound's `cover`).
##
## Details: one positional one-shot every 6-14 s (longer under the hush, much
## longer in a storm), picked by weight from what is near: settling rock
## always, dust devils in clear weather, Flux vents near Flux, far Combine
## industry near a base the player has seen. The same kind never plays twice
## in a row when another is possible.

const ROCK: StringName = &"amb_rock_settle"
const VENT: StringName = &"amb_flux_vent"
const DEVIL: StringName = &"amb_dust_devil"
const INDUSTRY: StringName = &"amb_combine_industry"
const DETAILS: Array[StringName] = [ROCK, VENT, DEVIL, INDUSTRY]

const BED_WIND: StringName = &"amb_kessel_wind"
const BED_AIR: StringName = &"amb_kessel_air"
const BED_HUSH: StringName = &"amb_kessel_hush"
const BEDS: Array[StringName] = [BED_WIND, BED_AIR, BED_HUSH]
## Bed -> range its level wanders in (dB). The hush does not wander.
const BED_RANGE_DB: Dictionary[StringName, Vector2] = {
	BED_WIND: Vector2(-5.0, 0.0),
	BED_AIR: Vector2(-9.0, -1.0),
}
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


## 1 inside `radii.x`, 0 beyond `radii.y`, smooth between.
static func nearness(distance: float, radii: Vector2) -> float:
	if distance == INF:
		return 0.0
	var u: float = clampf((distance - radii.x) / maxf(radii.y - radii.x, 0.001), 0.0, 1.0)
	return 1.0 - u * u * (3.0 - 2.0 * u)


## Weight of each detail kind in a context (keys VENT_NEAR, BASE_NEAR,
## SITE_NEAR, STORM, each 0..1; missing keys are 0).
static func detail_weights(context: Dictionary) -> Dictionary[StringName, float]:
	var vent: float = context.get(VENT_NEAR, 0.0)
	var base: float = context.get(BASE_NEAR, 0.0)
	var site: float = context.get(SITE_NEAR, 0.0)
	var storm: float = context.get(STORM, 0.0)
	var calm: float = 1.0 - 0.75 * site
	return {
		ROCK: 1.0 * calm,
		DEVIL: 0.45 * (1.0 - storm) * calm,
		VENT: (0.08 + 2.2 * vent) * calm,
		INDUSTRY: 2.6 * base * calm,
	}


## Picks a kind by weight with `roll` in [0, 1), avoiding `last` while any
## other kind has weight. Returns &"" when nothing has weight.
static func pick(
	weights: Dictionary[StringName, float], roll: float, last: StringName
) -> StringName:
	var candidates: Array[StringName] = []
	for kind: StringName in DETAILS:
		if kind != last and weights.get(kind, 0.0) > 0.0:
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


## A new wander target (dB) for a bed. `roll` in [0, 1).
static func wander_target_db(bed: StringName, roll: float) -> float:
	var range_db: Vector2 = BED_RANGE_DB.get(bed, Vector2.ZERO)
	return lerpf(range_db.x, range_db.y, clampf(roll, 0.0, 1.0))


static func wander_gap(roll: float) -> float:
	return lerpf(WANDER_GAP.x, WANDER_GAP.y, clampf(roll, 0.0, 1.0))


## Level (dB) of a bed from its wander level and the context: the hush rises
## near a site, the wind and air step back there, the storm covers all three.
static func bed_db(bed: StringName, wander_db: float, context: Dictionary) -> float:
	var site: float = context.get(SITE_NEAR, 0.0)
	var storm: float = context.get(STORM, 0.0)
	var cover: float = AudioMix.linear_to_db_safe(1.0 - 0.85 * clampf(storm, 0.0, 1.0))
	if bed == BED_HUSH:
		if site <= 0.0:
			return AudioMix.SILENT_DB
		return lerpf(HUSH_FLOOR_DB, 0.0, site) + cover
	return wander_db - 6.0 * site + cover
