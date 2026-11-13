class_name FloodSystem
extends RefCounted
## What the sea does to the world (ADR 0014). A planet rule (TideSystem) only sets
## the sea level in the WorldConditions; the world runs this every sim tick after the
## rule, and it costs nothing on a world without a sea.
##
## - Navigation: the PathService learns where the sea stands (`set_water()`; on a
##   tidal map that switches between navmeshes baked for a few sea levels). When the
##   closed ground changed, every ground unit whose route now runs into closed water
##   asks for a new path, and units waiting on a shore for the sea to fall ask again
##   too: from two ticks after the change and then every check for REPLAN_WINDOW_TICKS
##   (the navigation server takes a large new mesh a few frames later, and a path asked
##   for in between still crosses the old ground).
## - Units: a ground unit in water deeper than the wading depth moves at the wading
##   factor and takes light damage; an idle one wades to the nearest dry ground on its
##   own. The player hears the Advisor's `units_in_water` (at most every 30 s).
##   Hovering units are never caught.
## - Resource nodes under water are flooded (`ResourceNode.is_flooded`): haulers do
##   not mine them until the sea falls.

## Units and nodes are checked every this many ticks.
const CHECK_TICKS: int = 5
## Ticks between a navmesh switch and the first re-plans (the server must take the
## mesh) ...
const REPLAN_DELAY_TICKS: int = 2
## ... and how long after the switch routes are checked again at every check.
const REPLAN_WINDOW_TICKS: int = 30
## Seconds between two `units_in_water` alerts.
const ALERT_SECONDS: float = 30.0
## How far an idle unit in water looks for dry ground, and the step of the search.
const DRY_SEARCH_RADIUS: float = 40.0
const DRY_SEARCH_STEP: float = 2.0
## Dry ground for a wading unit stands this much above the closed ground.
const DRY_MARGIN: float = 0.2
## Spacing of the samples along a route checked against the sea, in metres.
const ROUTE_SAMPLE: float = 2.0

var world: SimWorld = null
## Wall-clock cost of the last tick, in microseconds.
var last_tick_usec: int = 0
## Units in water deeper than the wading depth at the last check (tests, debug).
var wading_count: int = 0

var _replan_at: int = -1
var _replan_until: int = -1
var _next_alert_tick: int = 0


func _init(p_world: SimWorld) -> void:
	world = p_world


## One sim tick (after the planet rule).
func tick(tick_number: int, dt: float) -> void:
	var conditions: WorldConditions = world.conditions
	if not conditions.has_sea():
		return
	var started: int = Time.get_ticks_usec()
	if sync():
		_replan_at = tick_number + REPLAN_DELAY_TICKS
		_replan_until = tick_number + REPLAN_WINDOW_TICKS
	if _replan_at >= 0 and tick_number >= _replan_at:
		_replan_at = -1
		_replan()
	elif tick_number <= _replan_until and tick_number % CHECK_TICKS == 0:
		_replan()
	if tick_number % CHECK_TICKS == 0:
		_check_units(tick_number, dt * CHECK_TICKS)
		_check_nodes()
	last_tick_usec = Time.get_ticks_usec() - started


## Tells navigation where the sea stands now (also after a load, before orders
## resume). Returns true when the closed ground changed.
func sync() -> bool:
	var conditions: WorldConditions = world.conditions
	if not conditions.has_sea():
		return false
	if world.paths.water_heights == null:
		world.paths.water_heights = world.heights
	return world.paths.set_water(conditions.sea_level, conditions.wading_depth)


## True if a ground unit following `route` (its position first) would walk into closed
## water: wet ground after dry ground (a unit wading out of the sea is not stopped).
func route_runs_into_water(route: PackedVector3Array) -> bool:
	var closed: float = world.paths.closed_below
	if closed <= -INF or world.heights == null or route.is_empty():
		return false
	var left_water: bool = not _closed_at(route[0], closed)
	for i: int in range(1, route.size()):
		var from: Vector3 = route[i - 1]
		var to: Vector3 = route[i]
		var steps: int = maxi(
			1, ceili(Vector2(to.x - from.x, to.z - from.z).length() / ROUTE_SAMPLE)
		)
		for step: int in range(1, steps + 1):
			var wet: bool = _closed_at(from.lerp(to, float(step) / steps), closed)
			if wet and left_water:
				return true
			left_water = left_water or not wet
	return false


## The nearest point to `at` a wading unit can stand dry on (searched in rings), or
## Vector3.INF if there is none near. With `above`, the ground must also be at least
## that high (`conditions.high_water`: ground the sea never reaches).
func nearest_dry(at: Vector3, above: float = -INF) -> Vector3:
	var lowest: float = maxf(world.paths.closed_below + DRY_MARGIN, above)
	var radius: float = DRY_SEARCH_STEP
	while radius <= DRY_SEARCH_RADIUS:
		var steps: int = maxi(8, ceili(TAU * radius / DRY_SEARCH_STEP))
		var best: Vector3 = Vector3.INF
		var best_height: float = -INF
		for i: int in steps:
			var angle: float = TAU * i / steps
			var point: Vector3 = at + Vector3(cos(angle), 0.0, sin(angle)) * radius
			var height: float = world.heights.sample(point.x, point.z)
			if height < lowest or not world.paths.is_walkable(point):
				continue
			if height > best_height:
				best = Vector3(point.x, height, point.z)
				best_height = height
		if best != Vector3.INF:
			return best
		radius += DRY_SEARCH_STEP
	return Vector3.INF


func _replan() -> void:
	for unit: Unit in world.units:
		if unit.is_dead or unit.locomotion == null or unit.def == null or unit.def.hovers:
			continue
		var locomotion: Locomotion = unit.locomotion
		if locomotion.is_waiting_for_tide():
			locomotion.replan()
		elif locomotion.is_travelling() and route_runs_into_water(locomotion.remaining_route()):
			locomotion.replan()


func _check_units(tick_number: int, step_seconds: float) -> void:
	var conditions: WorldConditions = world.conditions
	var player_wading: bool = false
	wading_count = 0
	for unit: Unit in world.units:
		if unit.is_dead or unit.locomotion == null or unit.def == null or unit.def.hovers:
			continue
		var at: Vector3 = unit.sim_position()
		var depth: float = conditions.sea_level - world.heights.sample(at.x, at.z)
		var wading: bool = depth > conditions.wading_depth
		unit.locomotion.set_extra_scale(
			&"wading", conditions.wading_speed_factor if wading else 1.0
		)
		if not wading:
			continue
		wading_count += 1
		player_wading = player_wading or unit.faction == world.player_faction
		var damage: float = conditions.wading_damage_per_second * step_seconds
		if damage > 0.0 and unit.health != null:
			unit.health.take(damage)
		if unit.is_dead or unit.is_dormant or unit.orders == null or not unit.orders.is_idle():
			continue
		var dry: Vector3 = nearest_dry(at)
		if dry != Vector3.INF:
			unit.orders.give(Order.new(MoveCommand.KIND_MOVE, dry))
	if player_wading and tick_number >= _next_alert_tick:
		_next_alert_tick = tick_number + roundi(ALERT_SECONDS * SimClock.TICK_RATE)
		Events.advisor_alert.emit(&"units_in_water")


func _check_nodes() -> void:
	var sea: float = world.conditions.sea_level
	for node: ResourceNode in world.resource_nodes:
		node.set_flooded(sea > world.heights.sample(node.position.x, node.position.z))


func _closed_at(point: Vector3, closed: float) -> bool:
	return world.heights.sample(point.x, point.z) < closed
