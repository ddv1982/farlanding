class_name MachineKeeper
extends RefCounted
## How the enemy commander plays Hollow Meridian's engines (ADR 0017), run on each of
## its decisions. Power on that planet comes from the engines, so it plays by the same
## rule as the player:
##
## - it keeps `machines_wanted` engines running: an idle builder goes to reactivate the
##   nearest engine it may claim that it has explored or that stands by its base (one
##   claim at a time) with an escort of idle armed units, `machine_escort` of them and
##   more to match the guards it has seen there; it also takes over the player's (when
##   the profile allows that);
## - it remembers the Custodians it has seen standing by each engine (one it has not
##   seen guarded counts as a Warden's worth: every engine on the deck is guarded), sends
##   an escort that can win that fight, and passes over engines it cannot field one
##   for; a worker goes alone only to an engine it has seen without guards;
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
## An escort must reach the guards' weighted strength this many times over; an engine
## it cannot field that escort for is passed over. (It was a quarter of the guards'
## price, and the guards won: six Rangers are needed for one Warden. ADR 0018.)
const ESCORT_RATIO: float = 1.5
## Points round an engine that must be in sight for its guard count to stand.
const AROUND_SAMPLES: int = 8
## Guards assumed at an engine whose surroundings it has not seen (a Warden's price).
const UNSEEN_GUARDS: float = 600.0
## An engine where a claim's worker was killed is left alone this long (3 min), so
## builders are not fed one after another into its guards (found by the balance
## harness, ADR 0018: 26 Fabricators and 54 Riggers lost in one finale).
const FAILED_CLAIM_TICKS: int = 1800

var port: AiPort
var world: SimWorld
var profile: CommanderProfile
var faction: int = 1
## The engine being claimed and by whom: entity ids (-1 = none), and when it began.
var claim_engine: int = -1
var claim_worker: int = -1
var claim_tick: int = 0
## Engine id -> strength of the guards last seen by it (Custodians, and enemies counted
## up to Custodian terms: see `_guard_strength`).
var guards_seen: Dictionary[int, float] = {}
## Engine id -> sim tick defenders were last sent.
var _defended: Dictionary[int, int] = {}
## Engine id -> sim tick before which it is not claimed again (a worker died there).
var _avoid_until: Dictionary[int, int] = {}


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


## The Custodians the faction sees by each engine it sees. A count stands only once it
## sees all around the engine; a glimpse may only raise it (found by the balance
## harness, ADR 0018: with the engine in sight and its Warden just outside it, the
## engine counted as unguarded).
func _look_for_guards(machinery: MachinerySystem) -> void:
	for engine: Building in machinery.engines():
		if not _sees_area(engine.position):
			continue
		var strength: float = 0.0
		for unit: Unit in world.units:
			if unit.faction == faction or unit.is_dead:
				continue
			if AiGroup.flat_distance(unit.sim_position(), engine.position) > GUARD_RADIUS:
				continue
			if world.vision == null or world.vision.can_see(faction, unit):
				strength += _guard_strength(unit)
		for building: Building in world.buildings:
			if building.faction == faction or building.is_dead or building.machine != null:
				continue
			if AiGroup.flat_distance(building.position, engine.position) > GUARD_RADIUS:
				continue
			if world.vision == null or world.vision.can_see(faction, building):
				strength += _guard_strength(building)
		if _sees_around(engine.position):
			guards_seen[engine.entity_id] = strength
		elif strength > guards_seen.get(engine.entity_id, 0.0):
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
	if _claim_running(machinery) or _claim_arriving(machinery):
		return sent
	_note_failed_claim()
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
		if not machinery.can_claim(engine, faction) or not _known(engine.position, home):
			continue
		if _avoid_until.get(engine.entity_id, -1) > port.now():
			continue
		var owned_by_enemy: bool = (
			not engine.machine.is_dormant() and not Factions.is_custodian(engine.faction)
		)
		if owned_by_enemy and not profile.machine_takeover:
			continue
		# No worker goes where its escort could not win; alone only where no guards are.
		var needed: float = escort_needed(engine)
		if needed > 0.0 and needed > available:
			continue
		var score: float = AiGroup.flat_distance(engine.position, home) + needed * GUARD_COST
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
	if _explored(best.position):
		port.push(ReactivateCommand.new(faction, [worker] as Array[Node3D], best))
	else:
		_move([worker] as Array[Unit], best.position)  # an engine by the base: look first
	sent.append(worker)
	claim_engine = best.entity_id
	claim_worker = worker.entity_id
	claim_tick = port.now()
	# An escort goes along when there is one, large enough for the guards.
	var escort: Array[Unit] = _take_escort(free, best.position, escort_needed(best))
	if not escort.is_empty():
		_move(escort, best.position)
		sent.append_array(escort)
	return sent


## Strength an escort to `engine` must reach: the guards seen there (a Warden's worth
## where it has not looked), weighted, ESCORT_RATIO times over; 0 where it saw none.
func escort_needed(engine: Building) -> float:
	var guards: float = guards_seen.get(engine.entity_id, UNSEEN_GUARDS)
	return guards * GUARD_WEIGHT * ESCORT_RATIO


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


## A claim whose worker was killed marks its engine to be left alone for a while.
func _note_failed_claim() -> void:
	if claim_engine < 0 or claim_worker < 0:
		return
	var worker: Unit = world.entity(claim_worker) as Unit
	if worker == null or worker.is_dead:
		_avoid_until[claim_engine] = port.now() + FAILED_CLAIM_TICKS


## True while the current claim's worker walks to an engine by the base it has not seen
## yet; once it sees it, the work starts.
func _claim_arriving(machinery: MachinerySystem) -> bool:
	if claim_engine < 0:
		return false
	var engine: Building = world.entity(claim_engine) as Building
	var worker: Unit = world.entity(claim_worker) as Unit
	if engine == null or worker == null or worker.is_dead:
		return false
	if not machinery.can_claim(engine, faction) or port.now() - claim_tick > CLAIM_TIMEOUT_TICKS:
		return false
	if worker.reactivator == null or worker.reactivator.target == engine:
		return false
	if _explored(engine.position):
		port.push(ReactivateCommand.new(faction, [worker] as Array[Node3D], engine))
		return true
	return worker.locomotion.is_travelling()


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


## True if the faction knows the engine at `at` is there: its ground is explored, or it
## stands by its own base (a commander knows the ground it landed on; found by the
## balance harness, ADR 0018: its scout explored the far side first, so the Combine
## crossed the deck for the player's engines before taking its own).
func _known(at: Vector3, home: Vector3) -> bool:
	return AiGroup.flat_distance(at, home) <= profile.base_radius or _explored(at)


func _explored(at: Vector3) -> bool:
	return world.vision == null or world.vision.grid.is_explored(faction, at)


func _sees_area(at: Vector3) -> bool:
	return world.vision == null or world.vision.grid.is_visible(faction, at)


## What `entity` adds to an engine's guards, in Custodian terms: Custodians at their
## strength (weighted down later by GUARD_WEIGHT), an enemy's armed units and towers at
## full strength (found by the balance harness, ADR 0018: the Combine kept sending a
## Rigger and three escorts to take over engines the player's army stood by).
static func _guard_strength(entity: Node3D) -> float:
	var strength: float = AiKnowledge.strength_of(entity)
	var unit: Unit = entity as Unit
	if unit != null and Factions.is_custodian(unit.faction):
		return strength
	return strength / GUARD_WEIGHT


## True if the faction sees the ground all round `at`, out to most of the guard radius.
## Not the whole radius on purpose: a worker's own sight does not reach that far, so
## requiring it made every engine need an escort and stalled the finale (ADR 0018). A
## guard missed at the very edge costs one worker, and the engine is then avoided.
func _sees_around(at: Vector3) -> bool:
	for i: int in AROUND_SAMPLES:
		var angle: float = TAU * i / AROUND_SAMPLES
		var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * GUARD_RADIUS * 0.75
		if not _sees_area(at + offset):
			return false
	return _sees_area(at)


func to_dict() -> Dictionary:
	var seen: Dictionary = {}
	for id: int in guards_seen:
		seen[str(id)] = guards_seen[id]
	var defended: Dictionary = {}
	for id: int in _defended:
		defended[str(id)] = _defended[id]
	var avoid: Dictionary = {}
	for id: int in _avoid_until:
		avoid[str(id)] = _avoid_until[id]
	return {
		"version": SAVE_VERSION,
		"avoid": avoid,
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
	_avoid_until.clear()
	var avoid: Dictionary = data.get("avoid", {})
	for key: Variant in avoid:
		var until: int = avoid[key]
		_avoid_until[int(str(key))] = until
	_defended.clear()
	var defended: Dictionary = data.get("defended", {})
	for key: Variant in defended:
		var tick: int = defended[key]
		_defended[int(str(key))] = tick
