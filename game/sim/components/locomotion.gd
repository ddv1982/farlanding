class_name Locomotion
extends Node
## Movement component (ground units; flying units too, ADR 0016: they get a
## straight-line PathService and keep `flight_altitude` above the terrain).
## Wraps a Mover, asks the PathService for a path once per
## destination, follows the terrain through a HeightField, and (when the path backend
## offers a navigation map) joins server-side RVO avoidance. Runs on sim ticks; the
## parent Node3D is moved every frame by `interpolate()`.

## Ground speed changed (metres per second). Presentation drives wheels/legs from it.
signal motion_changed(speed: float)
## The destination was reached (or given up on after being stuck next to it).
signal arrived

## 2: the wanted destination and the wait for the tide (ADR 0014).
const SAVE_VERSION: int = 2
## A path ending further than this from where the unit was sent falls short.
const TIDE_SHORT: float = 3.0
## No progress toward the current corner for this long counts as stuck.
const STUCK_SECONDS: float = 1.5
## Progress smaller than this does not reset the stuck timer.
const STUCK_PROGRESS: float = 0.3
## Stuck re-paths allowed per destination before the unit gives up and stops.
const MAX_REPATHS: int = 2
## RVO priorities: idle units hold their ground, moving units steer around them.
const PRIORITY_IDLE: float = 1.0
const PRIORITY_MOVING: float = 0.5

var mover: Mover = Mover.new()
## Body radius in metres (from the UnitDef).
var radius: float = 0.5

## The path backend this unit moves with (also used by commands for formations).
var paths: PathService = PathService.new()

var _heights: HeightField = null
var _destination: Vector3 = Vector3.ZERO
var _travelling: bool = false
var _previous_position: Vector3 = Vector3.ZERO
var _previous_yaw: float = 0.0
var _agent: RID = RID()
var _safe_velocity: Vector3 = Vector3.ZERO
var _has_safe_velocity: bool = false
var _stuck_seconds: float = 0.0
var _best_corner_distance: float = INF
var _stuck_corner: int = -1
var _reported_speed: float = 0.0
var _repaths: int = 0
var _facing: bool = false
var _face_point: Vector3 = Vector3.ZERO
var _agent_priority: float = -1.0
var _agent_position: Vector3 = Vector3.INF
var _agent_velocity: Vector3 = Vector3.INF
var _base_speed: float = INF
var _speed_limit: float = INF
var _speed_scale: float = 1.0
## Further top-speed factors by cause (wading, carrying), multiplied in.
var _extra_scales: Dictionary[StringName, float] = {}
## Where the unit was sent (its path may end short of it); INF = nowhere.
var _wanted: Vector3 = Vector3.INF
## True while the sea closes the way to `_wanted` but low water would open it.
var _tide_wait: bool = false
## Height kept above the terrain: a flying unit's altitude, 0 on the ground.
var _altitude: float = 0.0


## Configures the component from a definition and places it. Call once after the
## unit entered the tree.
func setup(
	def: UnitDef,
	start: Vector3,
	start_yaw: float,
	p_paths: PathService,
	heights: HeightField,
) -> void:
	_base_speed = def.move_speed
	mover.max_speed = _top_speed()
	mover.acceleration = def.acceleration
	mover.turn_speed = deg_to_rad(def.turn_speed)
	radius = def.radius
	paths = p_paths
	_heights = heights
	_altitude = def.flight_altitude if def.flies else 0.0
	mover.position = _on_ground(start)
	mover.yaw = start_yaw
	_previous_position = mover.position
	_previous_yaw = mover.yaw
	_create_agent(def)
	interpolate(1.0)


func _exit_tree() -> void:
	if _agent.is_valid():
		NavigationServer3D.free_rid(_agent)
		_agent = RID()


## Requests a path to `target` and starts following it. Returns false (and stays put)
## when no path exists.
func move_to(target: Vector3) -> bool:
	_repaths = 0
	_facing = false
	_wanted = target
	return _request_path(target)


## Follows a path computed elsewhere (e.g. shared by a group) toward `wanted` (INF:
## the path's end). Returns false for an empty path.
func follow_path(path: PackedVector3Array, wanted: Vector3 = Vector3.INF) -> bool:
	_repaths = 0
	_facing = false
	_wanted = wanted
	if wanted == Vector3.INF:
		_wanted = path[path.size() - 1] if not path.is_empty() else mover.position
	_note_tide(path)
	return _start_path(path)


## Asks for a new path to where the unit was sent (the sea closed or opened a way).
## Returns false when it has nowhere to go or no path exists.
func replan() -> bool:
	if _wanted == Vector3.INF:
		return false
	_repaths = 0
	return _request_path(_wanted)


## True while the sea closes the only way to where the unit was sent and low water
## would open it: the unit waits on the shore, its order still open.
func is_waiting_for_tide() -> bool:
	return _tide_wait


## The rest of the route: where the unit is, then the corners still ahead.
func remaining_route() -> PackedVector3Array:
	var route: PackedVector3Array = PackedVector3Array([mover.position])
	if mover.has_path():
		route.append_array(mover.path.slice(mover.path_index))
	return route


## Multiplies the top speed by `scale` for `cause` (&"wading", &"carrying"); 1 ends it.
func set_extra_scale(cause: StringName, scale: float) -> void:
	var current: float = _extra_scales.get(cause, 1.0)
	if is_equal_approx(current, scale):
		return
	if is_equal_approx(scale, 1.0):
		_extra_scales.erase(cause)
	else:
		_extra_scales[cause] = scale
	_apply_top_speed()


## Caps the top speed at `limit` m/s (INF = the definition's own speed), e.g. while
## a unit creeps in stealth mode.
func set_speed_limit(limit: float) -> void:
	_speed_limit = limit
	_apply_top_speed()


## Scales the top speed (a dust storm slows everyone); 1 = normal.
func set_speed_scale(scale: float) -> void:
	if is_equal_approx(scale, _speed_scale):
		return
	_speed_scale = maxf(scale, 0.05)
	_apply_top_speed()


func get_speed_scale() -> float:
	return _speed_scale


func _top_speed() -> float:
	var speed: float = minf(_base_speed, _speed_limit) * _speed_scale
	for scale: float in _extra_scales.values():
		speed *= scale
	return maxf(speed, 0.05)


func _apply_top_speed() -> void:
	mover.max_speed = _top_speed()
	if _agent.is_valid():
		NavigationServer3D.agent_set_max_speed(_agent, mover.max_speed)


## Brakes to a halt and forgets the destination.
func stop() -> void:
	mover.clear_path()
	_travelling = false
	_facing = false
	_tide_wait = false
	_wanted = Vector3.INF


## While standing, turn the body toward `point` (until the next move or stop).
func face(point: Vector3) -> void:
	_face_point = point
	_facing = true


func is_facing() -> bool:
	return _facing


## True while heading for a destination.
func is_travelling() -> bool:
	return _travelling


func get_destination() -> Vector3:
	return _destination if _travelling else mover.position


## One sim tick of movement.
func tick(dt: float) -> void:
	_previous_position = mover.position
	_previous_yaw = mover.yaw
	var start: Vector3 = mover.position
	if _has_safe_velocity and mover.has_path():
		mover.integrate(_safe_velocity, dt)
		# Avoidance must not push a unit off the walkable area: fall back to the plan.
		if not paths.is_walkable(mover.position):
			mover.position = start
			mover.integrate(mover.velocity, dt)
	else:
		mover.integrate(mover.velocity, dt)
	var reached: bool = mover.plan(dt)
	if _facing and not mover.has_path():
		_turn_toward_face_point(dt)
	mover.position = _on_ground(mover.position)
	if reached:
		_finish()
	elif _travelling:
		_check_stuck(dt)
	_update_agent()
	if not is_equal_approx(mover.speed, _reported_speed):
		_reported_speed = mover.speed
		motion_changed.emit(mover.speed)


## Places the parent between the last two sim states; `fraction` in [0, 1].
func interpolate(fraction: float) -> void:
	var body: Node3D = get_parent() as Node3D
	if body == null:
		return
	body.position = _previous_position.lerp(mover.position, fraction)
	body.rotation.y = lerp_angle(_previous_yaw, mover.yaw, fraction)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"mover": mover.to_dict(),
		"destination": var_to_str(_destination),
		"travelling": _travelling,
		"wanted": var_to_str(_wanted),
		"tide_wait": _tide_wait,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported Locomotion save version")
	var mover_data: Dictionary = data.get("mover", {})
	mover.from_dict(mover_data)
	var destination_text: String = data.get("destination", "Vector3(0, 0, 0)")
	_destination = str_to_var(destination_text)
	_travelling = data.get("travelling", false)
	var wanted_text: String = data.get("wanted", "")
	_wanted = str_to_var(wanted_text) if wanted_text != "" else _destination
	_tide_wait = data.get("tide_wait", false)
	_previous_position = mover.position
	_previous_yaw = mover.yaw


func _request_path(target: Vector3) -> bool:
	var path: PackedVector3Array = paths.find_path(mover.position, target)
	_note_tide(path)
	return _start_path(path)


## Notes whether `path` falls short of `_wanted` only because of the sea: the way the
## hovering units take (the sea ignored) gets there.
func _note_tide(path: PackedVector3Array) -> void:
	_tide_wait = false
	if paths.closed_below <= -INF or _wanted == Vector3.INF:
		return
	var end: Vector3 = path[path.size() - 1] if not path.is_empty() else mover.position
	if _flat_distance(end, _wanted) <= TIDE_SHORT:
		return
	var dry: PathService = paths.for_hover()
	if dry == paths:
		return
	var low: PackedVector3Array = dry.find_path(mover.position, _wanted)
	_tide_wait = not low.is_empty() and _flat_distance(low[low.size() - 1], _wanted) <= TIDE_SHORT


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _start_path(path: PackedVector3Array) -> bool:
	if path.is_empty():
		mover.clear_path()
		_travelling = false
		return _tide_wait
	mover.set_path(path)
	_destination = path[path.size() - 1]
	_travelling = true
	_reset_stuck()
	return true


func _finish() -> void:
	_travelling = false
	mover.clear_path()
	arrived.emit()


func _check_stuck(dt: float) -> void:
	var distance: float = mover.distance_to_corner()
	if mover.path_index != _stuck_corner:
		# A new corner is further away than the one just passed: restart the measure.
		_stuck_corner = mover.path_index
		_best_corner_distance = distance
		_stuck_seconds = 0.0
		return
	if distance < _best_corner_distance - STUCK_PROGRESS:
		_best_corner_distance = distance
		_stuck_seconds = 0.0
		return
	_stuck_seconds += dt
	if _stuck_seconds < STUCK_SECONDS:
		return
	var final_distance: float = (
		Vector2(_destination.x - mover.position.x, _destination.z - mover.position.z).length()
	)
	if final_distance < radius * 4.0 + 1.0:
		# Close enough and blocked (usually by a unit already standing there).
		_finish()
		return
	_repaths += 1
	if _repaths > MAX_REPATHS or not _request_path(_destination):
		_finish()


func _turn_toward_face_point(dt: float) -> void:
	var direction: Vector3 = Vector3(
		_face_point.x - mover.position.x, 0.0, _face_point.z - mover.position.z
	)
	if direction.length_squared() < 0.01:
		return
	var wanted: float = Mover.yaw_for(direction)
	mover.yaw = wrapf(rotate_toward(mover.yaw, wanted, mover.turn_speed * dt), -PI, PI)


func _reset_stuck() -> void:
	_stuck_seconds = 0.0
	_best_corner_distance = INF
	_stuck_corner = -1


func _on_ground(point: Vector3) -> Vector3:
	if _heights != null:
		point.y = _heights.sample(point.x, point.z) + _altitude
	elif _altitude > 0.0:
		point.y = _altitude
	return point


func _create_agent(def: UnitDef) -> void:
	var map: RID = paths.get_avoidance_map()
	if not map.is_valid():
		return
	_agent = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_use_3d_avoidance(_agent, false)
	NavigationServer3D.agent_set_radius(_agent, def.radius + 0.25)
	NavigationServer3D.agent_set_max_speed(_agent, mover.max_speed)
	NavigationServer3D.agent_set_neighbor_distance(_agent, maxf(8.0, def.radius * 6.0))
	NavigationServer3D.agent_set_max_neighbors(_agent, 8)
	NavigationServer3D.agent_set_time_horizon_agents(_agent, 0.8)
	NavigationServer3D.agent_set_avoidance_priority(_agent, PRIORITY_IDLE)
	NavigationServer3D.agent_set_position(_agent, mover.position)
	_agent_priority = PRIORITY_IDLE
	_agent_position = mover.position
	_agent_velocity = Vector3.ZERO
	NavigationServer3D.agent_set_avoidance_callback(_agent, _on_safe_velocity)
	NavigationServer3D.agent_set_avoidance_enabled(_agent, true)
	NavigationServer3D.agent_set_map(_agent, map)


func _update_agent() -> void:
	if not _agent.is_valid():
		return
	# Only tell the server what changed: most units stand still most of the time.
	if mover.position != _agent_position:
		_agent_position = mover.position
		NavigationServer3D.agent_set_position(_agent, mover.position)
	var moving: bool = mover.has_path()
	var priority: float = PRIORITY_MOVING if moving else PRIORITY_IDLE
	if priority != _agent_priority:
		_agent_priority = priority
		NavigationServer3D.agent_set_avoidance_priority(_agent, priority)
	if mover.velocity != _agent_velocity:
		_agent_velocity = mover.velocity
		NavigationServer3D.agent_set_velocity(_agent, mover.velocity)
	if not moving:
		_has_safe_velocity = false


func _on_safe_velocity(safe_velocity: Vector3) -> void:
	_safe_velocity = safe_velocity
	_has_safe_velocity = true
