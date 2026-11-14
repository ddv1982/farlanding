class_name Carrier
extends OrderHandler
## Lets a unit pick up a carriable prop (an Antecedent artefact, ADR 0014) and carry
## it. A `carry` order walks to the prop and lifts it; the order then ends and the
## unit carries it wherever it is sent. While carrying, the unit moves at
## SPEED_FACTOR (never faster than MAX_SPEED) and does not fight. It drops the prop
## where it stands when it dies (anyone may pick it up again). A prop another unit of
## the same faction carries is left alone; one an enemy carries must be won back by
## killing the carrier.

const KIND: StringName = &"carry"
## A prop is lifted from this far beyond the unit's and the prop's radius.
const REACH: float = 2.0
## Top speed while carrying is multiplied by this.
const SPEED_FACTOR: float = 0.6
## Nobody carries faster than this (m/s): a Ranger's pace when carrying. Without it a
## Kite ran an artefact across Thalassa in under two minutes (ADR 0018).
const MAX_SPEED: float = 3.6
## Path attempts to reach the prop before giving up.
const MAX_ATTEMPTS: int = 3

## What the unit carries, or null.
var cargo: Prop = null

var _attempts: int = 0
## Saved id of the cargo, resolved by resume() / resolve_cargo().
var _cargo_id: int = -1


func handles() -> Array[StringName]:
	return [KIND]


## Speed scale of a `def` unit while it carries.
static func speed_scale(def: UnitDef) -> float:
	if def == null or def.move_speed <= 0.0:
		return SPEED_FACTOR
	return minf(SPEED_FACTOR, MAX_SPEED / def.move_speed)


## True while it carries something.
func is_carrying() -> bool:
	return is_instance_valid(cargo)


func begin(order: Order) -> bool:
	var prop: Prop = order.target_entity as Prop
	if not can_lift(prop):
		return false
	if cargo == prop:
		return false
	_attempts = 0
	unit.locomotion.move_to(prop.position)
	return true


func step(order: Order, _dt: float) -> bool:
	var prop: Prop = order.target_entity as Prop
	if not can_lift(prop):
		return true
	var reach: float = unit.def.radius + prop.radius() + REACH
	var at: Vector3 = unit.sim_position()
	if Vector2(prop.position.x - at.x, prop.position.z - at.z).length() <= reach:
		pick_up(prop)
		return true
	if unit.locomotion.is_waiting_for_tide():
		return false  # the way is under water: the order holds until the sea falls
	if not unit.locomotion.is_travelling():
		_attempts += 1
		if _attempts > MAX_ATTEMPTS:
			return true
		unit.locomotion.move_to(prop.position)
	return false


func end(_order: Order) -> void:
	_attempts = 0


## True if this unit may lift `prop` now: a carriable prop nobody carries (this unit
## carries nothing else).
func can_lift(prop: Variant) -> bool:
	if not is_instance_valid(prop) or not prop is Prop:
		return false
	var candidate: Prop = prop
	return candidate.is_carriable() and not candidate.is_carried() and not is_carrying()


## Lifts `prop` (it follows the unit from now on). `announce` false: a load puts it
## back in the carrier's hands without telling anyone.
func pick_up(prop: Prop, announce: bool = true) -> void:
	cargo = prop
	prop.carrier = unit
	prop.lifted = true
	var previous: int = prop.last_faction
	prop.last_faction = unit.faction
	unit.locomotion.set_extra_scale(&"carrying", speed_scale(unit.def))
	prop.carried_changed.emit(unit)
	if not announce:
		return
	Events.cargo_picked_up.emit(unit, prop)
	if _is_players():
		Events.ui_feedback.emit(&"artefact_pickup")
		if previous != unit.faction:
			# Ours (again): first lifted, or won back from the enemy.
			Events.advisor_alert.emit(&"artefact_secured")
	elif previous != unit.faction and unit.faction != Factions.CUSTODIANS:
		Events.advisor_alert.emit(&"artefact_taken")


## Puts the cargo down where the unit stands.
func drop() -> void:
	if not is_carrying():
		cargo = null
		return
	var prop: Prop = cargo
	cargo = null
	prop.carrier = null
	prop.position = prop.ground_point(unit.sim_position())
	prop.is_visible_to_player = true
	if unit.locomotion != null:
		unit.locomotion.set_extra_scale(&"carrying", 1.0)
	prop.carried_changed.emit(null)
	Events.cargo_dropped.emit(unit, prop)
	if _is_players():
		Events.ui_feedback.emit(&"artefact_drop")


func _is_players() -> bool:
	return unit.world != null and unit.faction == unit.world.player_faction


## The carrier died: the cargo falls where it stood.
func on_carrier_died(_attacker: Node3D) -> void:
	drop()


## After a load: the saved cargo becomes the prop again and is lifted (the order may
## be anything; the carry order itself ends on lifting).
func resolve_cargo(lookup: Callable) -> void:
	if _cargo_id < 0:
		return
	var found: Node3D = lookup.call(_cargo_id)
	var prop: Prop = found as Prop
	_cargo_id = -1
	if prop != null and prop.is_carriable() and not prop.is_carried():
		pick_up(prop, false)


func to_dict() -> Dictionary:
	return {"cargo": Order.entity_id_of(cargo), "attempts": _attempts}


func from_dict(data: Dictionary) -> void:
	_cargo_id = data.get("cargo", -1)
	_attempts = data.get("attempts", 0)
