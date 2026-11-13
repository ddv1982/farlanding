class_name Unit
extends Node3D
## A mobile unit: a thin root holding its definition and faction, composed of
## component nodes (Locomotion, UnitOrders, and OrderHandlers such as Harvester,
## Builder or Scanner) plus a presentation child. Health (always), a Weapon (when the
## def has one), a Scanner (when it can scan) and a Dormancy (Custodians that start
## dormant) are added from the def when it enters the tree. Spawned by SimWorld, which
## sets `def`, `faction`, `world` and `entity_id` before adding it to the tree.
##
## Armed units fight on their own: idle ones engage enemies they can see within
## weapon range, walk up to ones a little further (never more than AUTO_CHASE from
## where they stood, then walk back), and return fire when hit. Moving units hold
## fire unless their weapon fires on the move.

## Health changed, `fraction` in [0, 1]. The visual shows it.
signal health_changed(fraction: float)
## The weapon aims at `point` (every tick while it has a target).
signal aim_changed(point: Vector3)
## The weapon stopped aiming.
signal aim_cleared
## A dormant Custodian woke up.
signal woke

const SAVE_VERSION: int = 4
const GROUP: StringName = &"units"
## How far beyond weapon range an idle unit walks to engage an enemy it sees.
const AUTO_CHASE: float = 8.0
## How far beyond weapon range a unit walks to answer fire from an enemy it sees.
const RETURN_FIRE_CHASE: float = 14.0
## Above this speed (m/s) a unit counts as moving and holds fire.
const MOVING_SPEED: float = 0.3

## Read by audio, UI and selection (`def.sound_set`, `def.display_name`).
var def: UnitDef
var faction: int = 0
## The world this unit lives in (null in some tests).
var world: SimWorld = null
## Save id, unique within the mission; -1 until spawned.
var entity_id: int = -1
var locomotion: Locomotion = null
var orders: UnitOrders = null
var harvester: Harvester = null
var builder: Builder = null
## Null for units that cannot scan.
var scanner: Scanner = null
## Null for units that are never dormant.
var dormancy: Dormancy = null
var health: Health = null
## Null for unarmed units.
var weapon: Weapon = null
## False while the player cannot see this unit (it is hidden then). Read by audio
## and UI; always true for the player's own units.
var is_visible_to_player: bool = true
## True from the moment its health ran out.
var is_dead: bool:
	get:
		return health != null and health.is_dead()
## Current ground speed in m/s. Read by audio for movement loops.
var speed: float:
	get:
		return locomotion.mover.speed if locomotion != null else 0.0
## True while a dormant Custodian has not been disturbed. Read by audio and UI.
var is_dormant: bool:
	get:
		return dormancy != null and dormancy.is_dormant
## True while scanning a discovery site. Read by audio and UI.
var is_scanning: bool:
	get:
		return scanner != null and scanner.is_scanning()
## True while mining at a deposit. Read by audio for the mining loop.
var is_harvesting: bool:
	get:
		return harvester != null and harvester.is_mining()

var _handlers: Array[OrderHandler] = []
## Who last hit this unit, answered once it can be seen (it may only be exposed by
## its own shot on the next vision update).
var _attacker: Node3D = null


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if def != null and def.can_scan() and find_children("*", "Scanner", false).is_empty():
		var added: Scanner = Scanner.new()
		added.name = &"Scanner"
		add_child(added)
	for child: Node in get_children():
		if child is Locomotion:
			locomotion = child
		elif child is UnitOrders:
			orders = child
		elif child is OrderHandler:
			_handlers.append(child)
			if child is Harvester:
				harvester = child
			elif child is Builder:
				builder = child
			elif child is Scanner:
				scanner = child
		elif child is Health:
			health = child
		elif child is Weapon:
			weapon = child
	if orders != null:
		orders.setup(locomotion)
		orders.can_target = _can_target
		for handler: OrderHandler in _handlers:
			handler.setup(self)
			orders.add_handler(handler)
	if def != null:
		_add_combat_components()
	if def != null and def.starts_dormant:
		dormancy = Dormancy.new()
		dormancy.name = &"Dormancy"
		add_child(dormancy)
		dormancy.setup(self)
		dormancy.woke.connect(woke.emit)


## One sim tick: orders first (they may start a new path), then movement, then the
## weapon. Dead units do nothing.
func sim_tick(dt: float) -> void:
	if is_dead:
		return
	if dormancy != null and dormancy.is_dormant:
		dormancy.tick()
		return
	if orders != null:
		orders.tick(dt)
	if locomotion != null:
		locomotion.tick(dt)
	if weapon != null:
		_tick_weapon(dt)


## Simulation position (leads the drawn node by up to one tick).
func sim_position() -> Vector3:
	return locomotion.mover.position if locomotion != null else global_position


## True while the unit is under way (not standing or braking to a halt).
func is_moving() -> bool:
	if locomotion == null:
		return false
	return locomotion.is_travelling() or locomotion.mover.speed > MOVING_SPEED


func to_dict() -> Dictionary:
	var handlers: Dictionary = {}
	for handler: OrderHandler in _handlers:
		handlers[String(handler.name)] = handler.to_dict()
	return {
		"version": SAVE_VERSION,
		"def": def.resource_path if def != null else "",
		"faction": faction,
		"entity_id": entity_id,
		"locomotion": locomotion.to_dict() if locomotion != null else {},
		"orders": orders.to_dict() if orders != null else {},
		"handlers": handlers,
		"health": health.to_dict() if health != null else {},
		"weapon": weapon.to_dict() if weapon != null else {},
		"dormancy": dormancy.to_dict() if dormancy != null else {},
	}


## Restores component state; `def` and `faction` are set by the spawner.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported Unit save version")
	faction = data.get("faction", faction)
	entity_id = data.get("entity_id", entity_id)
	var locomotion_data: Dictionary = data.get("locomotion", {})
	if locomotion != null and not locomotion_data.is_empty():
		locomotion.from_dict(locomotion_data)
	var orders_data: Dictionary = data.get("orders", {})
	if orders != null and not orders_data.is_empty():
		orders.from_dict(orders_data)
	var handlers: Dictionary = data.get("handlers", {})
	for handler: OrderHandler in _handlers:
		var handler_data: Dictionary = handlers.get(String(handler.name), {})
		if not handler_data.is_empty():
			handler.from_dict(handler_data)
	var health_data: Dictionary = data.get("health", {})
	if health != null and not health_data.is_empty():
		health.from_dict(health_data)
	var weapon_data: Dictionary = data.get("weapon", {})
	if weapon != null and not weapon_data.is_empty():
		weapon.from_dict(weapon_data)
	var dormancy_data: Dictionary = data.get("dormancy", {})
	if dormancy != null and not dormancy_data.is_empty():
		dormancy.from_dict(dormancy_data)


func _add_combat_components() -> void:
	if health == null:
		health = Health.new()
		health.name = &"Health"
		add_child(health)
	health.setup(def.max_health, def.armour(), self)
	health.changed.connect(health_changed.emit)
	health.damaged.connect(_on_damaged)
	if def.weapon != null and weapon == null:
		weapon = Weapon.new()
		weapon.name = &"Weapon"
		add_child(weapon)
	if weapon == null:
		return
	weapon.setup(def.weapon, self, faction, world.combat if world != null else null)
	weapon.aim_changed.connect(aim_changed.emit)
	weapon.aim_cleared.connect(aim_cleared.emit)
	if orders != null:
		orders.engage_distance = maxf(def.weapon.max_range - UnitOrders.ENGAGE_MARGIN, 1.0)


func _tick_weapon(dt: float) -> void:
	var moving: bool = is_moving()
	var idle: bool = orders == null or orders.is_idle()
	var ordered: Node3D = orders.attack_target() if orders != null else null
	var auto: bool = idle or orders.is_auto_attacking() or weapon.def.fire_while_moving
	var body_yaw: float = locomotion.mover.yaw if locomotion != null else rotation.y
	weapon.tick(
		dt,
		sim_position(),
		body_yaw,
		ordered,
		auto,
		not moving or weapon.def.fire_while_moving,
		AUTO_CHASE if idle else 0.0
	)
	if weapon.target != null and not weapon.def.turret and not moving and locomotion != null:
		locomotion.face(AttackCommand.position_of(weapon.target))
	if not idle or orders == null or weapon.target != null:
		return
	if not is_instance_valid(_attacker):
		_attacker = null
	elif _answer(_attacker):
		return
	if weapon.sighted != null:
		orders.engage(weapon.sighted, sim_position(), AUTO_CHASE)


## Hit: remember who did it; an idle unit answers as soon as it can see them.
func _on_damaged(_amount: float, attacker: Node3D) -> void:
	if dormancy != null:
		dormancy.wake()
	if weapon == null or orders == null or is_dead or attacker == null:
		return
	_attacker = attacker
	if orders.is_idle():
		_answer(attacker)


## Shoots back at `attacker`, walking up to it if it is a little out of range.
## Returns true if it did; forgets attackers that are gone.
func _answer(attacker: Node3D) -> bool:
	if not Combat.is_alive(attacker):
		_attacker = null
		return false
	if not _can_target(attacker):
		return false
	_attacker = null
	if weapon.in_range(attacker, sim_position()):
		weapon.target = attacker
		return true
	orders.engage(attacker, sim_position(), RETURN_FIRE_CHASE)
	return true


func _can_target(target: Variant) -> bool:
	if world != null and world.combat != null:
		return world.combat.can_target(faction, target)
	return AttackCommand.is_valid_target(target, faction)
