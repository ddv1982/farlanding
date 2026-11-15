class_name Locomotion
extends Node
## Movement component (ground units; flying units too, ADR 0016: they get a
## straight-line PathService and keep `flight_altitude` above the terrain).
## Wraps a Mover, asks the PathService for a path once per
## destination, follows the terrain through a HeightField, and (when the world has a
## Traffic, ADR 0022) passes other ground units: it bends and brakes around them, and
## steps aside for a friend while it stands with nothing to do. Runs on sim ticks; the
## parent Node3D is moved every frame by `interpolate()`.

## Ground speed changed (metres per second). Presentation drives wheels/legs from it.
signal motion_changed(speed: float)
## The destination was reached (or given up on after being stuck next to it).
signal arrived

## 2: the wanted destination and the wait for the tide (ADR 0014).
## 3: a step aside in progress and the post to walk back to (ADR 0022).
const SAVE_VERSION: int = 3
## A path ending further than this from where the unit was sent falls short.
const TIDE_SHORT: float = 3.0
## No progress toward the current corner for this long counts as stuck.
const STUCK_SECONDS: float = 1.5
## Progress smaller than this does not reset the stuck timer.
const STUCK_PROGRESS: float = 0.3
## Stuck re-paths allowed per destination before the unit gives up and stops.
const MAX_REPATHS: int = 2
## A nearby corner can be skipped once the next leg is directly walkable.
const SKIP_DISTANCE: float = 12.0
## Traffic queues accumulate stuck time slowly, including near their final slot.
const WAITING_SHARE: float = 0.2
## A step aside is dropped when it takes longer than this.
const GIVE_WAY_SECONDS: float = 2.5
## After stepping aside, a unit walks back once nothing has driven by for this long.
const RETURN_SECONDS: float = 2.0
## ... unless it ended up this close to where it stood anyway.
const RETURN_DISTANCE: float = 0.6
## Share of the way the sideways pull moves toward Traffic's newest value per tick.
const STEER_EASE: float = 0.5
## After traffic steered a unit onto closed ground, it follows its path alone this long.
const PLAIN_SECONDS: float = 0.5

var mover: Mover = Mover.new()
## Body radius in metres (from the UnitDef).
var radius: float = 0.5

## The path backend this unit moves with (also used by commands for formations).
var paths: PathService = PathService.new()
## True while the unit must stay where it stands (it works, fires or hides there): it
## does not step aside for friends. The Unit sets it every tick.
var holds_ground: bool = false

var _heights: HeightField = null
var _destination: Vector3 = Vector3.ZERO
var _travelling: bool = false
var _previous_position: Vector3 = Vector3.ZERO
var _previous_yaw: float = 0.0
var _traffic: Traffic = null
var _body: TrafficBody = null
## True while the path being followed is a step aside (or the walk back), not an order.
var _giving_way: bool = false
var _give_way_seconds: float = 0.0
## Where the unit stood before it stepped aside; INF = it has not.
var _post: Vector3 = Vector3.INF
var _quiet_seconds: float = 0.0
## The sideways pull in use: Traffic's, eased.
var _steer: Vector3 = Vector3.ZERO
## True when the velocity being applied was bent by traffic.
var _steered: bool = false
var _plain_seconds: float = 0.0
var _stuck_seconds: float = 0.0
var _best_corner_distance: float = INF
var _stuck_corner: int = -1
var _reported_speed: float = 0.0
var _repaths: int = 0
var _facing: bool = false
var _face_point: Vector3 = Vector3.ZERO
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
## unit entered the tree. With `traffic`, the unit (of `faction`) passes the other
## units in it; flying units stay out.
func setup(
	def: UnitDef,
	start: Vector3,
	start_yaw: float,
	p_paths: PathService,
	heights: HeightField,
	traffic: Traffic = null,
	faction: int = 0,
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
	if traffic != null and not def.flies:
		_traffic = traffic
		_body = TrafficBody.new()
		_body.radius = def.radius
		_body.acceleration = def.acceleration
		_body.faction = faction
		_traffic.add(_body)
		_update_body()
	interpolate(1.0)


func _exit_tree() -> void:
	if _body != null:
		_traffic.remove(_body)
		_body = null


## Requests a path to `target` and starts following it. Returns false (and stays put)
## when no path exists.
func move_to(target: Vector3) -> bool:
	_repaths = 0
	_facing = false
	_end_give_way()
	_wanted = target
	return _request_path(target)


## Follows a path computed elsewhere (e.g. shared by a group) toward `wanted` (INF:
## the path's end). Returns false for an empty path.
func follow_path(path: PackedVector3Array, wanted: Vector3 = Vector3.INF) -> bool:
	_repaths = 0
	_facing = false
	_end_give_way()
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


## Brakes to a halt and forgets the destination.
func stop() -> void:
	mover.clear_path()
	_end_give_way()
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
	mover.integrate(mover.velocity, dt)
	if _body != null:
		_shift(_body.push)
		# Traffic must not take a unit off the walkable area: stay, and follow the
		# path alone for a moment.
		if _steered and not paths.is_walkable(mover.position):
			mover.position = start
			_plain_seconds = PLAIN_SECONDS
		_tick_give_way(dt)
	var steer: Vector3 = Vector3.ZERO
	var speed_cap: float = INF
	_plain_seconds = maxf(_plain_seconds - dt, 0.0)
	if _body != null and _plain_seconds <= 0.0:
		steer = _body.steer
		speed_cap = _body.speed_cap
	_skip_visible_corners()
	# Eased in and out, so the unit swings around instead of jerking sideways.
	_steer = _steer.lerp(steer, STEER_EASE)
	if _steer.length_squared() < 0.0004:
		_steer = Vector3.ZERO
	_steered = _steer != Vector3.ZERO
	var reached: bool = mover.plan(dt, _steer, speed_cap)
	if _facing and not mover.has_path():
		_turn_toward_face_point(dt)
	mover.position = _on_ground(mover.position)
	if reached and _giving_way:
		_giving_way = false
	elif reached:
		_finish()
	elif _travelling:
		_check_stuck(dt)
	_update_body()
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
		"giving_way": _giving_way,
		"post": var_to_str(_post),
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported Locomotion save version")
	var mover_data: Dictionary = data.get("mover", {})
	mover.from_dict(mover_data)
	var destination_text: String = data.get("destination", "Vector3(0, 0, 0)")
	_destination = str_to_var(destination_text)
	_travelling = data.get("travelling", false)
	_giving_way = data.get("giving_way", false)
	var post_text: String = data.get("post", "")
	_post = str_to_var(post_text) if post_text != "" else Vector3.INF
	var wanted_text: String = data.get("wanted", "")
	_wanted = str_to_var(wanted_text) if wanted_text != "" else _destination
	_tide_wait = data.get("tide_wait", false)
	_previous_position = mover.position
	_previous_yaw = mover.yaw
	_update_body()


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
	var final_distance: float = (
		Vector2(_destination.x - mover.position.x, _destination.z - mover.position.z).length()
	)
	var waiting: bool = _body != null and _body.speed_cap < mover.max_speed
	_stuck_seconds += dt * (WAITING_SHARE if waiting else 1.0)
	if _stuck_seconds < STUCK_SECONDS:
		return
	if final_distance <= maxf(radius, 0.5):
		# The body covers its destination. Further away, retry the route rather
		# than silently accepting a place several vehicle lengths short.
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


## Do not funnel a whole group through an exact point after the obstacle is clear.
## The walk grid validates each shortcut, so corners across walls stay in the path.
func _skip_visible_corners() -> void:
	if _body == null or not _travelling:
		return
	while (
		mover.has_path()
		and not mover.is_on_last_corner()
		and mover.distance_to_corner() < SKIP_DISTANCE
		and paths.is_segment_walkable(mover.position, mover.path[mover.path_index + 1])
	):
		mover.skip_corner()


## Moves by `offset` when that stays on walkable ground (Traffic's push).
func _shift(offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	var shifted: Vector3 = mover.position + offset
	if paths.is_walkable(shifted):
		mover.position = shifted


## While standing with nothing to do: step aside when Traffic asks, and walk back to
## the post once nothing has driven by for a while.
func _tick_give_way(dt: float) -> void:
	if _travelling:
		return
	if _giving_way:
		_give_way_seconds += dt
		if _give_way_seconds > GIVE_WAY_SECONDS:
			mover.clear_path()
			_giving_way = false
		return
	if holds_ground:
		_post = Vector3.INF
		return
	if _body.give_way_to != Vector3.INF:
		if _post == Vector3.INF:
			_post = mover.position
		_quiet_seconds = 0.0
		_start_give_way(_body.give_way_to)
		return
	if _post == Vector3.INF:
		return
	_quiet_seconds = 0.0 if _body.crowded else _quiet_seconds + dt
	if _quiet_seconds < RETURN_SECONDS:
		return
	var post: Vector3 = _post
	_post = Vector3.INF
	if _flat_distance(post, mover.position) > RETURN_DISTANCE:
		_start_give_way(post)


func _start_give_way(target: Vector3) -> void:
	if not paths.is_walkable(target) or not paths.is_segment_walkable(mover.position, target):
		return
	mover.set_path(PackedVector3Array([target]))
	_giving_way = true
	_give_way_seconds = 0.0


## An order replaces a step aside: the unit no longer has a post to walk back to.
func _end_give_way() -> void:
	_giving_way = false
	_post = Vector3.INF


func _update_body() -> void:
	if _body == null:
		return
	_body.position = mover.position
	_body.velocity = mover.velocity
	_body.wish = mover.wish
	_body.max_speed = mover.max_speed
	_body.moving = mover.has_path()
	_body.asks_way = _travelling
	_body.gives_way = not _travelling and not _giving_way and not holds_ground
