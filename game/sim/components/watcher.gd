class_name Watcher
extends Node
## A unit's watchfulness (PLAN 3.4): how sure it is that someone is there. The
## StealthSystem raises `suspicion` (0..1) while the unit sees an intruder in its
## sight cone and lets it fall when it sees nothing; this node only holds the state.
## Its faction's behaviours read `last_noticed` (where it last noticed something),
## which is the unit's own knowledge, not the world's.

const SAVE_VERSION: int = 1

var unit: Unit = null
var suspicion: float = 0.0
## The unit it is watching (null when nothing has its attention).
var focus: Unit = null
## Suspicion per second it gains from `focus` this tick.
var rate: float = 0.0
## Where it last noticed something; valid while `has_noticed`.
var last_noticed: Vector3 = Vector3.ZERO
var has_noticed: bool = false
## True once suspicion reached 1 (it is sure), until it calms down to zero.
var spotted: bool = false
## True while its faction is alerted (set by the stealth system).
var faction_alerted: bool = false
## Sim tick it last saw anything (suspicion holds for a moment before it falls).
var last_seen_tick: int = -1000000
## The notice threshold was crossed and has not been re-armed yet (suspicion must
## fall back to zero first).
var noticed_announced: bool = false

var is_alerted: bool:
	get:
		return spotted or faction_alerted


func setup(p_unit: Unit) -> void:
	unit = p_unit


## Forgets everything: back to calm.
func calm() -> void:
	suspicion = 0.0
	focus = null
	rate = 0.0
	spotted = false
	noticed_announced = false


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"suspicion": suspicion,
		"last_noticed": var_to_str(last_noticed),
		"has_noticed": has_noticed,
		"spotted": spotted,
		"announced": noticed_announced,
	}


## Restores the state; the focus is found again by looking.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Watcher save version")
	suspicion = data.get("suspicion", 0.0)
	var text: String = data.get("last_noticed", "Vector3(0, 0, 0)")
	last_noticed = str_to_var(text)
	has_noticed = data.get("has_noticed", false)
	spotted = data.get("spotted", false)
	noticed_announced = data.get("announced", false)
