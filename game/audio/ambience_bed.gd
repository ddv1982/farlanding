class_name AmbienceBed
extends Resource
## One looping bed of a planet's ambience (AmbienceSet). It plays on the
## AmbienceDirector's own player and wanders slowly in level.

## SoundEvent whose first stream is the loop.
@export var event: StringName = &""
## Range its level wanders in (dB); (0, 0) holds it still.
@export var wander_db: Vector2 = Vector2.ZERO
## Level offset at low water (x) and at high water (y), in dB. Planets without
## a tide leave it at zero.
@export var tide_db: Vector2 = Vector2.ZERO
## A hush bed is silent until the listener nears an Antecedent site, then rises
## while the other beds step back.
@export var hush: bool = false
