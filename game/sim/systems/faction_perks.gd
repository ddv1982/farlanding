class_name FactionPerks
extends RefCounted
## What one faction brings into a landing from outside it (ADR 0012): entity types it
## may not field yet (locked), and stat multipliers. The sim reads them where a stat is
## used; it never knows where they came from (the campaign's tech web and loadout build
## them before the landing starts). A faction without perks plays the definitions as
## they are.
##
## Scales are keyed by stat (`vision_range`, every entity of the faction) or by
## "<def id>/<stat>" (one entity type, or one field option); both multiply.

const SAVE_VERSION: int = 1
## Stats the sim scales.
const MAX_HEALTH: StringName = &"max_health"
const VISION_RANGE: StringName = &"vision_range"
const CARRY_CAPACITY: StringName = &"carry_capacity"
const MINE_TIME: StringName = &"mine_time"
const SCAN_RATE: StringName = &"scan_rate"
## Field option stats (keyed "<option id>/<stat>").
const INTEL_COST: StringName = &"intel_cost"
const COOLDOWN: StringName = &"cooldown"
## Damage an eruption deals to the faction's buildings (ADR 0015).
const ERUPTION_DAMAGE: StringName = &"eruption_damage"
## Cooldown of controlled venting on the faction's Flux Taps (keyed by the Tap's id).
const VENT_COOLDOWN: StringName = &"vent_cooldown"
## How close an observer of the faction sees a unit under a tree crown (ADR 0016).
const CANOPY_SIGHT: StringName = &"canopy_sight"
const STATS: Array[StringName] = [
	MAX_HEALTH,
	VISION_RANGE,
	CARRY_CAPACITY,
	MINE_TIME,
	SCAN_RATE,
	INTEL_COST,
	COOLDOWN,
	ERUPTION_DAMAGE,
	VENT_COOLDOWN,
	CANOPY_SIGHT,
]

static var _none: FactionPerks = null

## Entity type ids (and field option ids) the faction may not produce, place or use.
var locked: Dictionary[StringName, bool] = {}
## Stat key -> multiplier.
var scales: Dictionary[StringName, float] = {}


## The perks of `faction` in `by_faction` (a SimWorld's `perks`); a shared empty set
## when it has none (do not change that one).
static func of(by_faction: Dictionary[int, FactionPerks], faction: int) -> FactionPerks:
	var found: FactionPerks = by_faction.get(faction, null)
	if found != null:
		return found
	if _none == null:
		_none = FactionPerks.new()
	return _none


## True if `id` (an entity type or field option id) may not be used.
func is_locked(id: StringName) -> bool:
	return locked.has(id)


func lock(id: StringName) -> void:
	if id != &"":
		locked[id] = true


func unlock(id: StringName) -> void:
	locked.erase(id)


## Multiplies `stat` by `factor`, for every entity (`target` empty) or for `target`.
func add_scale(target: StringName, stat: StringName, factor: float) -> void:
	var key: StringName = key_of(target, stat)
	scales[key] = scales.get(key, 1.0) * factor


## The multiplier of `stat` for the entity type or field option `id`.
func scale(id: StringName, stat: StringName) -> float:
	if scales.is_empty():
		return 1.0
	var general: float = scales.get(stat, 1.0)
	return general * scales.get(key_of(id, stat), 1.0)


## `base` scaled for `id`.
func apply(id: StringName, stat: StringName, base: float) -> float:
	return base * scale(id, stat)


## True if nothing is locked or scaled.
func is_empty() -> bool:
	return locked.is_empty() and scales.is_empty()


static func key_of(target: StringName, stat: StringName) -> StringName:
	return stat if target == &"" else StringName("%s/%s" % [target, stat])


func to_dict() -> Dictionary:
	var scale_data: Dictionary = {}
	for key: StringName in scales:
		scale_data[String(key)] = scales[key]
	var locked_ids: Array[String] = []
	for id: StringName in locked:
		locked_ids.append(String(id))
	return {"version": SAVE_VERSION, "locked": locked_ids, "scales": scale_data}


static func from_dict(data: Dictionary) -> FactionPerks:
	var perks: FactionPerks = FactionPerks.new()
	var version: int = data.get("version", 0)
	if version != SAVE_VERSION:
		return perks
	var ids: Array = data.get("locked", [])
	for id: Variant in ids:
		perks.lock(StringName(str(id)))
	var scale_data: Dictionary = data.get("scales", {})
	for key: Variant in scale_data:
		var factor: float = scale_data[key]
		perks.scales[StringName(str(key))] = factor
	return perks
