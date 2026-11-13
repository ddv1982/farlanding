class_name StealthSoundRouter
extends Node
## Stealth events -> sounds and the stealth music state (Phase 5). Listens to
## `Events`; gameplay never calls this. The rising suspicion tones are the
## SuspicionTones'.
##
## - alert_level_changed: the most alarmed watching faction decides what the
##   player hears. Rising to Suspicious plays `stealth_alert_suspicious`, rising
##   to Alerted `stealth_alert_alarm` (the Combine's alarm), falling back to
##   Unaware `stealth_all_clear`. Levels reported for the player's own faction
##   are ignored.
## - intruder_spotted: `stealth_spotted` (flat, Stealth bus) with a short duck
##   of music, ambience and effects so it always reads; once per target within
##   SPOTTED_REPEAT however many watchers see it. Spotting a target of another
##   faction than the player's is not the player's problem and stays silent.
## - Cloaking: units in group &"units" exposing `is_cloaked` are watched every
##   CLOAK_INTERVAL; a change plays `stealth_cloak_engage`/`_disengage` at the
##   unit if it is the player's or was visible to the player. A unit's first
##   reading is its baseline (a Wisp that spawns cloaked is silent).
## - Music: StealthMood (stealth_unaware / _suspicious / _alerted), active once
##   the mission reports an alert level (only guard factions keep one; an
##   initial `alert_level_changed(faction, &"unaware", &"unaware")` starts the
##   sparse score silently) or has a node in group &"watchers". A watcher's
##   suspicion alone does not make a mission a stealth mission (a Wisp in a
##   Conquest mission keeps the combat score). Requests go through
##   `set_music_state` (the AudioService merges them with the combat mood).
## - mission_started resets all of it; mission_ended freezes the music request.

const UNITS_GROUP: StringName = &"units"
const WATCHERS_GROUP: StringName = &"watchers"
const CLOAK_INTERVAL: float = 0.2
const MOOD_INTERVAL: float = 0.25
## The same target is not stung again within this many seconds.
const SPOTTED_REPEAT: float = 4.0
## How long the spotted sting ducks the other buses.
const SPOTTED_DUCK: float = 0.5

@export var player_faction: int = 0

## Plays the first existing event: `func(ids: Array[StringName], at: Vector3) -> StringName`.
var play_first: Callable = func(_ids: Array[StringName], _at: Vector3) -> StringName: return &""
## Ducks other buses: `func(hold_seconds: float) -> void`.
var duck: Callable = func(_hold: float) -> void: pass
## Requests the stealth music state (&"" = no stealth music): `func(state: StringName) -> void`.
var set_music_state: Callable = func(_state: StringName) -> void: pass

var mood: StealthMood = StealthMood.new()

var _music_state: StringName = &""
var _over: bool = false
var _mood_left: float = 0.0
var _cloak_left: float = 0.0
var _last_spotted: Dictionary[int, float] = {}
## Unit instance id -> [was cloaked, was visible] at the last scan.
var _cloaks: Dictionary[int, Array] = {}


func _ready() -> void:
	Events.alert_level_changed.connect(_on_alert_level_changed)
	Events.intruder_spotted.connect(_on_intruder_spotted)
	Events.mission_started.connect(handle_mission_started)
	Events.mission_ended.connect(_on_mission_ended)


func _process(delta: float) -> void:
	_cloak_left -= delta
	if _cloak_left <= 0.0:
		_cloak_left = CLOAK_INTERVAL
		scan_cloaks()
	_mood_left -= delta
	if _mood_left <= 0.0:
		_mood_left = MOOD_INTERVAL
		update_mood(_now())


## Re-evaluates the stealth music state and reports it if it changed.
func update_mood(now: float) -> StringName:
	if _over:
		return _music_state
	if not mood.active and is_inside_tree():
		if get_tree().get_first_node_in_group(WATCHERS_GROUP) != null:
			mood.activate()
	var wanted: StringName = mood.update(now)
	if wanted != _music_state:
		_music_state = wanted
		set_music_state.call(wanted)
	return wanted


func music_state() -> StringName:
	return _music_state


# --- Event handlers (public `handle_*` so tests can pass a time) -------------


func handle_alert_level_changed(
	faction: int, level: StringName, _previous: StringName, now: float
) -> Array[StringName]:
	if faction == player_faction:
		return []
	var change: Array[StringName] = mood.note_level(faction, level)
	var events: Array[StringName] = StealthCues.alert_events(change[1], change[0])
	for event_id: StringName in events:
		_play(event_id, Vector3.INF)
	update_mood(now)
	return events


## Returns true if the sting played.
func handle_intruder_spotted(_watcher: Node3D, target: Node3D, now: float) -> bool:
	if is_instance_valid(target):
		var faction: int = AudioEventRouter.faction_of(target)
		if faction != -1 and faction != player_faction:
			return false
	var key: int = target.get_instance_id() if is_instance_valid(target) else 0
	var last: float = _last_spotted.get(key, -INF)
	if now - last < SPOTTED_REPEAT:
		return false
	_last_spotted[key] = now
	var played: StringName = _play(StealthCues.SPOTTED, Vector3.INF)
	if played != &"":
		duck.call(SPOTTED_DUCK)
	return played != &""


func handle_mission_started() -> void:
	mood = StealthMood.new()
	_over = false
	_last_spotted.clear()
	_cloaks.clear()
	_music_state = &""
	set_music_state.call(&"")


func handle_mission_ended(_won: bool) -> void:
	_over = true


## Reads every unit's cloak; plays the change for units the player can hear.
## Returns the event ids played (for tests).
func scan_cloaks() -> Array[StringName]:
	var played: Array[StringName] = []
	if not is_inside_tree():
		return played
	var seen: Dictionary[int, Array] = {}
	for node: Node in get_tree().get_nodes_in_group(UNITS_GROUP):
		var unit: Node3D = node as Node3D
		if unit == null or not unit.is_inside_tree():
			continue
		var cloaked: Variant = StealthCues.cloak_state(unit)
		if cloaked == null:
			continue
		var now_cloaked: bool = cloaked
		var visible: bool = not CombatCues.is_hidden(unit)
		var key: int = unit.get_instance_id()
		seen[key] = [now_cloaked, visible]
		if not _cloaks.has(key):
			continue
		var before: Array = _cloaks[key]
		var was_cloaked: bool = before[0]
		var was_visible: bool = before[1]
		if was_cloaked == now_cloaked:
			continue
		var mine: bool = AudioEventRouter.faction_of(unit) == player_faction
		if not (mine or was_visible or visible):
			continue
		var event_id: StringName = (
			StealthCues.CLOAK_ENGAGE if now_cloaked else StealthCues.CLOAK_DISENGAGE
		)
		if _play(event_id, unit.global_position) != &"":
			played.append(event_id)
	_cloaks = seen
	return played


func _on_alert_level_changed(faction: int, level: StringName, previous: StringName) -> void:
	handle_alert_level_changed(faction, level, previous, _now())


func _on_intruder_spotted(watcher: Node3D, target: Node3D) -> void:
	handle_intruder_spotted(watcher, target, _now())


func _on_mission_ended(won: bool) -> void:
	handle_mission_ended(won)


func _play(event_id: StringName, at: Vector3) -> StringName:
	var ids: Array[StringName] = [event_id]
	var started: StringName = play_first.call(ids, at)
	return started


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
