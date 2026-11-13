class_name CommanderMemory
extends RefCounted
## What the commander remembers about its own plan between decisions: how far the
## opening got, attack waves sent, when it last scouted, attacks on its base, and
## build types it should not retry for a while (no room found).

## 2: every field (threat flags, the premature-wave roll, build back-offs).
const SAVE_VERSION: int = 2

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
	var backoff: Dictionary = {}
	for id: StringName in build_backoff:
		backoff[String(id)] = build_backoff[id]
	return {
		"version": SAVE_VERSION,
		"opening_index": opening_index,
		"waves_launched": waves_launched,
		"last_attack_tick": last_attack_tick,
		"last_scout_tick": last_scout_tick,
		"attacks_on_base": attacks_on_base,
		"threatened": threatened,
		"recalled": recalled,
		"storm_recalled": storm_recalled,
		"wave_rolled": wave_rolled,
		"wave_premature": wave_premature,
		"build_backoff": backoff,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported CommanderMemory save version")
	opening_index = data.get("opening_index", 0)
	waves_launched = data.get("waves_launched", 0)
	last_attack_tick = data.get("last_attack_tick", -1000000)
	last_scout_tick = data.get("last_scout_tick", -1000000)
	attacks_on_base = data.get("attacks_on_base", 0)
	threatened = data.get("threatened", false)
	recalled = data.get("recalled", false)
	storm_recalled = data.get("storm_recalled", false)
	wave_rolled = data.get("wave_rolled", -1)
	wave_premature = data.get("wave_premature", false)
	build_backoff.clear()
	var backoff: Dictionary = data.get("build_backoff", {})
	for key: Variant in backoff:
		var until: int = backoff[key]
		build_backoff[StringName(str(key))] = until
