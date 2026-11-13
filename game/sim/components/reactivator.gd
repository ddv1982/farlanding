class_name Reactivator
extends OrderHandler
## Lets a unit that can build or scan (a Fabricator, a Surveyor, the Combine Rigger)
## bring an Antecedent engine back to life, or take one running for another faction
## over (Hollow Meridian, ADR 0017). A `reactivate` order names the engine: the unit
## walks to the edge of its footprint, stops and works; the planet's MachinerySystem
## counts the work (several workers add up) and hands the engine over when it is done.
## The work stops when the order ends for any reason (a new order, a stop, death, being
## pushed away); unworked progress then fades.

const KIND: StringName = &"reactivate"
const MAX_ATTEMPTS: int = 6
const RETRY_SLIDE: float = 3.0
## Metres a worker may drift past its reach before it walks back.
const REACH_SLACK: float = 1.0

## The engine being approached or worked on (null when not reactivating).
var target: Building = null

var _working: bool = false
var _attempts: int = 0


func handles() -> Array[StringName]:
	return [KIND]


## True while working on an engine (read by audio and UI).
func is_working() -> bool:
	return _working


## True if units of `faction` may work on `building` now: an Antecedent machine in a
## world playing the machinery rule that does not already run for `faction`.
static func can_reactivate(building: Variant, faction: int) -> bool:
	if not is_instance_valid(building) or not building is Building:
		return false
	var node: Building = building
	if not node.is_inside_tree() or node.machine == null or node.world == null:
		return false
	var machinery: MachinerySystem = node.world.planet as MachinerySystem
	return machinery != null and machinery.can_claim(node, faction)


func begin(order: Order) -> bool:
	if not can_reactivate(order.target_entity, unit.faction):
		return false
	target = order.target_entity
	_working = false
	_attempts = 0
	_approach()
	return true


func step(_order: Order, _dt: float) -> bool:
	if not can_reactivate(target, unit.faction):
		return true
	if not _in_range(REACH_SLACK if _working else 0.0):
		_working = false
		if unit.locomotion.is_waiting_for_tide():
			return false
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
	var machinery: MachinerySystem = unit.world.planet as MachinerySystem
	machinery.report_work(target, unit)
	# Done once the engine runs for us: the system hands it over on its own tick.
	return false


func end(_order: Order) -> void:
	_working = false
	target = null


## A load: the engine is the restored order's; the work done is kept on the engine.
func resume(order: Order) -> void:
	target = (
		order.target_entity as Building
		if can_reactivate(order.target_entity, unit.faction)
		else null
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
	var machinery: MachinerySystem = unit.world.planet as MachinerySystem
	var range_metres: float = machinery.work_range() if machinery != null else 3.0
	return NavmeshPathService.CUT_MARGIN + unit.def.radius + range_metres


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


func _in_range(slack: float) -> bool:
	var position: Vector3 = unit.sim_position()
	var area: Rect2 = target.footprint()
	var nearest: Vector2 = Vector2(
		clampf(position.x, area.position.x, area.end.x),
		clampf(position.z, area.position.y, area.end.y)
	)
	return nearest.distance_to(Vector2(position.x, position.z)) <= _reach() + slack
