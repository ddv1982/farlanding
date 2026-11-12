class_name AttackGroup
extends AiGroup
## A group of armed units sent out by the commander (PLAN 3.5). States:
##
##   gather -> advance -> fight -> advance ... -> retreat -> done
##                 \-> regroup -/        \-> retreat (badly outnumbered or bled out)
##
## *gather* meets at the staging point, *advance* moves on the target (the next one
## once it is reached, from `next_target`), *regroup* pulls a strung-out column
## together, *fight* focuses fire on the most dangerous enemy in sight, *retreat* goes
## home and ends the group. A defence group starts at *advance* and goes home once its
## area is clear; a last stand never retreats.

const MODE_ATTACK: StringName = &"attack"
const MODE_DEFEND: StringName = &"defend"
const MODE_LAST_STAND: StringName = &"last_stand"

const GATHER: StringName = &"gather"
const ADVANCE: StringName = &"advance"
const REGROUP: StringName = &"regroup"
const FIGHT: StringName = &"fight"
const RETREAT: StringName = &"retreat"
const DONE: StringName = &"done"

## A target counts as reached within this distance of the group's centre.
const ARRIVE_RADIUS: float = 12.0
## Behaviour steps with no enemy in sight before a fight counts as over.
const QUIET_STEPS: int = 3
## Re-ordered moves that left the group idle short of its goal before it gives up
## (the goal cannot be reached).
const MAX_STUCK: int = 3
## Retreat ends this close to home (or after RETREAT_TIMEOUT ticks).
const HOME_RADIUS: float = 18.0
const RETREAT_TIMEOUT: int = 900
## A regroup ends early once every member has stopped for this long (no one is coming).
const SETTLE_TICKS: int = 20

var mode: StringName = MODE_ATTACK
var target: Vector3 = Vector3.ZERO
var home: Vector3 = Vector3.ZERO
var staging: Vector3 = Vector3.ZERO
## `func(from: Vector3) -> Vector3`: the next place to attack once `target` is
## reached and clear, or Vector3.INF for none. Unset: go home.
var next_target: Callable = Callable()
## The enemy the group is firing on.
var focus: Node3D = null
## Why it last retreated (&"outnumbered", &"losses", &"unreachable", &"recalled",
## &"no_target", &"clear").
var retreat_reason: StringName = &""


func _init(
	p_port: AiPort,
	p_profile: CommanderProfile,
	p_members: Array[Unit],
	p_mode: StringName,
	p_target: Vector3,
	p_home: Vector3,
	p_staging: Vector3,
) -> void:
	super(p_port, p_profile, p_members)
	mode = p_mode
	target = p_target
	home = p_home
	staging = p_staging
	var me: WeakRef = weakref(self)
	machine.add_state(GATHER, GatherState.new(me))
	machine.add_state(ADVANCE, AdvanceState.new(me))
	machine.add_state(REGROUP, RegroupState.new(me))
	machine.add_state(FIGHT, FightState.new(me))
	machine.add_state(RETREAT, RetreatState.new(me))
	machine.add_state(DONE, DoneState.new(me))


## Starts the behaviour: an attack gathers first, a defence or last stand goes at once.
func start() -> void:
	machine.start(GATHER if mode == MODE_ATTACK else ADVANCE)


## Called home by the commander (its base is under attack).
func recall() -> void:
	if finished or state() == RETREAT or state() == DONE:
		return
	retreat_reason = &"recalled"
	machine.transition_to(RETREAT)


## True when the group sees enemies close enough to fight.
func in_contact() -> bool:
	return not seen_enemies().is_empty()


## Moves on after a target area is reached and clear: the next target, else home.
## Returns the state to enter.
func move_on() -> StringName:
	var next: Vector3 = Vector3.INF
	var here: Vector3 = centroid()
	if next_target.is_valid():
		next = next_target.call(here)
	if next != Vector3.INF and flat_distance(next, here) <= ARRIVE_RADIUS + body_radius():
		next = Vector3.INF  # Already there: not a new target.
	if mode == MODE_DEFEND or next == Vector3.INF:
		if mode == MODE_LAST_STAND and next == Vector3.INF:
			return &""
		retreat_reason = &"clear" if mode == MODE_DEFEND else &"no_target"
		return RETREAT
	target = next
	order_move(target)
	return &""


## The enemy to fire on: armed units first, then armed buildings, then anything, the
## nearest to the group's centre within each class.
static func pick_focus(enemies: Array[Node3D], from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score: float = INF
	for enemy: Node3D in enemies:
		var rank: float = 0.0
		if not Combat.is_armed(enemy):
			rank = 2000.0
		elif enemy is Building:
			rank = 1000.0
		var score: float = rank + Combat.reach_to(enemy, from)
		if score < best_score:
			best = enemy
			best_score = score
	return best


## Base of this group's states: holds the group weakly (no reference cycle).
class GroupState:
	extends State

	var _group: WeakRef

	func _init(group: WeakRef) -> void:
		_group = group

	func group() -> AttackGroup:
		var value: Variant = _group.get_ref()
		if value == null:
			return null
		var found: AttackGroup = value
		return found


class GatherState:
	extends GroupState

	var _started: int = 0

	func enter(_previous: StringName) -> void:
		var g: AttackGroup = group()
		_started = g.port.now()
		g.order_move(g.staging)

	func tick(_sim_tick: int) -> StringName:
		var g: AttackGroup = group()
		if g.in_contact():
			return FIGHT
		var timeout: int = CommanderDifficulty.ticks(g.profile.gather_timeout_seconds)
		if g.gathered_at(g.staging, g.profile.gather_radius):
			return ADVANCE
		if g.port.now() - _started > timeout:
			# Waited long enough: go with those who made it.
			g.drop_stragglers(g.staging, g.profile.gather_radius * 2.0)
			return ADVANCE
		return &""


class AdvanceState:
	extends GroupState

	## Metres the group must close on its target between re-orders to count as getting
	## somewhere.
	const PROGRESS: float = 5.0

	var _stuck: int = 0
	var _best: float = INF

	func enter(previous: StringName) -> void:
		var g: AttackGroup = group()
		if previous != REGROUP:
			_stuck = 0
			_best = INF
		g.order_move(g.target)

	func tick(_sim_tick: int) -> StringName:
		var g: AttackGroup = group()
		if g.in_contact():
			return FIGHT
		var distance: float = AiGroup.flat_distance(g.centroid(), g.target)
		if distance <= ARRIVE_RADIUS + g.body_radius():
			return g.move_on()
		if g.strung_out(g.profile.regroup_spread):
			return REGROUP
		if g.idle_share() >= 0.5 and g.may_reorder():
			# Idle short of the goal: count it as stuck only when no closer than at the
			# last re-order (the goal cannot be reached from here).
			if distance < _best - PROGRESS:
				_best = distance
				_stuck = 0
			else:
				_stuck += 1
			if _stuck > MAX_STUCK:
				g.retreat_reason = &"unreachable"
				return RETREAT
			g.order_move(g.target)
		return &""


class RegroupState:
	extends GroupState

	var _started: int = 0
	var _meet: Vector3 = Vector3.ZERO

	func enter(_previous: StringName) -> void:
		var g: AttackGroup = group()
		_started = g.port.now()
		var centre: Vector3 = g.centroid()
		var meet: Vector3 = g.members[0].sim_position()
		for unit: Unit in g.members:
			if (
				AiGroup.flat_distance(unit.sim_position(), centre)
				< AiGroup.flat_distance(meet, centre)
			):
				meet = unit.sim_position()
		_meet = meet
		g.order_move(meet)

	func tick(_sim_tick: int) -> StringName:
		var g: AttackGroup = group()
		if g.in_contact():
			return FIGHT
		var timeout: int = CommanderDifficulty.ticks(g.profile.gather_timeout_seconds)
		if g.gathered_at(g.centroid(), g.profile.regroup_spread * 0.5, 0.85):
			return ADVANCE
		var settled: bool = g.idle_share() >= 1.0 and g.port.now() - _started > SETTLE_TICKS
		if settled or g.port.now() - _started > timeout:
			# Some cannot catch up (another route, stuck): go on without them.
			g.drop_stragglers(_meet, g.profile.regroup_spread)
			return ADVANCE
		return &""


class FightState:
	extends GroupState

	var _quiet: int = 0

	func enter(_previous: StringName) -> void:
		_quiet = 0
		group().focus = null

	func tick(_sim_tick: int) -> StringName:
		var g: AttackGroup = group()
		var enemies: Array[Node3D] = g.seen_enemies()
		if enemies.is_empty():
			_quiet += 1
			if _quiet < QUIET_STEPS:
				return &""
			g.focus = null
			if g.mode == MODE_DEFEND:
				g.retreat_reason = &"clear"
				return RETREAT
			return ADVANCE
		_quiet = 0
		if g.mode == MODE_ATTACK:
			var theirs: float = 0.0
			for enemy: Node3D in enemies:
				theirs += AiKnowledge.strength_of(enemy)
			var ours: float = g.strength()
			if theirs > ours * g.profile.retreat_ratio:
				g.retreat_reason = &"outnumbered"
				return RETREAT
			if ours < g.initial_strength * g.profile.retreat_losses:
				g.retreat_reason = &"losses"
				return RETREAT
		var pick: Node3D = AttackGroup.pick_focus(enemies, g.centroid())
		if pick != g.focus or (g.idle_share() > 0.0 and g.may_reorder()):
			g.focus = pick
			g.order_attack(pick)
		return &""


class RetreatState:
	extends GroupState

	var _started: int = 0
	var _reorders: int = 0

	func enter(_previous: StringName) -> void:
		var g: AttackGroup = group()
		_started = g.port.now()
		_reorders = 0
		g.focus = null
		g.order_move(g.home)

	func tick(_sim_tick: int) -> StringName:
		var g: AttackGroup = group()
		if AiGroup.flat_distance(g.centroid(), g.home) <= HOME_RADIUS + g.body_radius():
			return DONE
		if g.port.now() - _started > RETREAT_TIMEOUT:
			return DONE
		if g.idle_share() >= 0.5 and g.may_reorder():
			_reorders += 1
			if _reorders > MAX_STUCK:
				return DONE
			g.order_move(g.home)
		return &""


class DoneState:
	extends GroupState

	func enter(_previous: StringName) -> void:
		group().finish()
