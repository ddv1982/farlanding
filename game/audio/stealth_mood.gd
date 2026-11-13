class_name StealthMood
extends RefCounted
## Decides the stealth music state from the watching factions' alert levels.
## Pure logic.
##
## Inactive (returns &"") until the mission shows it is a stealth mission: an
## alert level was reported, or a watcher exists (StealthSoundRouter). Then
## the music follows the most alarmed faction: Unaware -> stealth_unaware (sparse),
## Suspicious -> stealth_suspicious (the pulse joins), Alerted ->
## stealth_alerted (full drive). Rising applies at once; falling waits until
## the lower level has held for HOLD_DOWN of the level being left, so an alarm
## that flickers off and on again does not drop the drive in between.

const HOLD_DOWN: Dictionary[StringName, float] = {
	StealthCues.ALERTED: 6.0,
	StealthCues.SUSPICIOUS: 4.0,
}

var active: bool = false

var _levels: Dictionary[int, StringName] = {}
var _shown: StringName = StealthCues.UNAWARE
var _lower_since: float = INF


## A faction's alert level changed. Returns the overall level before and after
## (for the stingers) as [previous, now].
func note_level(faction: int, level: StringName) -> Array[StringName]:
	var before: StringName = overall()
	active = true
	_levels[faction] = level
	return [before, overall()]


func activate() -> void:
	active = true


## The most alarmed level over all factions (Unaware if none reported).
func overall() -> StringName:
	var level: StringName = StealthCues.UNAWARE
	for faction: int in _levels:
		level = StealthCues.louder(level, _levels[faction])
	return level


## The level the music currently shows (after the hold on the way down).
func shown_level() -> StringName:
	return _shown


## Advances the hold; returns the music state, or &"" while inactive.
func update(now: float) -> StringName:
	if not active:
		return &""
	var target: StringName = overall()
	if StealthCues.rank_of(target) >= StealthCues.rank_of(_shown):
		_shown = target
		_lower_since = INF
	else:
		if _lower_since == INF:
			_lower_since = now
		var hold: float = HOLD_DOWN.get(_shown, 0.0)
		if now - _lower_since >= hold:
			_shown = target
			_lower_since = INF
	return StealthCues.music_state_for(_shown)
