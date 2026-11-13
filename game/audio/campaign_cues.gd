class_name CampaignCues
extends RefCounted
## Pure rules for the campaign layer (Phase 7): aboard the Meridian between
## landings. Nothing here plays anything; the CampaignSoundRouter asks.
##
## Screens -> music: the ship score (`res://data/sounds/music/meridian.tres`)
## has one state per screen (title, star_map, meridian, tech_web, loadout); an
## unknown screen name plays the star map's state. &"" is a landing (briefing,
## mission, debrief): the planet's score and ambience take over.
##
## Hovers: sweeping the mouse over the map or the web sends a hover per node.
## Two hovers never start closer than HOVER_GAP; once HOVER_BURST hovers have
## come within HOVER_WINDOW, the gap widens to HOVER_BURST_GAP and they play
## HOVER_BURST_DB quieter, so a sweep sparkles instead of machine-gunning.
##
## Saves: autosaves (a slot whose name contains "auto") confirm at most once
## per AUTOSAVE_GAP; other saves (the player asked) at most once per SAVE_GAP.
##
## Return phrase: a landing's result is voiced by the ship
## (`advisor_campaign_return_won` / `_lost`) on the first ship screen after
## `landing_resolved`, unless a mission-ending sting played less than
## RETURN_QUIET seconds before: the player has just heard the verdict.
##
## Tech: `tech_buy` (the click) already carries the seal; `tech_unlocked`
## alone (a tech granted without a purchase click) plays the seal by itself,
## and only if no tech_buy came within TECH_PAIR_WINDOW either side of it.

const TITLE: StringName = &"title"
const STAR_MAP: StringName = &"star_map"
const MERIDIAN: StringName = &"meridian"
const TECH_WEB: StringName = &"tech_web"
const LOADOUT: StringName = &"loadout"
const SCREENS: Array[StringName] = [TITLE, STAR_MAP, MERIDIAN, TECH_WEB, LOADOUT]

## Ship beds (on the AmbienceDirector's own players) and details (flat).
const BED_HUM: StringName = &"amb_ship_hum"
const BED_AIR: StringName = &"amb_ship_air"
const BEDS: Array[StringName] = [BED_HUM, BED_AIR]
## Bed -> range its level wanders in (dB).
const BED_RANGE_DB: Dictionary[StringName, Vector2] = {
	BED_HUM: Vector2(-3.0, 0.0),
	BED_AIR: Vector2(-7.0, -1.0),
}
## On the title screen the ship is further away: the beds sit lower.
const TITLE_BED_DB: float = -6.0
const RELAY: StringName = &"amb_ship_relay"
const CREAK: StringName = &"amb_ship_creak"
const MACHINE: StringName = &"amb_ship_machine"
const PING: StringName = &"amb_ship_ping"
const DETAILS: Array[StringName] = [RELAY, CREAK, MACHINE, PING]
const DETAIL_WEIGHTS: Dictionary[StringName, float] = {
	RELAY: 1.0,
	CREAK: 0.7,
	MACHINE: 0.6,
	PING: 0.5,
}
## Seconds between ship details (and longer on the title screen).
const DETAIL_GAP: Vector2 = Vector2(5.0, 12.0)
const TITLE_GAP_SCALE: float = 2.0

const HOVER_GAP: float = 0.07
const HOVER_WINDOW: float = 0.6
const HOVER_BURST: int = 4
const HOVER_BURST_GAP: float = 0.16
const HOVER_BURST_DB: float = -5.0
## Returned by `hover` when this hover stays silent.
const SKIP: float = -INF

const SAVE_GAP: float = 2.0
const AUTOSAVE_GAP: float = 60.0
const RETURN_QUIET: float = 10.0
const TECH_PAIR_WINDOW: float = 0.5

var _hovers: PackedFloat64Array = []
var _last_hover: float = -INF
var _last_save: float = -INF
var _last_autosave: float = -INF


static func is_ship_screen(screen: StringName) -> bool:
	return screen != &""


## The ship score's state for a screen.
static func music_state(screen: StringName) -> StringName:
	return screen if screen in SCREENS else STAR_MAP


static func return_kind(won: bool) -> StringName:
	return &"campaign_return_won" if won else &"campaign_return_lost"


## Whether the return phrase should play at `now`, given when the last
## mission-ending sting played (-INF if none).
static func return_allowed(now: float, last_ending_sting: float) -> bool:
	return now - last_ending_sting >= RETURN_QUIET


## Seconds to the next ship detail. `roll` in [0, 1).
static func detail_gap(roll: float, screen: StringName) -> float:
	var gap: float = lerpf(DETAIL_GAP.x, DETAIL_GAP.y, clampf(roll, 0.0, 1.0))
	return gap * (TITLE_GAP_SCALE if screen == TITLE else 1.0)


## A detail by weight with `roll` in [0, 1), never `last` twice running.
static func pick_detail(roll: float, last: StringName) -> StringName:
	var total: float = 0.0
	for kind: StringName in DETAILS:
		if kind != last:
			total += DETAIL_WEIGHTS[kind]
	var at: float = clampf(roll, 0.0, 0.9999) * total
	for kind: StringName in DETAILS:
		if kind == last:
			continue
		if at < DETAIL_WEIGHTS[kind]:
			return kind
		at -= DETAIL_WEIGHTS[kind]
	return RELAY if last != RELAY else CREAK


static func wander_target_db(bed: StringName, roll: float) -> float:
	var range_db: Vector2 = BED_RANGE_DB.get(bed, Vector2.ZERO)
	return lerpf(range_db.x, range_db.y, clampf(roll, 0.0, 1.0))


## A hover at `now`: the volume offset (dB) to play it at, or SKIP.
func hover(now: float) -> float:
	var kept: PackedFloat64Array = []
	for at: float in _hovers:
		if now - at < HOVER_WINDOW:
			kept.append(at)
	_hovers = kept
	var burst: bool = _hovers.size() >= HOVER_BURST
	var gap: float = HOVER_BURST_GAP if burst else HOVER_GAP
	_hovers.append(now)
	if now - _last_hover < gap:
		return SKIP
	_last_hover = now
	return HOVER_BURST_DB if burst else 0.0


## Whether a save of `slot` at `now` is confirmed (and, if so, it is noted).
func save_allowed(slot: StringName, now: float) -> bool:
	var auto: bool = String(slot).to_lower().contains("auto")
	var last: float = _last_autosave if auto else _last_save
	if now - last < (AUTOSAVE_GAP if auto else SAVE_GAP):
		return false
	if auto:
		_last_autosave = now
	else:
		_last_save = now
	return true
