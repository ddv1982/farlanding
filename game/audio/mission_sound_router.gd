class_name MissionSoundRouter
extends Node
## Mission events -> sounds (Phase 5): objectives, the briefing and debrief,
## the mission launch and the Survey storm. Listens to `Events`; gameplay never
## calls this.
##
## Objectives are the Advisor's phrases and go through its queue (one at a
## time, throttled; the Advisor bus ducks the music):
## - objective_added: `objective_hidden` for a hidden objective, else
##   `objective_new`.
## - objective_completed: `objective_done` for a primary objective,
##   `objective_done_secondary` for any other kind.
## - objective_failed: `objective_failed`.
## - objective_updated: `ui_objective_tick`, for objectives the player knows
##   (a hidden objective is silent until objective_added reveals it).
## Several objective events in one frame (a mission adding three objectives at
## once) make ONE phrase, the most important. Gameplay may also raise the
## Advisor kinds objective_new / objective_done / objective_failed itself:
## they join the same frame's choice, and the AdvisorQueue's family throttle
## keeps a signal and an alert for the same moment from both speaking.
##
## Briefing and debrief (`Events.ui_feedback`): briefing_open starts the
## briefing bed under the panel (the score dips), briefing_close stops it;
## debrief_open starts the debrief bed. The panels' own clicks are the
## interface sounds `ui_<kind>` (AudioEventRouter); text reveals send
## &"briefing_tick" (`ui_briefing_tick`).
##
## Launch: `mus_sting_launch` once per mission: when the briefing closes, or
## LAUNCH_DELAY after mission_started if no briefing is open by then.
##
## Storm (Survey): the deadline is read from the objectives themselves. A
## known, active objective with `countdown_tick` >= 0 and `countdown_fails`
## (missing = true) is a deadline; on every `Events.sim_ticked(tick)` the
## soonest one is checked. With MINUTE_SECONDS left, `mus_storm_minute` plays
## and the score's storm layer comes in; with COUNTDOWN_SECONDS left,
## `mus_storm_countdown` (ten ticks, the storm breaking on the tenth second).
## Completing the deadline objective takes the storm layer out again.
## Fallbacks for a mission without such an objective: `advisor_alert` kind
## &"objective_time_low" starts the minute stage; a later one (at least
## FINAL_MIN_GAP on) or &"storm_final" starts the countdown. (Since Phase 6
## &"storm_warning" is the weather's own warning, voiced by the Advisor and
## heard through StormSound; it no longer starts the deadline stages.)
## mission_started resets all of it.
##
## Menu (Phase 6): `menu_open` (the mission select is shown) loops the menu
## theme as a bed with the score dipped out of the way; `menu_close` stops it.

const PRIMARY: StringName = &"primary"
const HIDDEN: StringName = &"hidden"

const OBJECTIVE_NEW: StringName = &"objective_new"
const OBJECTIVE_HIDDEN: StringName = &"objective_hidden"
const OBJECTIVE_DONE: StringName = &"objective_done"
const OBJECTIVE_DONE_SECONDARY: StringName = &"objective_done_secondary"
const OBJECTIVE_FAILED: StringName = &"objective_failed"
## Advisor kinds gameplay may raise that this router voices instead of the
## AudioEventRouter (so a signal and an alert for the same moment merge).
const OBJECTIVE_ALERTS: Array[StringName] = [OBJECTIVE_NEW, OBJECTIVE_DONE, OBJECTIVE_FAILED]

const OBJECTIVE_TICK: StringName = &"ui_objective_tick"
const BRIEFING_BED: StringName = &"mus_briefing_bed"
const DEBRIEF_BED: StringName = &"mus_debrief_bed"
const MENU_THEME: StringName = &"mus_menu_theme"
const LAUNCH: StringName = &"mus_sting_launch"
const STORM_MINUTE: StringName = &"mus_storm_minute"
const STORM_COUNTDOWN: StringName = &"mus_storm_countdown"
const STORM_WARNING: StringName = &"storm_warning"
const TIME_LOW: StringName = &"objective_time_low"
const STORM_FINAL: StringName = &"storm_final"
const STORM_LAYER: StringName = &"storm"

const LAUNCH_DELAY: float = 0.3
const FINAL_MIN_GAP: float = 20.0
const MINUTE_SECONDS: float = 60.0
const COUNTDOWN_SECONDS: float = 10.0
## The score dips this far under the briefing and debrief beds.
const BRIEFING_DUCK_DB: float = -14.0
const DEBRIEF_DUCK_DB: float = -18.0
## The menu theme stands alone: the score all but stops under it.
const MENU_DUCK_DB: float = -40.0

## Plays the first existing event: `func(ids: Array[StringName], at: Vector3) -> StringName`.
var play_first: Callable = func(_ids: Array[StringName], _at: Vector3) -> StringName: return &""
## Offers an Advisor alert kind: `func(kind: StringName) -> void`.
var offer_alert: Callable = func(_kind: StringName) -> void: pass
## Starts a bed: `func(event_id: StringName, duck_db: float) -> void`.
var play_bed: Callable = func(_id: StringName, _duck_db: float) -> void: pass
## Stops the bed: `func() -> void`.
var stop_bed: Callable = func() -> void: pass
## Sets a music layer's gain: `func(layer: StringName, gain_db: float) -> void`.
var set_layer_gain: Callable = func(_layer: StringName, _db: float) -> void: pass

var _pending_kinds: Array[StringName] = []
var _known: Dictionary[StringName, bool] = {}
var _briefing_open: bool = false
var _menu_open: bool = false
var _launch_due: float = INF
var _launch_pending: bool = false
var _storm_stage: int = 0
var _storm_since: float = -INF
## Objective id -> objective, for the deadlines the player knows about.
var _deadlines: Dictionary[StringName, RefCounted] = {}


func _ready() -> void:
	Events.objective_added.connect(handle_objective_added)
	Events.objective_updated.connect(handle_objective_updated)
	Events.objective_completed.connect(handle_objective_completed)
	Events.objective_failed.connect(handle_objective_failed)
	Events.ui_feedback.connect(_on_ui_feedback)
	Events.advisor_alert.connect(_on_advisor_alert)
	Events.mission_started.connect(_on_mission_started)
	Events.sim_ticked.connect(handle_sim_ticked)
	set_layer_gain.call(STORM_LAYER, AudioMix.SILENT_DB)


func _process(_delta: float) -> void:
	flush_objectives()
	update_launch(_now())


# --- Objectives ---------------------------------------------------------------


## The Advisor kind for an objective event.
static func objective_kind(objective: Object, event: StringName) -> StringName:
	var kind: StringName = _string_name_of(objective, &"kind")
	match event:
		&"added":
			return OBJECTIVE_HIDDEN if kind == HIDDEN else OBJECTIVE_NEW
		&"completed":
			return OBJECTIVE_DONE if kind == PRIMARY or kind == &"" else OBJECTIVE_DONE_SECONDARY
		&"failed":
			return OBJECTIVE_FAILED
	return &""


func handle_objective_added(objective: RefCounted) -> void:
	var id: StringName = _string_name_of(objective, &"id")
	if id != &"":
		_known[id] = true
	_note_deadline(objective)
	_pending_kinds.append(objective_kind(objective, &"added"))


func handle_objective_updated(objective: RefCounted) -> void:
	var id: StringName = _string_name_of(objective, &"id")
	var kind: StringName = _string_name_of(objective, &"kind")
	if kind == HIDDEN and not _known.has(id):
		return
	_note_deadline(objective)
	_play(OBJECTIVE_TICK)


func handle_objective_completed(objective: RefCounted) -> void:
	var id: StringName = _string_name_of(objective, &"id")
	if _deadlines.has(id):
		_deadlines.erase(id)
		if _deadlines.is_empty() and _storm_stage > 0:
			set_layer_gain.call(STORM_LAYER, AudioMix.SILENT_DB)
	_pending_kinds.append(objective_kind(objective, &"completed"))


func handle_objective_failed(objective: RefCounted) -> void:
	_deadlines.erase(_string_name_of(objective, &"id"))
	_pending_kinds.append(objective_kind(objective, &"failed"))


## Offers this frame's most important objective phrase. Returns it, or &"".
func flush_objectives() -> StringName:
	if _pending_kinds.is_empty():
		return &""
	var best: StringName = _pending_kinds[0]
	for kind: StringName in _pending_kinds:
		if AdvisorQueue.priority_of(kind) > AdvisorQueue.priority_of(best):
			best = kind
	_pending_kinds.clear()
	offer_alert.call(best)
	return best


# --- Briefing, debrief, launch -----------------------------------------------


func handle_ui_feedback(kind: StringName, now: float) -> void:
	match kind:
		&"briefing_open":
			_briefing_open = true
			_menu_open = false
			play_bed.call(BRIEFING_BED, BRIEFING_DUCK_DB)
		&"briefing_close":
			if _briefing_open:
				_briefing_open = false
				stop_bed.call()
				if _launch_pending:
					_launch_due = now
					update_launch(now)
		&"debrief_open":
			_briefing_open = false
			_menu_open = false
			play_bed.call(DEBRIEF_BED, DEBRIEF_DUCK_DB)
		&"menu_open":
			_menu_open = true
			play_bed.call(MENU_THEME, MENU_DUCK_DB)
		&"menu_close":
			if _menu_open:
				_menu_open = false
				stop_bed.call()


func handle_mission_started(now: float) -> void:
	_pending_kinds.clear()
	_known.clear()
	_deadlines.clear()
	_storm_stage = 0
	_storm_since = -INF
	set_layer_gain.call(STORM_LAYER, AudioMix.SILENT_DB)
	_menu_open = false
	if not _briefing_open:
		stop_bed.call()
	_launch_pending = true
	_launch_due = INF if _briefing_open else now + LAUNCH_DELAY


## Plays the launch phrase once it is due (not while a briefing is open).
## Returns true when it played.
func update_launch(now: float) -> bool:
	if not _launch_pending or _briefing_open or now < _launch_due:
		return false
	_launch_pending = false
	_launch_due = INF
	_play(LAUNCH)
	return true


func is_briefing_open() -> bool:
	return _briefing_open


func is_menu_open() -> bool:
	return _menu_open


# --- Storm --------------------------------------------------------------------


## Returns the storm cue played, or &"".
func handle_advisor_alert(kind: StringName, now: float) -> StringName:
	if kind in OBJECTIVE_ALERTS:
		_pending_kinds.append(kind)
		return &""
	var warning: bool = kind == TIME_LOW
	if kind == STORM_FINAL or (warning and _storm_stage >= 1):
		if _storm_stage >= 2 or (warning and now - _storm_since < FINAL_MIN_GAP):
			return &""
		return _enter_storm(2, now)
	if warning:
		return _enter_storm(1, now)
	return &""


## Checks the soonest known deadline at sim tick `tick`. Returns the storm cue
## played, or &"".
func handle_sim_ticked(tick: int) -> StringName:
	var left: float = seconds_to_deadline(tick)
	if left == INF:
		return &""
	if left <= COUNTDOWN_SECONDS and _storm_stage < 2:
		return _enter_storm(2, _now())
	if left <= MINUTE_SECONDS and _storm_stage < 1:
		return _enter_storm(1, _now())
	return &""


## Seconds to the soonest active deadline at `tick`, or INF if there is none.
func seconds_to_deadline(tick: int) -> float:
	var soonest: float = INF
	for id: StringName in _deadlines.keys():
		var objective: RefCounted = _deadlines[id]
		if not is_deadline(objective):
			continue
		var due: int = _int_of(objective, &"countdown_tick")
		soonest = minf(soonest, maxf(float(due - tick) / SimClock.TICK_RATE, 0.0))
	return soonest


## A known objective that fails when its countdown runs out, and is still active.
static func is_deadline(objective: Object) -> bool:
	if objective == null or _int_of(objective, &"countdown_tick") < 0:
		return false
	var fails: Variant = objective.get(&"countdown_fails")
	if fails is bool and not fails:
		return false
	var state: StringName = _string_name_of(objective, &"state")
	return state == &"" or state == &"active"


func storm_stage() -> int:
	return _storm_stage


# --- Internals ----------------------------------------------------------------


func _enter_storm(stage: int, now: float) -> StringName:
	var cue: StringName = STORM_COUNTDOWN if stage >= 2 else STORM_MINUTE
	if stage == 1:
		_storm_since = now
	_storm_stage = stage
	_play(cue)
	set_layer_gain.call(STORM_LAYER, 0.0)
	return cue


func _note_deadline(objective: RefCounted) -> void:
	var id: StringName = _string_name_of(objective, &"id")
	if id != &"" and is_deadline(objective):
		_deadlines[id] = objective


func _on_ui_feedback(kind: StringName) -> void:
	handle_ui_feedback(kind, _now())


func _on_advisor_alert(kind: StringName) -> void:
	handle_advisor_alert(kind, _now())


func _on_mission_started() -> void:
	handle_mission_started(_now())


func _play(event_id: StringName) -> StringName:
	var ids: Array[StringName] = [event_id]
	var started: StringName = play_first.call(ids, Vector3.INF)
	return started


static func _int_of(object: Object, property: StringName) -> int:
	if object == null or not is_instance_valid(object):
		return -1
	var value: Variant = object.get(property)
	if value is int:
		var number: int = value
		return number
	return -1


static func _string_name_of(object: Object, property: StringName) -> StringName:
	if object == null or not is_instance_valid(object):
		return &""
	var value: Variant = object.get(property)
	if value is StringName:
		var found: StringName = value
		return found
	if value is String:
		var text: String = value
		return StringName(text)
	return &""


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
