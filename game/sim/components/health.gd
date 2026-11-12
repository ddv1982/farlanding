class_name Health
extends Node
## Hit points of a unit or building. `take()` applies damage that already went
## through the DamageTable, announces it on `Events.entity_damaged` and, the first
## time health reaches zero, emits `died` (SimWorld then removes the entity).

## Health changed; `fraction` in [0, 1]. The entity relays it to its visual.
signal changed(fraction: float)
## Health reached zero. Emitted once.
signal died(attacker: Node3D)
## Damage was taken (after armour). `attacker` may be null.
signal damaged(amount: float, attacker: Node3D)

const SAVE_VERSION: int = 1

var max_health: float = 100.0
var current: float = 100.0
## Column of the DamageTable this entity is hit on.
var armour_type: StringName = DamageTable.ARMOUR_LIGHT
## The entity root reported in `Events.entity_damaged` (the parent by default).
var entity: Node3D = null

var _dead: bool = false


func setup(p_max_health: float, p_armour_type: StringName, p_entity: Node3D = null) -> void:
	max_health = maxf(p_max_health, 1.0)
	current = max_health
	armour_type = p_armour_type
	entity = p_entity


func is_dead() -> bool:
	return _dead


## Share of health left, in [0, 1].
func fraction() -> float:
	return clampf(current / max_health, 0.0, 1.0)


## Takes `amount` damage (already multiplied by armour). Returns the damage taken,
## which is less than `amount` when it was the killing blow.
func take(amount: float, attacker: Node3D = null) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var taken: float = minf(amount, current)
	current -= taken
	changed.emit(fraction())
	damaged.emit(taken, attacker)
	var root: Node3D = entity if entity != null else get_parent() as Node3D
	if root != null:
		Events.entity_damaged.emit(root, taken, attacker)
	if current <= 0.0:
		current = 0.0
		_dead = true
		died.emit(attacker)
	return taken


## Restores up to `amount` health (repairs). Does nothing once dead.
func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	changed.emit(fraction())


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "current": current, "max": max_health}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Health save version")
	max_health = data.get("max", max_health)
	current = data.get("current", current)
	_dead = current <= 0.0
	changed.emit(fraction())
