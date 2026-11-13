class_name Harvester
extends OrderHandler
## Lets a unit mine Alloy. A `harvest` order names a deposit and runs a cycle until
## nothing is left to mine:
##
##   to_deposit -> mining -> to_dock -> unloading -> to_deposit ...
##
## The unit unloads at its faction's nearest drop-off of the highest priority (a
## Refinery's dock, or the Lander until a Refinery exists); with none it waits and
## asks again. When the deposit runs out it moves on to the nearest other deposit
## within `rules.deposit_search_radius`, or the order ends. While the sea covers the
## deposit (a tidal map, ADR 0014) it is not mined: the hauler delivers what it carries,
## moves on to a dry deposit within the search radius, or else waits on ground the sea
## never reaches and goes back once the deposit is dry.

const KIND: StringName = &"harvest"
const STATE_IDLE: StringName = &"idle"
const STATE_TO_DEPOSIT: StringName = &"to_deposit"
const STATE_MINING: StringName = &"mining"
const STATE_TO_DOCK: StringName = &"to_dock"
const STATE_UNLOADING: StringName = &"unloading"
const STATE_WAITING: StringName = &"waiting"
## Waiting on high ground for the sea to leave the deposit.
const STATE_TIDE: StringName = &"tide"
## Seconds between looks at a flooded deposit while waiting.
const TIDE_LOOK_SECONDS: float = 1.0
## Mining starts this far (metres) beyond the deposit's radius plus the unit's own.
const DEPOSIT_REACH: float = 3.5
## Unloading starts within this distance of the dock point.
const DOCK_REACH: float = 4.0
## Seconds between looks for a drop-off when there is none.
const WAIT_SECONDS: float = 2.0
## Path attempts to reach a deposit or dock before giving up on it.
const MAX_ATTEMPTS: int = 3

var state: StringName = STATE_IDLE
## Alloy carried.
var cargo: int = 0
var deposit: ResourceNode = null
var dock: Building = null
## Round trips finished (deliveries), for tests and the debug overlay.
var deliveries: int = 0

var _timer: float = 0.0
var _attempts: int = 0
## Saved ids restored by from_dict, resolved by resume() (or the next begin()).
var _deposit_id: int = -1
var _dock_id: int = -1


func handles() -> Array[StringName]:
	return [KIND]


## True while mining at a deposit.
func is_mining() -> bool:
	return state == STATE_MINING


func begin(order: Order) -> bool:
	var target: ResourceNode = order.target_entity as ResourceNode
	deposit = target if _is_minable(target) else _find_deposit(order.target_position)
	if deposit == null and cargo <= 0:
		return false
	order.target_entity = deposit
	if cargo >= unit.carry_capacity or deposit == null:
		_go_dock()
	else:
		_go_deposit()
	return true


func step(order: Order, dt: float) -> bool:
	match state:
		STATE_TO_DEPOSIT:
			return _step_to_deposit(order)
		STATE_MINING:
			return _step_mining(order, dt)
		STATE_TO_DOCK:
			return _step_to_dock()
		STATE_UNLOADING:
			return _step_unloading(order, dt)
		STATE_WAITING, STATE_TIDE:
			return _step_waiting(order, dt)
	return true


func end(_order: Order) -> void:
	state = STATE_IDLE
	dock = null


## A load: the deposit and dock saved by id become nodes again; the cycle carries on
## in its saved state (a vanished deposit or dock is replaced by the usual rules).
func resume(order: Order) -> void:
	if unit.world == null:
		return
	if _deposit_id >= 0:
		deposit = unit.world.entity(_deposit_id) as ResourceNode
	elif order.target_entity is ResourceNode:
		deposit = order.target_entity
	_deposit_id = -1
	if deposit != null:
		order.target_entity = deposit
	dock = unit.world.entity(_dock_id) as Building if _dock_id >= 0 else null
	_dock_id = -1


func to_dict() -> Dictionary:
	return {
		"state": state,
		"cargo": cargo,
		"deposit": Order.entity_id_of(deposit),
		"dock": Order.entity_id_of(dock),
		"timer": _timer,
		"attempts": _attempts,
		"deliveries": deliveries,
	}


func from_dict(data: Dictionary) -> void:
	state = data.get("state", STATE_IDLE)
	cargo = data.get("cargo", 0)
	_deposit_id = data.get("deposit", -1)
	_dock_id = data.get("dock", -1)
	_timer = data.get("timer", 0.0)
	_attempts = data.get("attempts", 0)
	deliveries = data.get("deliveries", 0)


func _step_to_deposit(order: Order) -> bool:
	if not _is_minable(deposit):
		return _after_depletion(order)
	if deposit.is_flooded:
		return _avoid_flood(order)
	if _near(deposit.position, deposit.def.radius + unit.def.radius + DEPOSIT_REACH):
		unit.locomotion.stop()
		unit.locomotion.face(deposit.position)
		state = STATE_MINING
		_timer = unit.mine_time
		return false
	if unit.locomotion.is_waiting_for_tide():
		return false  # the way is under water: hold until the sea falls
	if not unit.locomotion.is_travelling():
		_attempts += 1
		if _attempts > MAX_ATTEMPTS:
			return _give_up_deposit(order)
		unit.locomotion.move_to(deposit.position)
	return false


func _step_mining(order: Order, dt: float) -> bool:
	if not _is_minable(deposit):
		return _after_depletion(order)
	if deposit.is_flooded:
		return _avoid_flood(order)
	_timer -= dt
	if _timer > 0.0:
		return false
	cargo += deposit.take(unit.carry_capacity - cargo)
	if deposit.is_depleted() and unit.world != null:
		unit.world.deplete(deposit, unit.faction)
	_go_dock()
	return false


func _step_to_dock() -> bool:
	if dock == null or not is_instance_valid(dock) or not dock.accepts_alloy_from(unit.faction):
		_go_dock()
		return false
	if _near(dock.dock_position(), DOCK_REACH):
		unit.locomotion.stop()
		state = STATE_UNLOADING
		_timer = unit.def.unload_time
		return false
	if unit.locomotion.is_waiting_for_tide():
		return false  # the way is under water: hold until the sea falls
	if not unit.locomotion.is_travelling():
		_attempts += 1
		if _attempts > MAX_ATTEMPTS:
			state = STATE_WAITING
			_timer = WAIT_SECONDS
			_attempts = 0
		else:
			unit.locomotion.move_to(dock.dock_position())
	return false


func _step_unloading(order: Order, dt: float) -> bool:
	_timer -= dt
	if _timer > 0.0:
		return false
	if unit.world != null:
		unit.world.economy.deliver(unit, cargo)
	cargo = 0
	deliveries += 1
	if _is_minable(deposit):
		_go_deposit()
		return false
	return _after_depletion(order)


## The sea covers the deposit: unload what is carried, else move on to a dry deposit
## within the search radius, else wait on ground the sea never reaches.
func _avoid_flood(order: Order) -> bool:
	if cargo > 0:
		_go_dock()
		return false
	var next: ResourceNode = null
	if unit.world != null:
		next = unit.world.nearest_deposit(
			deposit.position, unit.world.rules.deposit_search_radius, deposit
		)
	if next != null:
		deposit = next
		order.target_entity = next
		order.target_position = next.position
		_go_deposit()
		return false
	state = STATE_TIDE
	_timer = TIDE_LOOK_SECONDS
	var shelter: Vector3 = Vector3.INF
	if unit.world != null and unit.world.flood != null:
		shelter = unit.world.flood.nearest_dry(
			unit.sim_position(), unit.world.conditions.high_water
		)
	if shelter != Vector3.INF:
		unit.locomotion.move_to(shelter)
	else:
		unit.locomotion.stop()
	return false


## Waiting for a drop-off to appear, or for the sea to leave the deposit.
func _step_waiting(order: Order, dt: float) -> bool:
	if state == STATE_WAITING:
		_timer -= dt
		if _timer <= 0.0:
			_go_dock()
		return false
	if not _is_minable(deposit):
		return _after_depletion(order)
	_timer -= dt
	if _timer > 0.0:
		return false
	_timer = TIDE_LOOK_SECONDS
	if not deposit.is_flooded:
		_go_deposit()
	return false


## The deposit is gone: unload what is carried, then move on to another or stop.
## Returns true when the order is done.
func _after_depletion(order: Order) -> bool:
	if cargo > 0:
		_go_dock()
		return false
	var from: Vector3 = deposit.position if is_instance_valid(deposit) else order.target_position
	var next: ResourceNode = _find_deposit(from)
	if next == null:
		return true
	deposit = next
	order.target_entity = next
	order.target_position = next.position
	_go_deposit()
	return false


## The deposit cannot be reached: try the nearest other one, or end the order.
func _give_up_deposit(order: Order) -> bool:
	if cargo > 0:
		_go_dock()
		return false
	var next: ResourceNode = null
	if unit.world != null:
		next = unit.world.nearest_deposit(
			deposit.position, unit.world.rules.deposit_search_radius, deposit
		)
	if next == null:
		return true
	deposit = next
	order.target_entity = next
	order.target_position = next.position
	_go_deposit()
	return false


func _go_deposit() -> void:
	state = STATE_TO_DEPOSIT
	_attempts = 0
	unit.locomotion.move_to(deposit.position)


func _go_dock() -> void:
	dock = unit.world.nearest_dropoff(unit.faction, unit.sim_position()) if unit.world else null
	_attempts = 0
	if dock == null:
		state = STATE_WAITING
		_timer = WAIT_SECONDS
		return
	state = STATE_TO_DOCK
	unit.locomotion.move_to(dock.dock_position())


func _find_deposit(near: Vector3) -> ResourceNode:
	if unit.world == null:
		return null
	if _deposit_id >= 0:
		var saved: ResourceNode = unit.world.entity(_deposit_id) as ResourceNode
		_deposit_id = -1
		if _is_minable(saved):
			return saved
	return unit.world.nearest_deposit(near, unit.world.rules.deposit_search_radius)


func _near(point: Vector3, reach: float) -> bool:
	var position: Vector3 = unit.sim_position()
	return Vector2(point.x - position.x, point.z - position.z).length() <= reach


static func _is_minable(node: Variant) -> bool:
	if not is_instance_valid(node) or not node is ResourceNode:
		return false
	var resource_node: ResourceNode = node
	return resource_node.is_inside_tree() and resource_node.is_minable()
