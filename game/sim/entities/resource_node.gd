class_name ResourceNode
extends Node3D
## A resource node on the map: an Alloy deposit (mined by Haulers, runs out) or a
## Flux vent (tapped by a Flux Tap built on it, never runs out). Neutral: it belongs
## to no faction. Spawned by SimWorld.

## Share of the deposit left changed, in [0, 1]. The visual shrinks with it.
signal remaining_changed(fraction: float)
## The sea covered the node (`flooded`) or left it. Presentation may tint it.
signal flooded_changed(flooded: bool)
## An erupting vent's pressure changed (0..1), or its warning began or ended
## (`seconds_to_burst` < 0: none announced). Presentation shows a gauge (ADR 0015).
signal pressure_changed(pressure: float, seconds_to_burst: float)
## The vent was named the next to erupt (a geological forecast) or no longer is.
signal forecast_changed(next_to_erupt: bool)

const SAVE_VERSION: int = 1
const GROUP: StringName = &"resource_nodes"

var def: ResourceNodeDef
## Save id, unique within the mission; -1 until spawned.
var entity_id: int = -1
## Units of resource left (deposits).
var remaining: int = 0
## The Flux Tap standing on this vent, or null.
var tap: Building = null
## False while the player cannot see this node now. Read by audio and UI.
var is_visible_to_player: bool = true
## True while the sea covers it: nobody mines it until the sea falls (ADR 0014). Not
## saved: the world's FloodSystem sets it again from the sea level.
var is_flooded: bool = false
## An erupting vent's pressure, 0..1 (ADR 0015). Not saved here: the planet's
## EruptionSystem saves it and sets it again. Read by UI, presentation and the AI.
var pressure: float = 0.0
## Seconds until an announced eruption; -1 while none is announced.
var seconds_to_burst: float = -1.0
## True while a forecast the player holds names this vent the next to erupt.
var is_next_to_erupt: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


func setup(p_def: ResourceNodeDef) -> void:
	def = p_def
	remaining = def.amount


func _ready() -> void:
	remaining_changed.emit(fraction_left())


func resource() -> StringName:
	return def.resource if def != null else &""


## True for an Alloy deposit that still holds something.
func is_minable() -> bool:
	return def != null and def.resource == &"alloy" and remaining > 0


func is_depleted() -> bool:
	return def != null and def.amount > 0 and remaining <= 0


## Marks the node covered by the sea or dry again (the world's FloodSystem).
func set_flooded(flooded: bool) -> void:
	if flooded == is_flooded:
		return
	is_flooded = flooded
	flooded_changed.emit(flooded)


## True for a vent the planet's eruption rule plays (it builds pressure and erupts).
func erupts() -> bool:
	return def != null and def.resource == &"flux" and def.erupts


## Sets the pressure shown (the planet's EruptionSystem); announces a visible change.
func set_pressure(value: float, burst_in: float) -> void:
	var stepped: float = snappedf(clampf(value, 0.0, 1.0), 0.01)
	var seconds: float = ceilf(burst_in) if burst_in >= 0.0 else -1.0
	if is_equal_approx(stepped, pressure) and is_equal_approx(seconds, seconds_to_burst):
		return
	pressure = stepped
	seconds_to_burst = seconds
	pressure_changed.emit(pressure, seconds_to_burst)


## Marks the vent as named (or no longer named) the next to erupt.
func set_next_to_erupt(next: bool) -> void:
	if next == is_next_to_erupt:
		return
	is_next_to_erupt = next
	forecast_changed.emit(next)


## True for a vent without a Flux Tap on it.
func is_free_vent() -> bool:
	return def != null and def.resource == &"flux" and not is_instance_valid(tap)


## Share left in [0, 1] (always 1 for endless nodes).
func fraction_left() -> float:
	if def == null or def.amount <= 0:
		return 1.0
	return clampf(float(remaining) / def.amount, 0.0, 1.0)


## Takes up to `amount` from the deposit; returns what was taken.
func take(amount: int) -> int:
	var taken: int = mini(maxi(amount, 0), remaining)
	if taken <= 0:
		return 0
	remaining -= taken
	remaining_changed.emit(fraction_left())
	return taken


## Ground area kept clear of buildings and blocked for movement (world X/Z).
func blocked_area() -> Rect2:
	var half: float = def.radius * 0.8
	return Rect2(position.x - half, position.z - half, half * 2.0, half * 2.0)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"def": def.resource_path if def != null else "",
		"entity_id": entity_id,
		"position": var_to_str(position),
		"remaining": remaining,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported ResourceNode save version")
	entity_id = data.get("entity_id", entity_id)
	remaining = data.get("remaining", remaining)
	remaining_changed.emit(fraction_left())
