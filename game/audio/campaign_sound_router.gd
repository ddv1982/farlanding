class_name CampaignSoundRouter
extends Node
## Campaign events -> sounds (Phase 7): aboard the survey ship Meridian
## between landings. Listens to `Events`; gameplay never calls this. Rules in
## CampaignCues.
##
## - campaign_screen_changed(screen): a ship screen (title, star_map, meridian,
##   tech_web, loadout) asks the AudioService to be aboard (`show_screen`): the
##   ship score in that screen's state, the ship ambience, the ship mix. &""
##   (a landing takes over) hands back to the planet.
## - ui_feedback map_node_hover / tech_hover: `ui_<kind>` through the hover
##   limiter (the AudioEventRouter leaves these two kinds alone). Every other
##   campaign kind plays `ui_<kind>` by the naming rule there.
## - ui_feedback map_launch: besides its sound, the music starts handing over
##   to the landing at once (`launch`), so the briefing bed meets a quiet score.
## - tech_unlocked: the seal (`ui_tech_unlocked`) only when no tech_buy click
##   came with it (tech_buy already carries the seal).
## - landing_resolved(won): the ship's return phrase
##   (`advisor_campaign_return_won` / `_lost`, through the Advisor queue) on
##   the first ship screen after it, skipped if a mission-ending sting played
##   within CampaignCues.RETURN_QUIET (the debrief's verdict already spoke).
## - campaign_saved(slot): `ui_campaign_saved`, rate-limited (autosaves rarely).
## - campaign_loaded, mission_started: anything pending is dropped.

const HOVER_KINDS: Array[StringName] = [&"map_node_hover", &"tech_hover"]
const LAUNCH: StringName = &"map_launch"
const TECH_BUY: StringName = &"tech_buy"
const SAVED: StringName = &"ui_campaign_saved"
const UNLOCKED: StringName = &"ui_tech_unlocked"

## Plays the first existing event flat: `func(ids: Array[StringName], at: Vector3) -> StringName`.
var play_first: Callable = func(_ids: Array[StringName], _at: Vector3) -> StringName: return &""
## Plays an event flat with a volume offset: `func(id: StringName, at: Vector3, db: float) -> bool`.
var play_at: Callable = func(_id: StringName, _at: Vector3, _db: float) -> bool: return false
## Offers an Advisor alert kind: `func(kind: StringName) -> void`.
var offer_alert: Callable = func(_kind: StringName) -> void: pass
## Shows a campaign screen, or &"" for a landing: `func(screen: StringName) -> void`.
var show_screen: Callable = func(_screen: StringName) -> void: pass
## The launch was confirmed: `func() -> void`.
var launch: Callable = func() -> void: pass

var cues: CampaignCues = CampaignCues.new()

var _screen: StringName = &""
var _pending_return: StringName = &""
var _last_ending_sting: float = -INF
var _last_buy: float = -INF
var _unlock_due: float = INF


func _ready() -> void:
	Events.campaign_screen_changed.connect(_on_campaign_screen_changed)
	Events.ui_feedback.connect(_on_ui_feedback)
	Events.tech_unlocked.connect(_on_tech_unlocked)
	Events.landing_resolved.connect(_on_landing_resolved)
	Events.campaign_saved.connect(_on_campaign_saved)
	Events.campaign_loaded.connect(_on_campaign_loaded)
	Events.mission_started.connect(_on_mission_started)


func _process(_delta: float) -> void:
	update(_now())


## The screen shown last (&"" during a landing).
func screen() -> StringName:
	return _screen


func pending_return() -> StringName:
	return _pending_return


func handle_screen_changed(screen_name: StringName, now: float) -> void:
	_screen = screen_name
	show_screen.call(screen_name)
	if CampaignCues.is_ship_screen(screen_name) and _pending_return != &"":
		var kind: StringName = _pending_return
		_pending_return = &""
		if CampaignCues.return_allowed(now, _last_ending_sting):
			offer_alert.call(kind)


## Returns the event played (or &"").
func handle_ui_feedback(kind: StringName, now: float) -> StringName:
	if kind in HOVER_KINDS:
		var offset: float = cues.hover(now)
		if offset == CampaignCues.SKIP:
			return &""
		var event: StringName = StringName("ui_%s" % kind)
		return event if play_at.call(event, Vector3.INF, offset) else &""
	if kind == LAUNCH:
		launch.call()
	elif kind == TECH_BUY:
		_last_buy = now
		_unlock_due = INF  # the click carries the seal
	return &""


func handle_tech_unlocked(now: float) -> void:
	if now - _last_buy <= CampaignCues.TECH_PAIR_WINDOW:
		return
	# Wait a moment: the purchase click may follow the signal.
	_unlock_due = now + CampaignCues.TECH_PAIR_WINDOW


func handle_landing_resolved(won: bool, now: float) -> void:
	var kind: StringName = CampaignCues.return_kind(won)
	if CampaignCues.is_ship_screen(_screen):
		_pending_return = &""
		if CampaignCues.return_allowed(now, _last_ending_sting):
			offer_alert.call(kind)
		return
	_pending_return = kind


## Returns true if the save was confirmed.
func handle_campaign_saved(slot: StringName, now: float) -> bool:
	if not cues.save_allowed(slot, now):
		return false
	var ids: Array[StringName] = [SAVED]
	return play_first.call(ids, Vector3.INF) != &""


## A mission-ending sting (victory, defeat, storm, out-surveyed) played.
func note_ending_sting(now: float) -> void:
	_last_ending_sting = now


## Runs what is due at `now`. Returns the event played, or &"".
func update(now: float) -> StringName:
	if now < _unlock_due:
		return &""
	_unlock_due = INF
	var ids: Array[StringName] = [UNLOCKED]
	var played: StringName = play_first.call(ids, Vector3.INF)
	return played


func handle_reset() -> void:
	_pending_return = &""
	_unlock_due = INF


func _on_campaign_screen_changed(screen_name: StringName) -> void:
	handle_screen_changed(screen_name, _now())


func _on_ui_feedback(kind: StringName) -> void:
	handle_ui_feedback(kind, _now())


func _on_tech_unlocked(_tech: Resource) -> void:
	handle_tech_unlocked(_now())


func _on_landing_resolved(_node: Resource, won: bool, _intel_banked: int) -> void:
	handle_landing_resolved(won, _now())


func _on_campaign_saved(slot: StringName) -> void:
	handle_campaign_saved(slot, _now())


func _on_campaign_loaded(_slot: StringName) -> void:
	handle_reset()


func _on_mission_started() -> void:
	handle_reset()
	_screen = &""


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
