class_name Scanner
extends OrderHandler
## Lets a unit scan discovery sites (the Surveyor). A `scan` order names a site: the
## unit walks to within `scan_range` of its edge, stops and scans; the site's
## progress grows by `scan_rate` / scan time per second (several scanners add up).
## When it reaches 1 the world's Discovery system resolves the site. A scan stops when
## the order ends for any reason (a new order, a stop, the unit dies or is pushed
## away); if nobody else is scanning the site, its progress is lost and
## `Events.scan_interrupted` fires.

const KIND: StringName = &"scan"
const STATE_IDLE: StringName = &"idle"
const STATE_APPROACH: StringName = &"approach"
const STATE_SCANNING: StringName = &"scanning"
## Path attempts to reach the site before giving up.
const MAX_ATTEMPTS: int = 3

var state: StringName = STATE_IDLE
## The site being approached or scanned, or null.
var site: DiscoverySite = null

var _attempts: int = 0


func handles() -> Array[StringName]:
	return [KIND]


## True while scanning a site (read by audio and UI).
func is_scanning() -> bool:
	return state == STATE_SCANNING


func begin(order: Order) -> bool:
	var target: DiscoverySite = order.target_entity as DiscoverySite
	if not _scannable(target):
		return false
	site = target
	_attempts = 0
	if _in_reach():
		_start_scanning()
	else:
		state = STATE_APPROACH
		unit.locomotion.move_to(site.position)
	return true


func step(_order: Order, dt: float) -> bool:
	if not _scannable(site):
		return true
	if state == STATE_APPROACH:
		return _step_approach()
	if state == STATE_SCANNING:
		return _step_scanning(dt)
	return true


func end(_order: Order) -> void:
	_leave(true)


func _step_approach() -> bool:
	if _in_reach():
		_start_scanning()
		return false
	if not unit.locomotion.is_travelling():
		_attempts += 1
		if _attempts > MAX_ATTEMPTS:
			return true
		unit.locomotion.move_to(site.position)
	return false


## Returns true once the site is resolved.
func _step_scanning(dt: float) -> bool:
	site.set_scan_progress(site.scan_progress + unit.def.scan_rate * dt / site.def.scan_time)
	if site.scan_progress < 1.0:
		return false
	var done: DiscoverySite = site
	state = STATE_IDLE
	site = null
	if unit.world != null and unit.world.discovery != null:
		unit.world.discovery.resolve(done, unit.faction)
	else:
		done.resolve(unit.faction)
	return true


func _start_scanning() -> void:
	unit.locomotion.stop()
	unit.locomotion.face(site.position)
	state = STATE_SCANNING
	if site.add_scanner(unit):
		Events.scan_started.emit(unit, site)
		if unit.world != null and unit.world.discovery != null:
			unit.world.discovery.on_scan_started(site)


## Stops scanning; `interrupted` announces a scan cut short.
func _leave(interrupted: bool) -> void:
	if site != null and is_instance_valid(site) and state == STATE_SCANNING:
		if site.remove_scanner(unit) and interrupted:
			Events.scan_interrupted.emit(unit, site)
	state = STATE_IDLE
	site = null


func _in_reach() -> bool:
	var at: Vector3 = unit.sim_position()
	var distance: float = Vector2(site.position.x - at.x, site.position.z - at.z).length()
	return distance <= site.def.radius + unit.def.radius + unit.def.scan_range


static func _scannable(target: Variant) -> bool:
	if not is_instance_valid(target) or not target is DiscoverySite:
		return false
	var node: DiscoverySite = target
	return node.is_inside_tree() and node.can_be_scanned()
