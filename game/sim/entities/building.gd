class_name Building
extends Node3D
## A building: a thin root holding its definition and faction, composed of
## components chosen by its BuildingDef — always a Construction and a Health, a
## Producer when it makes units, a FluxExtractor when it taps Flux, a Weapon when it
## defends (Sentry: fires only while powered). Spawned by SimWorld (which sets
## `def`, `faction`, `world`, `entity_id` and calls `setup()`), ticked by it on the
## sim clock. Buildings are not rotated: the door side faces +Z.

## Construction progress changed, in [0, 1]. The visual raises the model with it.
signal build_progress_changed(progress: float)
## Construction finished.
signal completed
## Health changed, `fraction` in [0, 1]. The visual shows it.
signal health_changed(fraction: float)
## The weapon aims at `point` (every tick while it has a target).
signal aim_changed(point: Vector3)
## The weapon stopped aiming.
signal aim_cleared
## A saboteur disabled the building for good.
signal sabotaged

const SAVE_VERSION: int = 3
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
var health: Health = null
## Null for buildings without a defence weapon.
var weapon: Weapon = null
## False while the player cannot see this building now. Read by audio and UI.
var is_visible_to_player: bool = true
## True once the player has seen it; an enemy building stays shown from then on.
var seen_by_player: bool = true
## Sabotage work done on it so far, 0..1 (1 = sabotaged). Read by UI.
var sabotage_progress: float = 0.0
## True once sabotaged: it no longer works. Read by audio, UI and presentation.
var is_sabotaged: bool = false
## True from the moment its health ran out.
var is_dead: bool:
	get:
		return health != null and health.is_dead()

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
	health = Health.new()
	health.name = &"Health"
	health.setup(def.max_health, def.armour_type, self)
	health.changed.connect(health_changed.emit)
	add_child(health)
	if def.weapon != null:
		weapon = Weapon.new()
		weapon.name = &"Weapon"
		weapon.setup(def.weapon, self, faction, world.combat if world != null else null)
		weapon.aim_changed.connect(aim_changed.emit)
		weapon.aim_cleared.connect(aim_cleared.emit)
		add_child(weapon)
	_was_complete = complete


func _ready() -> void:
	if construction != null:
		build_progress_changed.emit(construction.progress())


func is_operational() -> bool:
	return construction != null and construction.is_complete() and not is_sabotaged


## Disables the building for good (SimWorld.sabotage announces it).
func sabotage() -> void:
	if is_sabotaged:
		return
	sabotage_progress = 1.0
	is_sabotaged = true
	sabotaged.emit()


## Ground area this building occupies (world X/Z).
func footprint() -> Rect2:
	return def.world_footprint(position)


## Simulation position (buildings do not move).
func sim_position() -> Vector3:
	return position


## One sim tick of the defence weapon: it aims while operational and fires only
## while powered.
func tick_weapon(dt: float) -> void:
	if weapon == null or is_dead or not is_operational():
		return
	weapon.tick(dt, position, 0.0, null, true, is_powered)


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
		"health": health.to_dict() if health != null else {},
		"weapon": weapon.to_dict() if weapon != null else {},
		"sabotage": sabotage_progress,
		"sabotaged": is_sabotaged,
	}


## Restores component state; the spawner sets `def`, `faction` and the position and
## calls `setup()` first.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported Building save version")
	entity_id = data.get("entity_id", entity_id)
	var construction_data: Dictionary = data.get("construction", {})
	if construction != null and not construction_data.is_empty():
		construction.from_dict(construction_data)
		_was_complete = construction.is_complete()
		# The visual was set up from the unsaved state in _ready(); show the loaded one.
		build_progress_changed.emit(construction.progress())
	var producer_data: Dictionary = data.get("producer", {})
	if producer != null and not producer_data.is_empty():
		producer.from_dict(producer_data)
	var flux_data: Dictionary = data.get("flux", {})
	if flux_extractor != null and not flux_data.is_empty():
		flux_extractor.from_dict(flux_data)
	var health_data: Dictionary = data.get("health", {})
	if health != null and not health_data.is_empty():
		health.from_dict(health_data)
	var weapon_data: Dictionary = data.get("weapon", {})
	if weapon != null and not weapon_data.is_empty():
		weapon.from_dict(weapon_data)
	sabotage_progress = data.get("sabotage", 0.0)
	is_sabotaged = data.get("sabotaged", false)
