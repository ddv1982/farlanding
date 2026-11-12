class_name AudioCueSelector
extends RefCounted
## Pure logic that turns gameplay notifications into sound-event ids.
##
## Returns candidates in order of preference; the router plays the first one
## that exists as a SoundEvent, so a sound set without, say, an attack reply
## falls back to the generic interface sound instead of staying silent.
##
## Group rule: a selection or an order gets ONE reply, from the sound set most
## common in the group (ties: the one seen first). Repeats are throttled.

## The same reply for the same sound set is not repeated within this window.
const REPEAT_WINDOW: float = 0.6
## No two unit replies start closer together than this.
const MIN_GAP: float = 0.12
## Command kinds that answer with the `attack` reply.
## Command kinds that already have their own sound (production queueing plays
## `ui_queue` from `production_started`), so no order click is added.
const SILENT_KINDS: Array[StringName] = [&"produce", &"cancel_production"]
const ATTACK_KINDS: Array[StringName] = [&"attack", &"attack_move", &"force_attack"]
## Command kinds that place a ground marker ping at `target_position`.
const GROUND_KINDS: Array[StringName] = [
	&"move", &"attack_move", &"patrol", &"rally", &"set_rally", &"rally_point"
]
## Command kinds that set a producer's rally point.
const RALLY_KINDS: Array[StringName] = [&"rally", &"set_rally", &"rally_point"]

## `ui_feedback` kinds whose event is not simply `ui_<kind>`.
const FEEDBACK_ALIASES: Dictionary[StringName, StringName] = {
	&"placement_invalid": &"ui_invalid_placement",
	&"insufficient_resources": &"ui_not_enough_resources",
	&"build_menu": &"ui_build_button",
	&"build": &"ui_build_button",
	&"production_queued": &"ui_queue",
	&"queued": &"ui_queue",
	&"rally": &"ui_rally_set",
}

var _last_reply_time: float = -INF
var _last_reply: StringName = &""
var _last_reply_set: StringName = &""
var _had_selection: bool = false


## The sound set most common among `sound_sets` (empty names ignored); ties go
## to the one that appears first. Returns &"" if none.
static func dominant_sound_set(sound_sets: Array[StringName]) -> StringName:
	var counts: Dictionary[StringName, int] = {}
	var order: Array[StringName] = []
	for sound_set: StringName in sound_sets:
		if sound_set == &"":
			continue
		if not counts.has(sound_set):
			counts[sound_set] = 0
			order.append(sound_set)
		counts[sound_set] += 1
	var best: StringName = &""
	var best_count: int = 0
	for sound_set: StringName in order:
		if counts[sound_set] > best_count:
			best = sound_set
			best_count = counts[sound_set]
	return best


## The reply kind for a command kind: &"move", &"attack", or &"" for none.
static func reply_kind(command_kind: StringName) -> StringName:
	if command_kind in ATTACK_KINDS:
		return &"attack"
	if command_kind == &"stop" or command_kind == &"hold":
		return &""
	return &"move"


static func unit_event(sound_set: StringName, kind: StringName) -> StringName:
	return StringName("unit_%s_%s" % [sound_set, kind])


static func building_event(sound_set: StringName) -> StringName:
	return StringName("building_%s_select" % sound_set)


## Advisor phrase for an alert kind, falling back to the generic alert.
static func advisor_events(kind: StringName) -> Array[StringName]:
	return [StringName("advisor_%s" % kind), &"advisor_alert"]


## Candidates for a new selection. Empty selection plays the deselect tick
## (only if something was selected before).
func on_selection(sound_sets: Array[StringName], now: float) -> Array[StringName]:
	if sound_sets.is_empty():
		var had: bool = _had_selection
		_had_selection = false
		if had:
			return [&"ui_deselect"]
		return []
	_had_selection = true
	var sound_set: StringName = dominant_sound_set(sound_sets)
	if sound_set == &"":
		return [&"ui_select"]
	if not _allow_reply(&"select", sound_set, now):
		return [&"ui_select"]
	return [unit_event(sound_set, &"select"), &"ui_select"]


## Candidates for a selection of buildings only (any unit in the selection
## takes precedence and goes through `on_selection`): the machine identity of
## the most common building type, once, throttled like unit replies.
func on_building_selection(sound_sets: Array[StringName], now: float) -> Array[StringName]:
	if sound_sets.is_empty():
		return on_selection(sound_sets, now)
	_had_selection = true
	var sound_set: StringName = dominant_sound_set(sound_sets)
	if sound_set == &"" or not _allow_reply(&"building", sound_set, now):
		return [&"ui_select"]
	return [building_event(sound_set), &"ui_select"]


## Candidates for a command issued by the player.
func on_command(
	sound_sets: Array[StringName], command_kind: StringName, now: float
) -> Array[StringName]:
	if command_kind in SILENT_KINDS:
		return []
	if command_kind in RALLY_KINDS:
		return [&"ui_rally_set", &"ui_order"]
	var kind: StringName = reply_kind(command_kind)
	var sound_set: StringName = dominant_sound_set(sound_sets)
	if kind == &"" or sound_set == &"":
		return [&"ui_order"]
	if not _allow_reply(kind, sound_set, now):
		return []
	return [unit_event(sound_set, kind), &"ui_order"]


## Event id for a `ui_feedback` kind: the kind itself if it already names a
## `ui_` event, plus a few aliases, otherwise `ui_<kind>`.
static func feedback_event(kind: StringName) -> Array[StringName]:
	var text: String = String(kind)
	var direct: StringName = FEEDBACK_ALIASES.get(
		kind, StringName(text if text.begins_with("ui_") else "ui_" + text)
	)
	if (
		text.begins_with("invalid")
		or text.ends_with("_invalid")
		or text.begins_with("not_enough")
		or text.begins_with("insufficient")
		or text.ends_with("_denied")
	):
		return [direct, &"ui_invalid"]
	return [direct]


func _allow_reply(kind: StringName, sound_set: StringName, now: float) -> bool:
	if now - _last_reply_time < MIN_GAP:
		return false
	if (
		kind == _last_reply
		and sound_set == _last_reply_set
		and now - _last_reply_time < REPEAT_WINDOW
	):
		return false
	_last_reply_time = now
	_last_reply = kind
	_last_reply_set = sound_set
	return true
