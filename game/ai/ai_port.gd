class_name AiPort
extends RefCounted
## How the AI's unit behaviours sense and act for one faction: they push Commands (the
## one command path), look around (only what the faction sees now) and read the time.
## This base class is a do-nothing fake for tests; WorldAiPort works on a live world.

var faction: int = 1
## Commands pushed so far (to watch for command spam).
var commands_pushed: int = 0


## The current sim tick.
func now() -> int:
	return 0


## Issues `command` for this faction.
func push(_command: Command) -> void:
	commands_pushed += 1


## Enemy units and buildings this faction sees now within `radius` of `center`.
func seen_enemies(_center: Vector3, _radius: float) -> Array[Node3D]:
	return []


## This faction's alert level (StealthSystem.LEVEL_*): its own knowledge.
func alert_level() -> StringName:
	return StealthSystem.LEVEL_UNAWARE


## Where this faction last noticed an intruder; Vector3.INF if never.
func alert_position() -> Vector3:
	return Vector3.INF
