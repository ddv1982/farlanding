class_name Locomotion
extends Node
## Ground movement component. Wraps a Mover, asks the PathService for a path once per
## destination, follows the terrain through a HeightField, and (when the path backend
## offers a navigation map) joins server-side RVO avoidance. Runs on sim ticks; the
## parent Node3D is moved every frame by `interpolate()`.

## Ground speed changed (metres per second). Presentation drives wheels/legs from it.
signal motion_changed(speed: float)
## The destination was reached (or given up on after being stuck next to it).
signal arrived

const SAVE_VERSION: int = 1
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
var _reported_speed: float = 0.0
var _repaths: int = 0


## Configures the component from a definition and places it. Call once after the
## unit entered the tree.
func setup(
	def: UnitDef,
	start: Vector3,
	start_yaw: float,
	p_paths: PathService,
	heights: HeightField,
) -> void:
	mover.max_speed = def.move_speed
	mover.acceleration = def.acceleration
	mover.turn_speed = deg_to_rad(def.turn_speed)
	radius = def.radius
	paths = p_paths
	_heights = heights
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
	return _request_path(target)


## Follows a path computed elsewhere (e.g. shared by a group). Returns false for an
## empty path.
func follow_path(path: PackedVector3Array) -> bool:
	_repaths = 0
	return _start_path(path)


## Brakes to a halt and forgets the destination.
func stop() -> void:
	mover.clear_path()
	_travelling = false


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
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Locomotion save version")
	var mover_data: Dictionary = data.get("mover", {})
	mover.from_dict(mover_data)
	var destination_text: String = data.get("destination", "Vector3(0, 0, 0)")
	_destination = str_to_var(destination_text)
	_travelling = data.get("travelling", false)
	_previous_position = mover.position
	_previous_yaw = mover.yaw


func _request_path(target: Vector3) -> bool:
	return _start_path(paths.find_path(mover.position, target))


func _start_path(path: PackedVector3Array) -> bool:
	if path.is_empty():
		mover.clear_path()
		_travelling = false
		return false
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


func _reset_stuck() -> void:
	_stuck_seconds = 0.0
	_best_corner_distance = INF


func _on_ground(point: Vector3) -> Vector3:
	if _heights != null:
		point.y = _heights.sample(point.x, point.z)
	return point


func _create_agent(def: UnitDef) -> void:
	var map: RID = paths.get_avoidance_map()
	if not map.is_valid():
		return
	_agent = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_use_3d_avoidance(_agent, false)
	NavigationServer3D.agent_set_radius(_agent, def.radius + 0.25)
	NavigationServer3D.agent_set_max_speed(_agent, def.move_speed)
	NavigationServer3D.agent_set_neighbor_distance(_agent, maxf(8.0, def.radius * 6.0))
	NavigationServer3D.agent_set_max_neighbors(_agent, 8)
	NavigationServer3D.agent_set_time_horizon_agents(_agent, 0.8)
	NavigationServer3D.agent_set_avoidance_priority(_agent, PRIORITY_IDLE)
	NavigationServer3D.agent_set_position(_agent, mover.position)
	NavigationServer3D.agent_set_avoidance_callback(_agent, _on_safe_velocity)
	NavigationServer3D.agent_set_avoidance_enabled(_agent, true)
	NavigationServer3D.agent_set_map(_agent, map)


func _update_agent() -> void:
	if not _agent.is_valid():
		return
	NavigationServer3D.agent_set_position(_agent, mover.position)
	var moving: bool = mover.has_path()
	NavigationServer3D.agent_set_avoidance_priority(
		_agent, PRIORITY_MOVING if moving else PRIORITY_IDLE
	)
	NavigationServer3D.agent_set_velocity(_agent, mover.velocity)
	if not moving:
		_has_safe_velocity = false


func _on_safe_velocity(safe_velocity: Vector3) -> void:
	_safe_velocity = safe_velocity
	_has_safe_velocity = true
