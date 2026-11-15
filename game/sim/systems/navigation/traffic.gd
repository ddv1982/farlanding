class_name Traffic
extends RefCounted
## How ground units pass each other (ADR 0022). Once per sim tick, before the units
## move, `solve()` looks at every unit's position and intended velocity and tells it:
##
## - `steer`: a sideways pull, so two units that would touch within HORIZON seconds
##   each bend away from where the other will be. Units meeting head-on both keep
##   right; the larger unit bends less.
## - `speed_cap`: brake behind a slower unit, or in front of a blocker, instead of
##   driving into it.
## - `give_way_to`: a standing friend in the way steps aside (Locomotion walks it
##   back afterwards).
## - `push`: a last resort that separates two bodies that overlap anyway.
##
## Deterministic and independent of the frame rate: plain arithmetic over the bodies
## in the order they were added. Flying units do not take part.

## How far ahead a moving unit looks, seconds.
const HORIZON: float = 2.0
## ... but never further than this, metres.
const LOOK_MAX: float = 14.0
## Room kept between two bodies when passing, metres.
const CLEARANCE: float = 0.35
## Largest sideways pull, as a fraction of the forward direction (1 = 45 degrees).
const MAX_STEER: float = 1.5
## Strength of the sideways pull.
const STEER_GAIN: float = 2.5
## A body nearer than this (beyond the radii) is steered around at full strength.
const CLOSE_DISTANCE: float = 2.0
## Extra pull to the right when meeting oncoming traffic.
const KEEP_RIGHT: float = 0.35
## A unit ahead moving at least this share of our top speed is followed, not passed.
const FOLLOW_SHARE: float = 0.7
## Braking for what is ahead uses this share of the unit's braking power, and aims to
## stop this far short (metres): the order to brake arrives a tick late.
const BRAKE_SHARE: float = 0.5
const BRAKE_MARGIN: float = 0.3
## Speed never capped below this while steering around something, m/s.
const CREEP_SPEED: float = 0.6
## A standing friend steps aside when it would be hit within this many seconds.
const GIVE_WAY_TIME: float = 1.2
## Extra distance a unit stepping aside moves beyond the passing room, metres.
const GIVE_WAY_MARGIN: float = 0.3
## Share of an overlap removed per tick (all of it: movement adds more each tick).
const PUSH_SHARE: float = 1.0
## A standing unit counts as crowded with a mover this close (beyond their radii).
const CROWD_DISTANCE: float = 4.0
## Grid cell for finding neighbours, metres.
const CELL: float = 8.0
## Largest unit radius the search allows for.
const MAX_RADIUS: float = 2.0

## How firmly a body keeps its place when two overlap: it moves, it stands with
## nothing to do, or it holds its ground.
const HOLD_MOVING: int = 0
const HOLD_LOOSE: int = 1
const HOLD_FIRM: int = 2

var _bodies: Array[TrafficBody] = []


func add(body: TrafficBody) -> void:
	_bodies.append(body)


func remove(body: TrafficBody) -> void:
	_bodies.erase(body)


func size() -> int:
	return _bodies.size()


## Works out every body's steer, speed cap, push and step-aside for this tick.
func solve(dt: float = SimClock.TICK_DELTA) -> void:
	var grid: Dictionary[int, Array] = {}
	for index: int in _bodies.size():
		var body: TrafficBody = _bodies[index]
		body.steer = Vector3.ZERO
		body.speed_cap = INF
		body.push = Vector3.ZERO
		body.give_way_to = Vector3.INF
		body.crowded = false
		var key: int = _key(floori(body.position.x / CELL), floori(body.position.z / CELL))
		if grid.has(key):
			grid[key].append(index)
		else:
			grid[key] = [index]
	# For each standing body: the time until the most urgent mover would hit it.
	var give_way_time: PackedFloat32Array = PackedFloat32Array()
	give_way_time.resize(_bodies.size())
	give_way_time.fill(INF)
	for index: int in _bodies.size():
		_solve_body(index, grid, give_way_time, dt)


func _solve_body(
	index: int, grid: Dictionary[int, Array], give_way_time: PackedFloat32Array, dt: float
) -> void:
	var body: TrafficBody = _bodies[index]
	var at: Vector2 = Vector2(body.position.x, body.position.z)
	var velocity: Vector2 = Vector2(body.wish.x, body.wish.z)
	var speed: float = velocity.length()
	var driving: bool = body.moving and speed > 0.01
	var forward: Vector2 = velocity / speed if driving else Vector2.ZERO
	var right: Vector2 = Vector2(-forward.y, forward.x)
	var reach: float = body.radius + MAX_RADIUS + CLEARANCE
	if driving:
		reach += minf(speed * HORIZON, LOOK_MAX)
	else:
		reach += CROWD_DISTANCE
	var steer: Vector2 = Vector2.ZERO
	var push: Vector2 = Vector2.ZERO
	var low_x: int = floori((at.x - reach) / CELL)
	var high_x: int = floori((at.x + reach) / CELL)
	var low_z: int = floori((at.y - reach) / CELL)
	var high_z: int = floori((at.y + reach) / CELL)
	for cell_x: int in range(low_x, high_x + 1):
		for cell_z: int in range(low_z, high_z + 1):
			var cell: Array = grid.get(_key(cell_x, cell_z), [])
			for entry: Variant in cell:
				var other_index: int = entry
				if other_index == index:
					continue
				var other: TrafficBody = _bodies[other_index]
				var offset: Vector2 = Vector2(other.position.x, other.position.z) - at
				var distance: float = offset.length()
				if distance > reach:
					continue
				var touching: float = body.radius + other.radius
				# Locomotion integrates its already-planned velocity before applying
				# this push. Resolve that next position, rather than last tick's contact.
				var next_offset: Vector2 = (
					offset
					+ (
						Vector2(
							other.velocity.x - body.velocity.x, other.velocity.z - body.velocity.z
						)
						* dt
					)
				)
				var next_distance: float = next_offset.length()
				if next_distance < touching:
					push += _push_apart(
						body, other, next_offset, next_distance, index < other_index
					)
				if not driving:
					if other.moving and distance < touching + CROWD_DISTANCE:
						body.crowded = true
					continue
				var other_velocity: Vector2 = Vector2(other.velocity.x, other.velocity.z)
				var relative: Vector2 = velocity - other_velocity
				var closing: float = relative.dot(offset)
				if closing <= 0.05 * distance:
					continue
				var time: float = closing / relative.length_squared()
				# Slow queues still need local avoidance: a time horizon alone
				# otherwise ignores a body already almost touching the bumper.
				if time > HORIZON and distance > touching + CLOSE_DISTANCE:
					continue
				var ahead: float = offset.dot(forward)
				if ahead <= 0.0:
					continue
				# Where the other will be, seen from here, when the two are closest.
				var miss: Vector2 = offset - relative * time
				var room: float = touching + CLEARANCE
				var miss_distance: float = miss.length()
				if miss_distance >= room:
					continue
				var side: float = offset.dot(right)
				var other_forward: float = other_velocity.dot(forward)
				# A parked neighbour outside the lane needs steering, not braking.
				# Moving traffic retains clearance for its next tick's movement.
				var brake_room: float = room if other.moving else touching
				if (
					absf(side) < brake_room
					and _brakes_for(index, other_index, forward, ahead, offset)
				):
					var reach_ahead: float = sqrt(brake_room * brake_room - side * side)
					var gap: float = maxf(ahead - reach_ahead - BRAKE_MARGIN, 0.0)
					var cap: float = (
						maxf(other_forward, 0.0) + sqrt(2.0 * BRAKE_SHARE * body.acceleration * gap)
					)
					body.speed_cap = minf(body.speed_cap, cap)
				if other.moving and other_forward >= FOLLOW_SHARE * body.max_speed:
					# Follow it: the speed cap keeps the distance.
					continue
				var away: Vector2 = -miss
				if other_forward < 0.0:
					away += right * KEEP_RIGHT * room
				away -= forward * away.dot(forward)
				if away.length_squared() < 0.0001:
					away = right
				# Urgent when it is soon, and when it is close however slowly it comes.
				var soon: float = 1.0 - time / HORIZON
				var close: float = 1.0 - (distance - touching) / CLOSE_DISTANCE
				var urgency: float = maxf(soon, close) * (0.4 + 0.6 * (1.0 - miss_distance / room))
				steer += away.normalized() * urgency * _share(body, other) * STEER_GAIN
				if (
					body.asks_way
					and other.gives_way
					and other.faction == body.faction
					and (time < GIVE_WAY_TIME or distance < touching + CLOSE_DISTANCE)
					and miss_distance < touching
					and time < give_way_time[other_index]
				):
					give_way_time[other_index] = time
					var to_side: float = 1.0 if side > 0.05 else -1.0
					var step: Vector2 = right * to_side * (room - absf(side) + GIVE_WAY_MARGIN)
					other.give_way_to = other.position + Vector3(step.x, 0.0, step.y)
	if steer.length_squared() > 0.0:
		steer = steer.limit_length(MAX_STEER)
		body.steer = Vector3(steer.x, 0.0, steer.y)
		body.speed_cap = maxf(body.speed_cap, CREEP_SPEED)
	body.push = Vector3(push.x, 0.0, push.y)


## True when body `index` is the one to brake for body `other_index`, which is `ahead`
## metres ahead along `forward`. Of two units driving roughly the same way toward the
## same spot, only the one further back brakes; if both did, each would slow to the
## other's speed in turn until both crawled.
func _brakes_for(
	index: int, other_index: int, forward: Vector2, ahead: float, offset: Vector2
) -> bool:
	var other: TrafficBody = _bodies[other_index]
	var other_wish: Vector2 = Vector2(other.wish.x, other.wish.z)
	var other_speed: float = other_wish.length()
	if not other.moving or other_speed <= 0.01:
		return true
	var other_way: Vector2 = other_wish / other_speed
	if other_way.dot(forward) <= 0.0:
		return true
	# How far ahead of the other this body is, seen along the other's way.
	var lead: float = -offset.dot(other_way)
	if is_equal_approx(lead, ahead):
		return index > other_index
	return ahead > lead


## How much of an encounter `body` answers for: the smaller unit bends more, and all
## of it falls to the mover when the other stands still.
static func _share(body: TrafficBody, other: TrafficBody) -> float:
	if not other.moving:
		return 1.0
	var own: float = body.radius * body.radius
	var theirs: float = other.radius * other.radius
	return clampf(2.0 * theirs / (own + theirs), 0.5, 1.5)


## The shift that takes `body` out of `other`. Whoever is freer to move makes all the
## room: a moving body for a standing one, a standing body with nothing to do for one
## that holds its ground. Two alike share it, the smaller giving more. A body that
## holds its ground is never shifted.
static func _push_apart(
	body: TrafficBody, other: TrafficBody, offset: Vector2, distance: float, first: bool
) -> Vector2:
	var own_hold: int = _hold(body)
	var other_hold: int = _hold(other)
	if own_hold > other_hold or own_hold == HOLD_FIRM:
		return Vector2.ZERO
	var direction: Vector2 = offset / distance if distance > 0.001 else Vector2.RIGHT
	if distance <= 0.001 and not first:
		direction = Vector2.LEFT
	var share: float = 1.0
	if own_hold == other_hold:
		var own: float = body.radius * body.radius
		share = other.radius * other.radius / (own + other.radius * other.radius)
	return -direction * (body.radius + other.radius - distance) * PUSH_SHARE * share


## How firmly `body` keeps its place: HOLD_MOVING, HOLD_LOOSE or HOLD_FIRM.
static func _hold(body: TrafficBody) -> int:
	if body.moving:
		return HOLD_MOVING
	return HOLD_LOOSE if body.gives_way else HOLD_FIRM


static func _key(cell_x: int, cell_z: int) -> int:
	return (cell_x + 32768) * 65536 + cell_z + 32768
