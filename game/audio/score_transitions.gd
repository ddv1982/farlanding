class_name ScoreTransitions
extends RefCounted
## Which transition hit (if any) covers a change of music state. Pure.
##
## Every state lives in one clip, so a change is a set of layer fades on the
## next beat (MusicDirector). Most fades are inaudible as cuts; two are not,
## and get a hit played on the beat the change lands:
##
## | from \\ to                         | combat, combat_heavy | aftermath        | anything else |
## |------------------------------------|----------------------|------------------|---------------|
## | explore, calm, tension, aftermath, | `mus_hit_combat`     | -                | -             |
## | stealth_* (no drums yet)           |                      |                  |               |
## | combat, combat_heavy               | -                    | `mus_hit_aftermath` | -          |
## | victory, defeat                    | -                    | -                | -             |
##
## combat <-> combat_heavy is a layer swell on the same drums (no hit);
## stealth_alerted already has its own alarm stinger and keeps its drums when
## combat takes over, so it is treated as "in combat" for the hit. Victory and
## defeat are settled by their stings (and mission_started resets the score).

const HIT_COMBAT: StringName = &"mus_hit_combat"
const HIT_AFTERMATH: StringName = &"mus_hit_aftermath"

const FIGHTING: Array[StringName] = [&"combat", &"combat_heavy", &"stealth_alerted"]
const FINAL: Array[StringName] = [&"victory", &"defeat"]


static func hit_for(from: StringName, to: StringName) -> StringName:
	if from == to or from == &"" or from in FINAL or to in FINAL:
		return &""
	var was_fighting: bool = from in FIGHTING
	var fighting: bool = to == &"combat" or to == &"combat_heavy"
	if fighting and not was_fighting:
		return HIT_COMBAT
	if to == &"aftermath" and (from == &"combat" or from == &"combat_heavy"):
		return HIT_AFTERMATH
	return &""
