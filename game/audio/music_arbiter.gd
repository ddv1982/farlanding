class_name MusicArbiter
extends RefCounted
## Merges the two things that ask for music states: the combat mood
## (MusicMood: explore, tension, combat, combat_heavy, aftermath) and the stealth mood
## (StealthMood: stealth_unaware, _suspicious, _alerted; &"" when the mission
## is not a stealth mission). Pure logic.
##
## Without stealth the combat mood plays. With it, the stealth state plays,
## except that real fighting wins: combat always, and tension or aftermath
## over a merely Unaware stealth score (a skirmish in a stealth mission still
## sounds like one).


static func pick(combat_state: StringName, stealth_state: StringName) -> StringName:
	if stealth_state == &"":
		return combat_state
	if combat_state == MusicMood.COMBAT or combat_state == MusicMood.COMBAT_HEAVY:
		return combat_state
	var fighting: bool = combat_state == MusicMood.TENSION or combat_state == MusicMood.AFTERMATH
	if fighting and stealth_state == StealthCues.MUSIC_UNAWARE:
		return combat_state
	return stealth_state
