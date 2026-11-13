class_name PatrolBehaviour
extends AiGroup
## Guards walking a PatrolRoute (PLAN 2.6, ADR 0010), as a small state machine:
##
##   patrol -> (waypoint reached) -> pause (look ahead, then aside) -> patrol ...
##   patrol / pause -> (a guard grew suspicious, or the faction is suspicious of
##       something close) -> investigate (walk there, look around) -> patrol
##   any -> (the faction is alerted) -> hunt (go where the intruder was last
##       noticed, attack what it sees) -> (alert over) -> patrol
##
## It only knows what its own guards noticed (their watchers) and what its faction
## knows (alert level and position, through the port); every order is a Command.
## Without a route the guards hold where they stand (reinforcements, sentries).

const PATROL: StringName = &"patrol"
const PAUSE: StringName = &"pause"
const INVESTIGATE: StringName = &"investigate"
const HUNT: StringName = &"hunt"
## A waypoint counts as reached within this distance.
const REACH: float = 3.0
## A guard this suspicious goes to look.
const INVESTIGATE_AT: float = 0.4
## The faction's suspicion draws guards within this distance of where it was noticed.
const INVESTIGATE_RADIUS: float = 40.0
## Sim ticks spent looking around where something was noticed.
const LOOK_AROUND_TICKS: int = 60
## Longest walk to anything before giving up on it, in sim ticks.
const LEG_TIMEOUT: int = 600
## Hunting re-orders when the alert position moved this far.
const HUNT_SHIFT: float = 6.0

var route: PatrolRoute = null
## Index of the waypoint walked to or paused at.
var index: int = 0
var direction: int = 1
## Where guards without a route stand.
var post: Vector3 = Vector3.ZERO
## Where it is investigating (Vector3.INF: nowhere).
var investigate_point: Vector3 = Vector3.INF
## Times it went to investigate, and hunts (for logs and tests).
var investigations: int = 0
var hunts: int = 0


func _init(p_port: AiPort, p_route: PatrolRoute, p_members: Array[Unit]) -> void:
	super(p_port, null, p_members)
	route = p_route
	post = centroid()
	var me: WeakRef = weakref(self)
	machine.add_state(PATROL, PatrolState.new(me))
	machine.add_state(PAUSE, PauseState.new(me))
	machine.add_state(INVESTIGATE, InvestigateState.new(me))
	machine.add_state(HUNT, HuntState.new(me))


func start() -> void:
	machine.start(PATROL)


## The point it is walking to on its route (its post without one).
func waypoint() -> Vector3:
	if route == null or route.waypoints.is_empty():
		return post
	return route.waypoints[index]


## Moves on to the next waypoint of the route.
func advance() -> void:
	if route == null or route.waypoints.is_empty():
		return
	var next: Vector2i = route.next_index(index, direction)
	index = next.x
	direction = next.y


## True if the faction is alerted.
func alerted() -> bool:
	return port.alert_level() == StealthSystem.LEVEL_ALERTED


## Where to look, if anything calls for it: the most suspicious guard's last notice,
## else where the suspicious faction noticed something nearby. Vector3.INF if nothing.
func point_of_interest() -> Vector3:
	var best: float = INVESTIGATE_AT
	var point: Vector3 = Vector3.INF
	for unit: Unit in members:
		if unit.watcher != null and unit.watcher.has_noticed and unit.suspicion >= best:
			best = unit.suspicion
			point = unit.watcher.last_noticed
	if point != Vector3.INF:
		return point
	if port.alert_level() != StealthSystem.LEVEL_SUSPICIOUS:
		return Vector3.INF
	var noticed: Vector3 = port.alert_position()
	if noticed != Vector3.INF and flat_distance(noticed, centroid()) <= INVESTIGATE_RADIUS:
		return noticed
	return Vector3.INF


## True when the members stand near `point` or have stopped walking.
func arrived_at(point: Vector3) -> bool:
	var spread_out: float = sqrt(maxf(members.size() - 1.0, 0.0)) * 1.6
	return share_within(point, REACH + spread_out) >= 0.5 or idle_share() >= 1.0


## Turns the standing members to look toward `point`.
func look_toward(point: Vector3) -> void:
	port.push(FaceCommand.new(port.faction, _as_nodes(members), point))


## The nearest enemy the group sees, or null.
func nearest_enemy() -> Node3D:
	var centre: Vector3 = centroid()
	var best: Node3D = null
	var best_distance: float = INF
	var reach: float = 24.0 + minf(spread(), 20.0)
	for enemy: Node3D in port.seen_enemies(centre, reach):
		var distance: float = flat_distance(AttackCommand.position_of(enemy), centre)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


class PatrolBaseState:
	extends State

	var _patrol: WeakRef

	func _init(patrol: WeakRef) -> void:
		_patrol = patrol

	func behaviour() -> PatrolBehaviour:
		var value: Variant = _patrol.get_ref()
		if value == null:
			return null
		var found: PatrolBehaviour = value
		return found

	## Hunt beats investigating, which beats the route.
	func interrupt() -> StringName:
		var b: PatrolBehaviour = behaviour()
		if b.alerted():
			return HUNT
		var point: Vector3 = b.point_of_interest()
		if point != Vector3.INF:
			b.investigate_point = point
			return INVESTIGATE
		return &""


class PatrolState:
	extends PatrolBaseState

	var _started: int = 0

	func enter(_previous: StringName) -> void:
		var b: PatrolBehaviour = behaviour()
		_started = b.port.now()
		b.order_move(b.waypoint())

	func tick(_sim_tick: int) -> StringName:
		var next: StringName = interrupt()
		if next != &"":
			return next
		var b: PatrolBehaviour = behaviour()
		if b.arrived_at(b.waypoint()) or b.port.now() - _started > LEG_TIMEOUT:
			return PAUSE
		return &""


class PauseState:
	extends PatrolBaseState

	var _until: int = 0
	var _looked_aside: bool = false
	var _aside: Vector3 = Vector3.ZERO

	func enter(_previous: StringName) -> void:
		var b: PatrolBehaviour = behaviour()
		var pause: float = 2.0
		var here: Vector3 = b.waypoint()
		var ahead: Vector3 = here + b.route.facing * 10.0 if b.route != null else here
		if b.route != null:
			pause = b.route.pause_at(b.index)
			if b.route.waypoints.size() > 1:
				var next: Vector2i = b.route.next_index(b.index, b.direction)
				ahead = b.route.waypoints[next.x]
		_until = b.port.now() + CommanderDifficulty.ticks(pause)
		_looked_aside = false
		var forward: Vector3 = ahead - here
		forward.y = 0.0
		if forward.length_squared() < 0.01:
			forward = Vector3.FORWARD
		_aside = here + forward.normalized().rotated(Vector3.UP, PI * 0.5) * 10.0
		b.look_toward(ahead)

	func tick(_sim_tick: int) -> StringName:
		var next: StringName = interrupt()
		if next != &"":
			return next
		var b: PatrolBehaviour = behaviour()
		var now: int = b.port.now()
		if b.route == null or b.route.waypoints.size() <= 1:
			return &""
		if not _looked_aside and now >= _until - CommanderDifficulty.ticks(0.8):
			_looked_aside = true
			b.look_toward(_aside)
		if now >= _until:
			b.advance()
			return PATROL
		return &""


class InvestigateState:
	extends PatrolBaseState

	var _started: int = 0
	var _arrived_at: int = -1
	var _turns: int = 0

	func enter(_previous: StringName) -> void:
		var b: PatrolBehaviour = behaviour()
		b.investigations += 1
		_started = b.port.now()
		_arrived_at = -1
		_turns = 0
		b.order_move(b.investigate_point)

	func tick(_sim_tick: int) -> StringName:
		var b: PatrolBehaviour = behaviour()
		if b.alerted():
			return HUNT
		var now: int = b.port.now()
		if _arrived_at < 0:
			# Something new caught a guard's eye on the way: go there instead.
			var point: Vector3 = b.point_of_interest()
			if point != Vector3.INF and AiGroup.flat_distance(point, b.investigate_point) > 4.0:
				b.investigate_point = point
				b.order_move(point)
			if b.arrived_at(b.investigate_point) or now - _started > LEG_TIMEOUT:
				_arrived_at = now
			return &""
		var looked: int = (now - _arrived_at) / 20
		if looked > _turns:
			_turns = looked
			var around: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, _turns * PI * 0.66)
			b.look_toward(b.investigate_point + around * 10.0)
		if now - _arrived_at >= LOOK_AROUND_TICKS:
			b.investigate_point = Vector3.INF
			return PATROL
		return &""


class HuntState:
	extends PatrolBaseState

	var _ordered_at: Vector3 = Vector3.INF
	var _target: Node3D = null

	func enter(_previous: StringName) -> void:
		var b: PatrolBehaviour = behaviour()
		b.hunts += 1
		_ordered_at = Vector3.INF
		_target = null

	func tick(_sim_tick: int) -> StringName:
		var b: PatrolBehaviour = behaviour()
		if not b.alerted():
			return PATROL
		var enemy: Node3D = b.nearest_enemy()
		if enemy != null:
			if enemy != _target or b.idle_share() > 0.5:
				_target = enemy
				b.order_attack(enemy)
			return &""
		_target = null
		var point: Vector3 = b.port.alert_position()
		if point == Vector3.INF:
			return &""
		var moved: bool = (
			_ordered_at == Vector3.INF or AiGroup.flat_distance(point, _ordered_at) > HUNT_SHIFT
		)
		if moved or (b.idle_share() >= 1.0 and not b.arrived_at(point) and b.may_reorder()):
			_ordered_at = point
			b.order_move(point)
		return &""
