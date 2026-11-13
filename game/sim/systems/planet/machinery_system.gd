class_name MachinerySystem
extends PlanetRuleSystem
## Hollow Meridian's old machinery (PLAN 2.5, ADR 0017), played from a MachineryRule.
##
## The engines are the map's Antecedent machines: Buildings whose def is a `machine`,
## each with a Machine component that holds its state (dormant, running, shut down)
## and the work done on it. Units with a Reactivator report their work every tick
## (`report_work`); this system adds it up per engine and hands the engine over once
## the work is done:
##
##   dormant --(reactivated: Events.machine_reactivated)--> running for F
##   running for F --(taken over by G: machine_lost F, machine_reactivated G)--> running for G
##   running for F --(health ran out: machine_lost F)--> shut down --(timer)--> running for F
##
## A shut-down engine may be claimed by anybody but its owner. Work by one faction first
## drains another faction's unfinished progress; work by two at once cancels out; with
## nobody working, progress fades. A worker who starts on an engine disturbs the
## dormant Custodians within the rule's `disturb_radius` (scaled by the worker's
## faction's `custodian_disturb` perk): they wake, see the worker for a while and go
## for it. While the rule plays, Reactors are locked for everyone and buildings that
## are not machines give only part of their power. Engines are public landmarks: the AI
## reads them through `engines()` and knows who runs one only when it sees it.

const SAVE_VERSION: int = 1
## Seconds the Custodians woken by a worker keep seeing it.
const WAKE_REVEAL_SECONDS: float = 12.0
## Radius of that reveal around the worker, in metres.
const WAKE_REVEAL_RADIUS: float = 6.0
## Work within this of complete counts as complete (float sums of tick-sized steps).
const DONE_SLACK: float = 0.0001

var _machinery: MachineryRule = null
var _now: int = 0
var _next_alert_tick: int = 0
## Units that worked on an engine on the last tick (save id -> engine id): a unit not
## in it starts work now and disturbs the Custodians.
var _working: Dictionary[int, int] = {}
var _working_now: Dictionary[int, int] = {}


static func ticks(seconds: float) -> int:
	return roundi(seconds * SimClock.TICK_RATE)


func _setup() -> void:
	_machinery = rule as MachineryRule
	assert(_machinery != null, "MachinerySystem needs a MachineryRule")
	_now = world.context.sim_clock.get_tick() if world.context != null else 0
	world.economy.power_scale = _machinery.headquarters_power_scale
	_lock_buildings()


## Every Antecedent machine in the world.
func engines() -> Array[Building]:
	var found: Array[Building] = []
	for building: Building in world.buildings:
		if is_instance_valid(building) and building.machine != null and not building.is_dead:
			found.append(building)
	return found


## The engines running for `faction`.
func held_by(faction: int) -> Array[Building]:
	var found: Array[Building] = []
	for engine: Building in engines():
		if engine.faction == faction and engine.machine.is_running():
			found.append(engine)
	return found


## How far from an engine's footprint a worker stands, in metres.
func work_range() -> float:
	return _machinery.work_range


## True if units of `faction` may work on `engine` now: it is a machine, and it does
## not run for `faction` already (nor is it `faction`'s own, waiting to restart).
func can_claim(engine: Building, faction: int) -> bool:
	if engine == null or engine.machine == null or engine.is_dead:
		return false
	if faction < 0 or Factions.is_custodian(faction):
		return false
	if engine.faction == faction and not engine.machine.is_dormant():
		return false
	return true


## Seconds one worker of `faction` needs to finish `engine` from scratch.
func seconds_to_claim(engine: Building) -> float:
	if engine.machine.is_running():
		return _machinery.takeover_seconds
	return _machinery.reactivate_seconds


## `worker` worked on `engine` this tick (its Reactivator, standing in reach).
func report_work(engine: Building, worker: Unit) -> void:
	if not can_claim(engine, worker.faction) or worker.is_dead:
		return
	if not engine.machine.workers.has(worker):
		engine.machine.workers.append(worker)
	_working_now[worker.entity_id] = engine.entity_id
	if _working.get(worker.entity_id, -1) != engine.entity_id:
		_disturb(engine, worker)


func indicator_title() -> String:
	return "ENGINES"


func indicator_text(_tick_number: int) -> String:
	var player: int = world.player_faction
	var held: int = held_by(player).size()
	var total: int = engines().size()
	var threatened: Building = _threatened_engine(player)
	if threatened != null:
		return "%d / %d HELD · ONE CONTESTED" % [held, total]
	return "%d / %d HELD" % [held, total]


func indicator_level() -> float:
	var total: int = engines().size()
	return float(held_by(world.player_faction).size()) / total if total > 0 else 0.0


func indicator_alarm() -> bool:
	return _threatened_engine(world.player_faction) != null


func _tick(tick_number: int, dt: float) -> void:
	_now = tick_number
	for engine: Building in engines():
		_tick_engine(engine, dt)
		engine.machine.workers.clear()
	_working = _working_now
	_working_now = {}


func _tick_engine(engine: Building, dt: float) -> void:
	var machine: Machine = engine.machine
	if machine.is_shut_down():
		machine.shutdown_left = maxf(machine.shutdown_left - dt, 0.0)
		if machine.shutdown_left <= 0.0 and machine.progress <= 0.0:
			_restart(engine)
	elif machine.is_running() and engine.health.current <= 0.0:
		_shut_down(engine)
	_work(engine, dt)


## Adds up this tick's work on `engine` and hands it over when it is done.
func _work(engine: Building, dt: float) -> void:
	var machine: Machine = engine.machine
	var by_faction: Dictionary[int, float] = {}
	for worker: Unit in machine.workers:
		if not is_instance_valid(worker) or worker.is_dead:
			continue
		var rate: float = FactionPerks.of(world.perks, worker.faction).scale(
			worker.def.id, FactionPerks.REACTIVATION_RATE
		)
		by_faction[worker.faction] = by_faction.get(worker.faction, 0.0) + rate
	if by_faction.is_empty():
		if machine.progress > 0.0:
			machine.set_progress(
				machine.progress - _machinery.progress_decay * dt, machine.claimant
			)
		return
	if by_faction.size() > 1:
		return  # contested: nobody gets on
	var faction: int = by_faction.keys()[0]
	var amount: float = by_faction[faction] * dt / seconds_to_claim(engine)
	var had: float = machine.progress
	if machine.claimant >= 0 and machine.claimant != faction:
		var left: float = had - amount
		if left > 0.0:
			machine.set_progress(left, machine.claimant)
			return
		# The other side's work is used up: only what is left over counts for us.
		amount = -left
		had = 0.0
	var done: float = had + amount
	machine.set_progress(done, faction)
	if done >= 1.0 - DONE_SLACK:
		_hand_over(engine, faction)


## `engine` now runs for `faction` (reactivated, taken over or claimed while shut down).
func _hand_over(engine: Building, faction: int) -> void:
	var machine: Machine = engine.machine
	var previous: int = engine.faction
	# A shut-down engine was already reported lost when it stopped.
	var was_held: bool = machine.is_running() and not Factions.is_custodian(previous)
	machine.set_progress(0.0, -1)
	machine.shutdown_left = 0.0
	engine.faction = faction
	_refill(engine)
	machine.set_state(Machine.RUNNING)
	if world.vision != null:
		world.vision.add_faction(faction)
		if faction == world.player_faction:
			engine.seen_by_player = true
		world.vision.refresh_building(engine)
	if was_held and previous != faction:
		Events.machine_lost.emit(engine, previous)
		if previous == world.player_faction:
			_alert(&"engine_lost")
	Events.machine_reactivated.emit(engine, faction)
	if faction == world.player_faction:
		Events.advisor_alert.emit(&"engine_online")
	world.economy.update_power(world.buildings)


func _shut_down(engine: Building) -> void:
	var machine: Machine = engine.machine
	machine.shutdown_left = _machinery.shutdown_seconds
	machine.set_progress(0.0, -1)
	machine.set_state(Machine.SHUT_DOWN)
	Events.machine_lost.emit(engine, engine.faction)
	if engine.faction == world.player_faction:
		_alert(&"engine_lost")
	world.economy.update_power(world.buildings)


## A shut-down engine nobody claimed in time runs again for its owner, repaired.
func _restart(engine: Building) -> void:
	_refill(engine)
	engine.machine.set_state(Machine.RUNNING)
	Events.machine_reactivated.emit(engine, engine.faction)
	if engine.faction == world.player_faction:
		Events.advisor_alert.emit(&"engine_online")
	world.economy.update_power(world.buildings)


## Full health for the engine's (new) owner, after its perks (sturdier engines).
func _refill(engine: Building) -> void:
	var health: Health = engine.health
	health.max_health = maxf(
		FactionPerks.of(world.perks, engine.faction).apply(
			engine.def.id, FactionPerks.MAX_HEALTH, engine.def.max_health
		),
		1.0
	)
	health.current = health.max_health
	health.changed.emit(1.0)


## A worker started on `engine`: the dormant Custodians around it wake and go for it.
func _disturb(engine: Building, worker: Unit) -> void:
	var reach: float = (
		_machinery.disturb_radius
		* FactionPerks.of(world.perks, worker.faction).scale(
			worker.def.id, FactionPerks.CUSTODIAN_DISTURB
		)
	)
	var at: Vector3 = engine.position
	var woken: int = 0
	for unit: Unit in world.units:
		if not Factions.is_custodian(unit.faction) or unit.is_dead or unit.dormancy == null:
			continue
		var there: Vector3 = unit.sim_position()
		if Vector2(there.x - at.x, there.z - at.z).length() > reach:
			continue
		if unit.is_dormant:
			unit.dormancy.wake()
			woken += 1
		elif unit.orders == null or not unit.orders.is_idle():
			continue
		if world.vision != null:
			world.vision.reveal_entity(
				unit.faction, worker, WAKE_REVEAL_RADIUS, ticks(WAKE_REVEAL_SECONDS)
			)
		if unit.orders != null:
			unit.orders.engage(worker, there, _machinery.chase_distance)
	if woken > 0 and worker.faction == world.player_faction:
		Events.advisor_alert.emit(&"custodians_awake")


## The player's engine an enemy is working on, or that is shut down, or null.
func _threatened_engine(faction: int) -> Building:
	for engine: Building in engines():
		if engine.faction != faction:
			continue
		if engine.machine.is_shut_down():
			return engine
		if engine.machine.claimant >= 0 and engine.machine.claimant != faction:
			return engine
	return null


func _alert(kind: StringName) -> void:
	if _now < _next_alert_tick:
		return
	_next_alert_tick = _now + ticks(_machinery.alert_seconds)
	Events.advisor_alert.emit(kind)


## Nobody may place the rule's locked buildings (the Reactor) on this planet.
func _lock_buildings() -> void:
	if _machinery.locked_buildings.is_empty():
		return
	var factions: Array[int] = [world.player_faction]
	for faction: int in world.perks:
		if not factions.has(faction):
			factions.append(faction)
	for faction: int in factions:
		var perks: FactionPerks = world.perks.get(faction, null)
		if perks == null:
			perks = FactionPerks.new()
			world.perks[faction] = perks
		for id: StringName in _machinery.locked_buildings:
			perks.lock(id)


func to_dict() -> Dictionary:
	var working: Dictionary = {}
	for id: int in _working:
		working[str(id)] = _working[id]
	return {
		"version": SAVE_VERSION,
		"tick": _now,
		"next_alert": _next_alert_tick,
		"working": working,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported MachinerySystem save version")
	_now = data.get("tick", _now)
	_next_alert_tick = data.get("next_alert", 0)
	_working.clear()
	var working: Dictionary = data.get("working", {})
	for key: Variant in working:
		var engine_id: int = working[key]
		_working[int(str(key))] = engine_id
