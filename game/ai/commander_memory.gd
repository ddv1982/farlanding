class_name CommanderMemory
extends RefCounted
## What the commander remembers about its own plan between decisions: how far the
## opening got, attack waves sent, when it last scouted, attacks on its base, and
## build types it should not retry for a while (no room found).

const SAVE_VERSION: int = 1

var opening_index: int = 0
var waves_launched: int = 0
var last_attack_tick: int = -1000000
var last_scout_tick: int = -1000000
## Separate attacks on the base so far (a new one starts after a quiet spell).
var attacks_on_base: int = 0
## True while the last decision saw enemies near home.
var threatened: bool = false
## True once the attack group was called home for the current attack on the base.
var recalled: bool = false
## True once the wave was called home for the current storm.
var storm_recalled: bool = false
## The wave the "premature attack" mistake was rolled for, and the result.
var wave_rolled: int = -1
var wave_premature: bool = false
## Def id -> sim tick before which it is not tried again.
var build_backoff: Dictionary[StringName, int] = {}


func is_backed_off(def: EntityDef, now: int) -> bool:
	return def != null and build_backoff.get(def.id, -1) > now


func back_off(def: EntityDef, until_tick: int) -> void:
	if def != null:
		build_backoff[def.id] = until_tick


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"opening_index": opening_index,
		"waves_launched": waves_launched,
		"last_attack_tick": last_attack_tick,
		"last_scout_tick": last_scout_tick,
		"attacks_on_base": attacks_on_base,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported CommanderMemory save version")
	opening_index = data.get("opening_index", 0)
	waves_launched = data.get("waves_launched", 0)
	last_attack_tick = data.get("last_attack_tick", -1000000)
	last_scout_tick = data.get("last_scout_tick", -1000000)
	attacks_on_base = data.get("attacks_on_base", 0)
