class_name Saboteur
extends OrderHandler
## Lets a unit (the Wisp) sabotage enemy buildings. A `sabotage` order names a
## finished enemy building: the unit walks to the nearest point of its edge, stops
## and works; the building's `sabotage_progress` grows by 1 / `sabotage_time` per
## second (several saboteurs add up, progress already made stays). At 1 the building
## is sabotaged for good: it stops working (no production, no power, no weapon) and
## `Events.entity_sabotaged` fires. Standing still while working keeps a Wisp cloaked.

const KIND: StringName = &"sabotage"
const MAX_ATTEMPTS: int = 6
const RETRY_SLIDE: float = 3.0

## The building being approached or worked on (null when not sabotaging).
var target: Building = null

var _working: bool = false
var _attempts: int = 0


func handles() -> Array[StringName]:
	return [KIND]


## True while working on a building (read by audio and UI).
func is_working() -> bool:
	return _working


## True if `building` is something this unit may sabotage: a finished, working
## building of another (non-Custodian) faction. Never an Antecedent engine: it changes
## hands and would stay dead for whoever took it.
static func can_sabotage(building: Variant, faction: int) -> bool:
	if not is_instance_valid(building) or not building is Building:
		return false
	var node: Building = building
	return (
		node.is_inside_tree()
		and not node.is_dead
		and node.faction != faction
		and not Factions.is_custodian(node.faction)
		and node.machine == null
		and node.is_operational()
	)


func begin(order: Order) -> bool:
	if not can_sabotage(order.target_entity, unit.faction):
		return false
	target = order.target_entity
	_working = false
	_attempts = 0
	_approach()
	return true


func step(_order: Order, dt: float) -> bool:
	if not can_sabotage(target, unit.faction):
		return true
	if not _in_range():
		_working = false
		if unit.locomotion.is_waiting_for_tide():
			return false  # the way is under water: hold until the sea falls
		if not unit.locomotion.is_travelling():
			_attempts += 1
			if _attempts > MAX_ATTEMPTS:
				return true
			_approach()
		return false
	if unit.locomotion.is_travelling():
		unit.locomotion.stop()
	unit.locomotion.face(target.position)
	_working = true
	target.sabotage_progress = minf(target.sabotage_progress + dt / unit.def.sabotage_time, 1.0)
	if target.sabotage_progress < 1.0:
		return false
	var done: Building = target
	_working = false
	target = null
	if unit.world != null:
		unit.world.sabotage(done, unit)
	else:
		done.sabotage()
	return true


func end(_order: Order) -> void:
	_working = false
	target = null


## A load: the target is the restored order's; progress made is kept on the building.
func resume(order: Order) -> void:
	target = (
		order.target_entity as Building if can_sabotage(order.target_entity, unit.faction) else null
	)
	_working = false


func to_dict() -> Dictionary:
	return {"target": Order.entity_id_of(target), "attempts": _attempts}


func from_dict(data: Dictionary) -> void:
	_attempts = data.get("attempts", 0)


func _approach() -> void:
	var step: int = ceili(_attempts * 0.5)
	var side: float = 1.0 if _attempts % 2 == 1 else -1.0
	unit.locomotion.move_to(_work_spot(side * step * RETRY_SLIDE))


func _reach() -> float:
	return NavmeshPathService.CUT_MARGIN + unit.def.sabotage_range


func _work_spot(slide: float) -> Vector3:
	var area: Rect2 = target.footprint().grow(_reach() * 0.5)
	var from: Vector3 = unit.sim_position()
	var spot: Vector2 = Vector2(
		clampf(from.x, area.position.x, area.end.x), clampf(from.z, area.position.y, area.end.y)
	)
	if is_equal_approx(spot.x, area.position.x) or is_equal_approx(spot.x, area.end.x):
		spot.y = clampf(spot.y + slide, area.position.y, area.end.y)
	else:
		spot.x = clampf(spot.x + slide, area.position.x, area.end.x)
	return Vector3(spot.x, target.position.y, spot.y)


func _in_range() -> bool:
	var position: Vector3 = unit.sim_position()
	var area: Rect2 = target.footprint()
	var nearest: Vector2 = Vector2(
		clampf(position.x, area.position.x, area.end.x),
		clampf(position.z, area.position.y, area.end.y)
	)
	return nearest.distance_to(Vector2(position.x, position.z)) <= _reach()
