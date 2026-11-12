class_name Building
extends Node3D
## A building: a thin root holding its definition and faction, composed of
## components chosen by its BuildingDef — always a Construction, a Producer when it
## makes units, a FluxExtractor when it taps Flux. Spawned by SimWorld (which sets
## `def`, `faction`, `world`, `entity_id` and calls `setup()`), ticked by it on the
## sim clock. Buildings are not rotated: the door side faces +Z.

## Construction progress changed, in [0, 1]. The visual raises the model with it.
signal build_progress_changed(progress: float)
## Construction finished.
signal completed

const SAVE_VERSION: int = 1
const GROUP: StringName = &"buildings"

var def: BuildingDef
var faction: int = 0
var world: SimWorld = null
## Save id, unique within the mission; -1 until spawned.
var entity_id: int = -1
var construction: Construction = null
var producer: Producer = null
var flux_extractor: FluxExtractor = null
## The vent a Flux Tap stands on, or null.
var vent: ResourceNode = null

## Read by audio (base loops) and the HUD.
var is_under_construction: bool:
	get:
		return construction != null and not construction.is_complete()
var is_producing: bool:
	get:
		return is_operational() and producer != null and producer.is_busy()
var is_powered: bool:
	get:
		if not is_operational():
			return false
		if def.power_use == 0 or world == null or world.economy == null:
			return true
		return not world.economy.stockpile(faction).is_low_power()

var _was_complete: bool = false
var _shown_progress: float = -1.0


func _enter_tree() -> void:
	add_to_group(GROUP)


## Creates the components for `def`. `complete` makes it stand finished (pre-placed).
func setup(complete: bool) -> void:
	construction = Construction.new()
	construction.name = &"Construction"
	construction.start(def.build_time, complete)
	add_child(construction)
	if def.is_producer():
		producer = Producer.new()
		producer.name = &"Producer"
		producer.setup(def.produces, def.queue_limit)
		add_child(producer)
	if def.flux_amount > 0:
		flux_extractor = FluxExtractor.new()
		flux_extractor.name = &"FluxExtractor"
		flux_extractor.setup(def.flux_amount, def.flux_interval)
		add_child(flux_extractor)
	_was_complete = complete


func _ready() -> void:
	if construction != null:
		build_progress_changed.emit(construction.progress())


func is_operational() -> bool:
	return construction != null and construction.is_complete()


## Ground area this building occupies (world X/Z).
func footprint() -> Rect2:
	return def.world_footprint(position)


## Where produced units appear.
func door_position() -> Vector3:
	return position + def.door


## Where haulers unload.
func dock_position() -> Vector3:
	return position + def.dock


## True if haulers of `p_faction` may unload here now.
func accepts_alloy_from(p_faction: int) -> bool:
	return def.accepts_alloy and faction == p_faction and is_operational()


## One sim tick of construction (builders added their work earlier in the tick).
## Returns true on the tick construction finished.
func sim_tick() -> bool:
	if construction == null:
		return false
	if not construction.is_complete():
		construction.end_tick()
		if construction.progress() != _shown_progress:
			_shown_progress = construction.progress()
			build_progress_changed.emit(_shown_progress)
		return false
	if not _was_complete:
		construction.end_tick()
		_was_complete = true
		build_progress_changed.emit(1.0)
		completed.emit()
		return true
	return false


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"def": def.resource_path if def != null else "",
		"faction": faction,
		"entity_id": entity_id,
		"position": var_to_str(position),
		"construction": construction.to_dict() if construction != null else {},
		"producer": producer.to_dict() if producer != null else {},
		"flux": flux_extractor.to_dict() if flux_extractor != null else {},
		"vent": Order.entity_id_of(vent),
	}


## Restores component state; the spawner sets `def`, `faction` and the position and
## calls `setup()` first.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Building save version")
	entity_id = data.get("entity_id", entity_id)
	var construction_data: Dictionary = data.get("construction", {})
	if construction != null and not construction_data.is_empty():
		construction.from_dict(construction_data)
		_was_complete = construction.is_complete()
	var producer_data: Dictionary = data.get("producer", {})
	if producer != null and not producer_data.is_empty():
		producer.from_dict(producer_data)
	var flux_data: Dictionary = data.get("flux", {})
	if flux_extractor != null and not flux_data.is_empty():
		flux_extractor.from_dict(flux_data)
