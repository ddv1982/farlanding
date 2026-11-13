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


## The weather everyone sees: storm intensity 0..1.
func storm_intensity() -> float:
	return 0.0


## Seconds until an announced storm starts; INF when none is announced.
func storm_eta_seconds() -> float:
	return INF


## True while the storm will not lift again.
func storm_is_final() -> bool:
	return false


## The tide (public, like the weather): 0 = low water .. 1 = high water.
func tide_level() -> float:
	return 0.0


## Seconds until the shallows next start to flood (0 while the sea rises or stands
## high); INF without a sea.
func shallows_close_seconds() -> float:
	return INF


## A crossing that stays dry at any tide (the map's causeway) to route a move from
## `from` to `to` through, when the straight way crosses the deep channel; Vector3.INF
## when there is none or none is needed.
func dry_crossing(_from: Vector3, _to: Vector3) -> Vector3:
	return Vector3.INF


## Vents about to erupt or close to it (public, like the weather): x, z, radius and
## seconds until the burst (INF when not building). Empty without eruptions.
func vent_dangers() -> Array[Vector4]:
	return []


## Carriable props (artefacts) this faction knows of: lying anywhere (charted from
## orbit), carried by its own units, or carried by an enemy it sees now.
func known_cargo() -> Array[Prop]:
	return []


## Discovery sites anyone may scan now (charted on the orbital scan, unresolved).
func open_sites() -> Array[Node3D]:
	return []
