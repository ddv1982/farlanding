class_name MachineKeeper
extends RefCounted
## How the enemy commander plays Hollow Meridian's engines (ADR 0017), run on each of
## its decisions. Power on that planet comes from the engines, so it plays by the same
## rule as the player:
##
## - it keeps `machines_wanted` engines running: an idle builder goes to reactivate the
##   nearest engine it may claim that it has explored (one claim at a time) with an
##   escort of idle armed units, `machine_escort` of them and more to match the
##   Custodians it has seen there; it also takes over the player's (when the profile
##   allows that);
## - it remembers the Custodians it has seen standing by each engine, and passes over
##   engines guarded more heavily than all its free armed units could handle;
## - it sends defenders to an engine of its own that is hurt, shut down or being taken
##   over.
##
## It reads only what its faction knows: engines are landmarks once their ground is
## explored, who runs one and the Custodians by it only while it sees them. It acts
## only through Commands.

const SAVE_VERSION: int = 1
## Custodians count as guarding an engine within this distance of it, in metres.
const GUARD_RADIUS: float = 18.0
## A claim is given up when its worker has done nothing for this long, in sim ticks.
const CLAIM_TIMEOUT_TICKS: int = 900
## The same engine is not defended again within this many sim ticks.
const DEFEND_TICKS: int = 300
## Guards seen are worth this many times their strength when picking an engine.
const GUARD_COST: float = 0.02
## Custodians are priced high for what they fight like: their strength counts this much.
const GUARD_WEIGHT: float = 0.5
## An engine is skipped when its guards outweigh every free armed unit this many times;
## otherwise the escort grows until it is at least the guards' weight over this.
const GUARD_LIMIT: float = 2.0

var port: AiPort
var world: SimWorld
var profile: CommanderProfile
var faction: int = 1
## The engine being claimed and by whom: entity ids (-1 = none), and when it began.
var claim_engine: int = -1
var claim_worker: int = -1
var claim_tick: int = 0
## Engine id -> strength of the Custodians last seen guarding it.
var guards_seen: Dictionary[int, float] = {}
## Engine id -> sim tick defenders were last sent.
var _defended: Dictionary[int, int] = {}


func _init(p_port: AiPort, p_world: SimWorld, p_profile: CommanderProfile) -> void:
	port = p_port
	world = p_world
	profile = p_profile
	faction = port.faction


## One decision. `home` is the base, `builders` its idle builders, `guards` its idle
## armed units. Returns the units it gave orders to (the caller leaves them alone).
func decide(home: Vector3, builders: Array[Unit], guards: Array[Unit]) -> Array[Unit]:
	var used: Array[Unit] = []
	var machinery: MachinerySystem = world.planet as MachinerySystem
	if machinery == null or profile.machines_wanted <= 0:
		return used
	_look_for_guards(machinery)
	var free: Array[Unit] = guards.duplicate()
	used.append_array(_defend(machinery, free))
	used.append_array(_claim(machinery, home, builders, free))
	return used


## The Custodians the faction sees by each engine it sees.
func _look_for_guards(machinery: MachinerySystem) -> void:
	for engine: Building in machinery.engines():
		if not _sees_area(engine.position):
			continue
		var strength: float = 0.0
		for unit: Unit in world.units:
			if not Factions.is_custodian(unit.faction) or unit.is_dead:
				continue
			if AiGroup.flat_distance(unit.sim_position(), engine.position) > GUARD_RADIUS:
				continue
			if world.vision == null or world.vision.can_see(faction, unit):
				strength += AiKnowledge.strength_of(unit)
		guards_seen[engine.entity_id] = strength


func _defend(machinery: MachinerySystem, free: Array[Unit]) -> Array[Unit]:
	var sent: Array[Unit] = []
	if profile.machine_defenders <= 0:
		return sent
	var now: int = port.now()
	var watched: Array[Building] = machinery.held_by(faction)
	watched.append_array(_shut_down_own(machinery))
	for engine: Building in watched:
		var machine: Machine = engine.machine
		var threatened: bool = (
			machine.is_shut_down()
			or engine.health.fraction() < 0.9
			or (machine.claimant >= 0 and machine.claimant != faction)
		)
		if not threatened:
			continue
		if now - _defended.get(engine.entity_id, -DEFEND_TICKS) < DEFEND_TICKS:
			continue
		var squad: Array[Unit] = _take_nearest(free, engine.position, profile.machine_defenders)
		if squad.is_empty():
			continue
		_defended[engine.entity_id] = now
		_move(squad, engine.position)
		sent.append_array(squad)
	return sent


func _claim(
	machinery: MachinerySystem, home: Vector3, builders: Array[Unit], free: Array[Unit]
) -> Array[Unit]:
	var sent: Array[Unit] = []
	if _claim_running(machinery):
		return sent
	claim_engine = -1
	claim_worker = -1
	if machinery.held_by(faction).size() >= profile.machines_wanted or builders.is_empty():
		return sent
	var available: float = 0.0
	for unit: Unit in free:
		available += AiKnowledge.strength_of(unit)
	var best: Building = null
	var best_score: float = INF
	for engine: Building in machinery.engines():
		if not machinery.can_claim(engine, faction) or not _explored(engine.position):
			continue
		var owned_by_enemy: bool = (
			not engine.machine.is_dormant() and not Factions.is_custodian(engine.faction)
		)
		if owned_by_enemy and not profile.machine_takeover:
			continue
		var guarded: float = guards_seen.get(engine.entity_id, 0.0) * GUARD_WEIGHT
		if guarded > 0.0 and guarded > available * GUARD_LIMIT:
			continue
		var score: float = AiGroup.flat_distance(engine.position, home) + guarded * GUARD_COST
		if owned_by_enemy and engine.machine.is_running():
			score += 40.0  # a takeover is slow and fought over: prefer free engines
		if score < best_score:
			best = engine
			best_score = score
	if best == null:
		return sent
	var worker: Unit = builders[0]
	for builder: Unit in builders:
		if (
			AiGroup.flat_distance(builder.sim_position(), best.position)
			< AiGroup.flat_distance(worker.sim_position(), best.position)
		):
			worker = builder
	port.push(ReactivateCommand.new(faction, [worker] as Array[Node3D], best))
	sent.append(worker)
	claim_engine = best.entity_id
	claim_worker = worker.entity_id
	claim_tick = port.now()
	# Every engine on the deck is guarded: an escort always goes, larger for known guards.
	var needed: float = guards_seen.get(best.entity_id, 0.0) * GUARD_WEIGHT / GUARD_LIMIT
	var escort: Array[Unit] = _take_escort(free, best.position, needed)
	if not escort.is_empty():
		_move(escort, best.position)
		sent.append_array(escort)
	return sent


## The nearest units of `pool` to `at`, at least `machine_escort` of them (as many as
## there are) and more until their strength reaches `needed`; taken out of `pool`.
func _take_escort(pool: Array[Unit], at: Vector3, needed: float) -> Array[Unit]:
	var sorted: Array[Unit] = _take_nearest(pool.duplicate(), at, pool.size())
	var taken: Array[Unit] = []
	var strength: float = 0.0
	for unit: Unit in sorted:
		if taken.size() >= profile.machine_escort and strength >= needed:
			break
		taken.append(unit)
		strength += AiKnowledge.strength_of(unit)
	for unit: Unit in taken:
		pool.erase(unit)
	return taken


## True while the current claim goes on: its worker lives, still works on it, and the
## engine is not ours yet.
func _claim_running(machinery: MachinerySystem) -> bool:
	if claim_engine < 0:
		return false
	var engine: Building = world.entity(claim_engine) as Building
	var worker: Unit = world.entity(claim_worker) as Unit
	if engine == null or worker == null or worker.is_dead:
		return false
	if not machinery.can_claim(engine, faction):
		return false
	if port.now() - claim_tick > CLAIM_TIMEOUT_TICKS:
		return false
	return worker.reactivator != null and worker.reactivator.target == engine


func _shut_down_own(machinery: MachinerySystem) -> Array[Building]:
	var found: Array[Building] = []
	for engine: Building in machinery.engines():
		if engine.faction == faction and engine.machine.is_shut_down():
			found.append(engine)
	return found


## Up to `count` units of `pool` nearest `at`, taken out of `pool`.
static func _take_nearest(pool: Array[Unit], at: Vector3, count: int) -> Array[Unit]:
	var sorted: Array[Unit] = pool.duplicate()
	sorted.sort_custom(
		func(a: Unit, b: Unit) -> bool:
			return (
				AiGroup.flat_distance(a.sim_position(), at)
				< AiGroup.flat_distance(b.sim_position(), at)
			)
	)
	var taken: Array[Unit] = sorted.slice(0, count)
	for unit: Unit in taken:
		pool.erase(unit)
	return taken


func _move(units: Array[Unit], at: Vector3) -> void:
	var goal: Vector3 = world.paths.closest_point(at)
	port.push(MoveCommand.new(MoveCommand.KIND_MOVE, faction, AiGroup._as_nodes(units), goal))


func _explored(at: Vector3) -> bool:
	return world.vision == null or world.vision.grid.is_explored(faction, at)


func _sees_area(at: Vector3) -> bool:
	return world.vision == null or world.vision.grid.is_visible(faction, at)


func to_dict() -> Dictionary:
	var seen: Dictionary = {}
	for id: int in guards_seen:
		seen[str(id)] = guards_seen[id]
	var defended: Dictionary = {}
	for id: int in _defended:
		defended[str(id)] = _defended[id]
	return {
		"version": SAVE_VERSION,
		"claim_engine": claim_engine,
		"claim_worker": claim_worker,
		"claim_tick": claim_tick,
		"guards_seen": seen,
		"defended": defended,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	if version != SAVE_VERSION:
		return
	claim_engine = data.get("claim_engine", -1)
	claim_worker = data.get("claim_worker", -1)
	claim_tick = data.get("claim_tick", 0)
	guards_seen.clear()
	var seen: Dictionary = data.get("guards_seen", {})
	for key: Variant in seen:
		var strength: float = seen[key]
		guards_seen[int(str(key))] = strength
	_defended.clear()
	var defended: Dictionary = data.get("defended", {})
	for key: Variant in defended:
		var tick: int = defended[key]
		_defended[int(str(key))] = tick
