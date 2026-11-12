class_name Mover
extends RefCounted
## Pure ground-movement maths for one unit: follows a list of path corners on the XZ
## plane, turning at `turn_speed` and accelerating/braking at `acceleration`, and
## stops exactly on the last corner. Knows nothing about nodes, terrain or avoidance;
## Locomotion wraps it. Height (`position.y`) is left to the caller.
##
## Each sim tick: `integrate(velocity_to_apply, dt)` then `plan(dt)`.

const SAVE_VERSION: int = 1
## A corner counts as passed within this distance (not used for the last corner).
const CORNER_RADIUS: float = 1.2
## The last corner counts as reached within this distance.
const ARRIVE_DISTANCE: float = 0.15
## Below this the unit stands still.
const MIN_SPEED: float = 0.05

## Metres per second.
var max_speed: float = 5.0
## Metres per second squared, for both speeding up and braking.
var acceleration: float = 10.0
## Radians per second.
var turn_speed: float = TAU

var position: Vector3 = Vector3.ZERO
## Facing in radians around +Y; 0 faces -Z (model forward).
var yaw: float = 0.0
## Current ground speed in metres per second.
var speed: float = 0.0
## Velocity this unit wants for the next tick (XZ only).
var velocity: Vector3 = Vector3.ZERO
var path: PackedVector3Array = PackedVector3Array()
var path_index: int = 0


func _init(
	p_max_speed: float = 5.0, p_acceleration: float = 10.0, p_turn_speed: float = TAU
) -> void:
	max_speed = p_max_speed
	acceleration = p_acceleration
	turn_speed = p_turn_speed


## Forward unit vector for a yaw (model forward is -Z).
static func forward_for(p_yaw: float) -> Vector3:
	return Vector3(-sin(p_yaw), 0.0, -cos(p_yaw))


## Yaw that faces along `direction` (XZ).
static func yaw_for(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func set_path(points: PackedVector3Array) -> void:
	path = points
	path_index = 0


## Drops the path; the unit brakes to a halt.
func clear_path() -> void:
	path = PackedVector3Array()
	path_index = 0


func has_path() -> bool:
	return path_index < path.size()


func is_moving() -> bool:
	return has_path() or speed > 0.0


## Distance on the XZ plane to the corner currently steered at, or 0 without a path.
func distance_to_corner() -> float:
	if not has_path():
		return 0.0
	return _flat(path[path_index] - position).length()


func is_on_last_corner() -> bool:
	return path_index == path.size() - 1


## Moves by `applied` (usually `velocity`, or an avoidance-adjusted velocity).
func integrate(applied: Vector3, dt: float) -> void:
	position.x += applied.x * dt
	position.z += applied.z * dt


## Updates facing, speed and `velocity` for the next `dt`. Returns true on the tick the
## last corner is reached.
func plan(dt: float) -> bool:
	if not has_path():
		speed = move_toward(speed, 0.0, acceleration * dt)
		if speed < MIN_SPEED:
			speed = 0.0
		velocity = forward_for(yaw) * speed
		return false
	var to_corner: Vector3 = _flat(path[path_index] - position)
	while not is_on_last_corner() and to_corner.length() < CORNER_RADIUS:
		path_index += 1
		to_corner = _flat(path[path_index] - position)
	var distance: float = to_corner.length()
	if is_on_last_corner() and distance <= ARRIVE_DISTANCE:
		position.x = path[path_index].x
		position.z = path[path_index].z
		clear_path()
		speed = 0.0
		velocity = Vector3.ZERO
		return true
	var direction: Vector3 = to_corner / distance
	var wanted_yaw: float = yaw_for(direction)
	yaw = wrapf(rotate_toward(yaw, wanted_yaw, turn_speed * dt), -PI, PI)
	# Slow down while facing away from the travel direction; turn in place above ~80°.
	var alignment: float = clampf((cos(angle_difference(yaw, wanted_yaw)) - 0.2) / 0.8, 0.0, 1.0)
	var wanted_speed: float = max_speed * alignment
	if is_on_last_corner():
		wanted_speed = minf(wanted_speed, sqrt(2.0 * acceleration * distance))
	speed = move_toward(speed, wanted_speed, acceleration * dt)
	var step_speed: float = speed
	if is_on_last_corner():
		step_speed = minf(speed, distance / dt)
	velocity = direction * step_speed
	return false


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"position": var_to_str(position),
		"yaw": yaw,
		"speed": speed,
		"path": var_to_str(path),
		"path_index": path_index,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Mover save version")
	var position_text: String = data.get("position", "Vector3(0, 0, 0)")
	position = str_to_var(position_text)
	yaw = data.get("yaw", 0.0)
	speed = data.get("speed", 0.0)
	var path_text: String = data.get("path", "PackedVector3Array()")
	path = str_to_var(path_text)
	path_index = data.get("path_index", 0)
	velocity = Vector3.ZERO


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
