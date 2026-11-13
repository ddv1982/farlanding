class_name Builder
extends OrderHandler
## Lets a unit construct buildings. A `build` order names a construction site: the
## builder travels to the nearest point of the site's edge, then adds work every tick
## (its build rate times the faction's power rate) while aiming its arm at the site.
## Several builders on one site add up. The order ends when the site is finished or
## gone.

const KIND: StringName = &"build"
## Path attempts to reach the site before giving up. Each retry slides the work
## spot along the site's edge (another builder may stand on the first one).
const MAX_ATTEMPTS: int = 6
## How far each retry slides the work spot, in metres.
const RETRY_SLIDE: float = 3.0

## The site being worked on (null when not building).
var site: Building = null

var _working: bool = false
var _attempts: int = 0


func handles() -> Array[StringName]:
	return [KIND]


## True while adding work to a site this tick.
func is_working() -> bool:
	return _working


## True if `building` is a site this unit's faction may work on.
func can_build_on(building: Variant) -> bool:
	if not is_instance_valid(building) or not building is Building:
		return false
	var target: Building = building
	return (
		target.is_inside_tree() and target.faction == unit.faction and target.is_under_construction
	)


func begin(order: Order) -> bool:
	if not can_build_on(order.target_entity):
		return false
	site = order.target_entity
	_working = false
	_attempts = 0
	_approach()
	return true


func step(_order: Order, dt: float) -> bool:
	if not can_build_on(site):
		return true
	if _in_range():
		if unit.locomotion.is_travelling():
			unit.locomotion.stop()
		var rate: float = 1.0
		if unit.world != null and unit.world.economy != null:
			rate = unit.world.economy.work_rate(unit.faction)
		site.construction.add_work(dt * unit.def.build_rate * rate)
		unit.locomotion.face(site.position)
		if not _working:
			_working = true
		unit.aim_changed.emit(site.position + Vector3.UP * site.def.height * 0.5)
		return site.construction.is_complete()
	_working = false
	if unit.locomotion.is_waiting_for_tide():
		return false  # the way is under water: hold until the sea falls
	if not unit.locomotion.is_travelling():
		_attempts += 1
		if _attempts > MAX_ATTEMPTS:
			return true
		_approach()
	return false


func end(_order: Order) -> void:
	if _working:
		unit.aim_cleared.emit()
	_working = false
	site = null


## Where this unit works from: the nearest point just outside the site's edge, slid
## along that edge by `slide` metres.
func work_spot(slide: float = 0.0) -> Vector3:
	var area: Rect2 = site.footprint().grow(_reach() * 0.5)
	var from: Vector3 = unit.sim_position()
	var spot: Vector2 = Vector2(
		clampf(from.x, area.position.x, area.end.x), clampf(from.z, area.position.y, area.end.y)
	)
	var on_side: bool = (
		is_equal_approx(spot.x, area.position.x) or is_equal_approx(spot.x, area.end.x)
	)
	if on_side:
		spot.y = clampf(spot.y + slide, area.position.y, area.end.y)
	else:
		spot.x = clampf(spot.x + slide, area.position.x, area.end.x)
	return Vector3(spot.x, site.position.y, spot.y)


## A load: the site is the restored order's target; work goes on from the saved spot.
func resume(order: Order) -> void:
	site = order.target_entity as Building if can_build_on(order.target_entity) else null
	_working = false


func to_dict() -> Dictionary:
	return {"site": Order.entity_id_of(site), "attempts": _attempts}


func from_dict(data: Dictionary) -> void:
	_attempts = data.get("attempts", 0)


func _approach() -> void:
	# Retries alternate sides: 0, +3, -3, +6, -6 ... metres.
	var step: int = ceili(_attempts * 0.5)
	var side: float = 1.0 if _attempts % 2 == 1 else -1.0
	unit.locomotion.move_to(work_spot(side * step * RETRY_SLIDE))


## Distance from the footprint edge within which the unit can build.
func _reach() -> float:
	return NavmeshPathService.CUT_MARGIN + unit.def.work_range


func _in_range() -> bool:
	var position: Vector3 = unit.sim_position()
	var area: Rect2 = site.footprint()
	var nearest: Vector2 = Vector2(
		clampf(position.x, area.position.x, area.end.x),
		clampf(position.z, area.position.y, area.end.y)
	)
	return nearest.distance_to(Vector2(position.x, position.z)) <= _reach()
