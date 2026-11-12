class_name Weapon
extends Node
## A gun on a unit or building. Every sim tick its carrier calls `tick()` with its
## situation: the target of its attack order (if any), whether it may pick targets
## of its own and whether it may fire now. The weapon chooses a target, turns its
## turret (or relies on the body facing it), and fires on cooldown through the
## mission's Combat system. Target acquisition is staggered: a weapon looks for new
## targets once every ACQUIRE_PERIOD ticks, through Combat's spatial grid.

## Aiming at `point` (emitted every tick while it has a target).
signal aim_changed(point: Vector3)
## No target any more.
signal aim_cleared
## A shot (one salvo) left the weapon.
signal fired(target: Node3D)

const SAVE_VERSION: int = 1
## Ticks between looks for a new target.
const ACQUIRE_PERIOD: int = 3
## Cooldown left below this counts as ready (absorbs float drift of 0.1 s steps).
const READY_EPSILON: float = 0.001

var def: WeaponDef
## The unit or building carrying the weapon.
var carrier: Node3D = null
var faction: int = 0
## The combat system shots go through (null: the weapon cannot fire).
var combat: Combat = null
## What it is shooting at, or null.
var target: Node3D = null
## The nearest visible enemy found beyond reach on the last look (idle units walk
## up to it), or null.
var sighted: Node3D = null
## World yaw the weapon points at (the turret's, or the body's without a turret).
var aim_yaw: float = 0.0
## Seconds until it may fire again.
var cooldown_left: float = 0.0

var _aiming: bool = false
var _stagger: int = 0


func setup(p_def: WeaponDef, p_carrier: Node3D, p_faction: int, p_combat: Combat) -> void:
	def = p_def
	carrier = p_carrier
	faction = p_faction
	combat = p_combat
	var id: int = Order.entity_id_of(p_carrier)
	_stagger = absi(id) % ACQUIRE_PERIOD


## One sim tick. `position` and `body_yaw` are the carrier's; `ordered` is the target
## of its attack order or null; `may_auto` lets it choose targets itself; `may_fire`
## is false while it must hold fire (moving, unpowered). `sight_reach` widens the
## look beyond range to fill `sighted`.
func tick(
	dt: float,
	position: Vector3,
	body_yaw: float,
	ordered: Node3D,
	may_auto: bool,
	may_fire: bool,
	sight_reach: float = 0.0,
) -> void:
	cooldown_left = maxf(cooldown_left - dt, 0.0)
	sighted = null
	target = _choose(position, ordered, may_auto, sight_reach)
	if target == null:
		if def.turret:
			aim_yaw = rotate_toward(aim_yaw, body_yaw, deg_to_rad(def.turn_speed) * dt)
		else:
			aim_yaw = body_yaw
		if _aiming:
			_aiming = false
			aim_cleared.emit()
		return
	var point: Vector3 = aim_point(target)
	var wanted: float = Mover.yaw_for(point - position)
	if def.turret:
		aim_yaw = wrapf(rotate_toward(aim_yaw, wanted, deg_to_rad(def.turn_speed) * dt), -PI, PI)
	else:
		aim_yaw = body_yaw
	_aiming = true
	aim_changed.emit(point)
	var aligned: bool = absf(angle_difference(aim_yaw, wanted)) <= deg_to_rad(def.fire_arc)
	if may_fire and aligned and cooldown_left <= READY_EPSILON and combat != null:
		_fire(position, point)


## True if `entity`'s body is within the weapon's range of `position`.
func in_range(entity: Node3D, position: Vector3) -> bool:
	return Combat.reach_to(entity, position) <= def.max_range


## Where to aim at `entity`: a metre above its origin.
static func aim_point(entity: Node3D) -> Vector3:
	return AttackCommand.position_of(entity) + Vector3.UP * UnitOrders.AIM_HEIGHT


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"cooldown": cooldown_left,
		"aim_yaw": aim_yaw,
		"target": Order.entity_id_of(target),
	}


## Restores cooldown and aim; the target is picked again on the next look.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Weapon save version")
	cooldown_left = data.get("cooldown", 0.0)
	aim_yaw = data.get("aim_yaw", 0.0)


func _choose(position: Vector3, ordered: Node3D, may_auto: bool, sight_reach: float) -> Node3D:
	if ordered != null and in_range(ordered, position) and _may_target(ordered):
		return ordered
	if not may_auto or combat == null:
		return null
	if (
		target != null
		and target != ordered
		and is_instance_valid(target)
		and in_range(target, position)
		and combat.can_target(faction, target)
	):
		return target
	if (combat.tick_count + _stagger) % ACQUIRE_PERIOD != 0:
		return null
	return _look(position, sight_reach)


## One look through the grid: the nearest enemy in range, else null with `sighted`
## set to one within `sight_reach` beyond it.
func _look(position: Vector3, sight_reach: float) -> Node3D:
	var found: Node3D = combat.find_target(faction, position, def.max_range + sight_reach)
	if found != null and not in_range(found, position):
		sighted = found
		return null
	return found


## Without a combat system (bare tests) any live enemy may be aimed at.
func _may_target(entity: Node3D) -> bool:
	if combat != null:
		return combat.can_target(faction, entity)
	return AttackCommand.is_valid_target(entity, faction)


func _fire(position: Vector3, point: Vector3) -> void:
	cooldown_left = def.cooldown
	var turn: Basis = Basis(Vector3.UP, aim_yaw)
	for i: int in def.salvo:
		var side: float = (i - (def.salvo - 1) * 0.5) * def.salvo_spacing
		var muzzle: Vector3 = position + turn * (def.muzzle + Vector3(side, 0.0, 0.0))
		combat.fire(def, carrier, faction, muzzle, target, point)
	fired.emit(target)
