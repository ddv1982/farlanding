class_name StealthSystem
extends RefCounted
## Stealth on the shared vision grid (PLAN 3.4, ADR 0010). Every unit has a
## `signature` (1 = plainly visible; a Wisp 0.5, cloaked 0.15) and watchers a
## `sensor`. A unit below signature 1 is *concealed*: its enemies' grids may cover
## it, yet they do not see it (no targeting, no AI perception, hidden from the
## player's view) until one of their watchers has spotted it.
##
## Spotting is not instant. Each sim tick every watcher looks for intruders inside
## its sight cone (`sight_angle`) within `sight range × signature × sensor`, on cells
## its faction's grid sees, with terrain line of sight. Its `suspicion` (0..1) rises
## while it has one, faster when closer and for a higher signature, holds for a
## moment and then decays. Crossing NOTICE_AT emits `suspicion_raised`; reaching 1
## emits `intruder_spotted` and reveals the intruder to that faction for
## SPOTTED_TICKS (renewed while it stays spotted).
##
## Factions in `guard_factions` (a mission chooses them) also keep an alert meter:
## Unaware -> Suspicious (a watcher passed SUSPICIOUS_AT, or something was sabotaged)
## -> Alerted (an intruder spotted, or the faction was attacked), stepping back down
## one level after a quiet period. Their watchers also grow suspicious of
## full-signature intruders (a sentry notices a Surveyor walking past). Changes emit
## `alert_level_changed`. `alert_level()` and `alert_position()` are the faction's
## own knowledge, which its AI may use.

const SAVE_VERSION: int = 1
const LEVEL_UNAWARE: StringName = &"unaware"
const LEVEL_SUSPICIOUS: StringName = &"suspicious"
const LEVEL_ALERTED: StringName = &"alerted"
const LEVELS: Array[StringName] = [LEVEL_UNAWARE, LEVEL_SUSPICIOUS, LEVEL_ALERTED]
## Suspicion at which a watcher has noticed something (`suspicion_raised`).
const NOTICE_AT: float = 0.15
## Suspicion at which a guard faction becomes suspicious.
const SUSPICIOUS_AT: float = 0.4
## Suspicion per second for a signature-1 intruder at the edge of reach, and point blank.
const RISE_AT_EDGE: float = 0.4
const RISE_CLOSE: float = 2.4
## Suspicion lost per second once the watcher has seen nothing for HOLD_TICKS.
const DECAY_PER_SECOND: float = 0.12
const HOLD_TICKS: int = 15
## Within this distance an intruder is noticed all round, cone or not.
const CLOSE_RANGE: float = 2.5
## A spotted intruder stays visible to the faction this long after it was last sure.
const SPOTTED_TICKS: int = 50
## A unit that hits a faction is revealed to it this long.
const ATTACK_REVEAL_TICKS: int = 30
## Quiet time before an alert steps down: Alerted -> Suspicious, Suspicious -> Unaware.
const ALERTED_QUIET_TICKS: int = 600
const SUSPICIOUS_QUIET_TICKS: int = 250
## Line of sight: eye and target heights above the ground, and the sampling step.
const EYE_HEIGHT: float = 1.6
const TARGET_HEIGHT: float = 0.8
const LOS_STEP: float = 2.0

## Factions with an alert meter, whose watchers notice any intruder.
var guard_factions: Array[int] = []
## The shared vision grid (not the VisionSystem: that one holds this system).
var grid: VisionGrid = null
var combat: Combat = null
var heights: HeightField = null
## Wall-clock cost of the last tick, in microseconds.
var last_tick_usec: int = 0

var _tick: int = 0
var _levels: Dictionary[int, StringName] = {}
## Per guard faction: sim tick of the last thing noticed (the quiet period starts there).
var _last_noticed_tick: Dictionary[int, int] = {}
var _alert_positions: Dictionary[int, Vector3] = {}
## Per faction: revealed unit -> sim tick the reveal ends.
var _revealed: Dictionary[int, Dictionary] = {}


func _init(
	p_grid: VisionGrid = null, p_combat: Combat = null, p_heights: HeightField = null
) -> void:
	grid = p_grid
	combat = p_combat
	heights = p_heights


## Gives `faction` an alert meter (Unaware at first).
func add_guard_faction(faction: int) -> void:
	if faction >= 0 and not guard_factions.has(faction):
		guard_factions.append(faction)
		_levels[faction] = LEVEL_UNAWARE
		_last_noticed_tick[faction] = _tick


## The alert level of `faction`: &"unaware", &"suspicious" or &"alerted" (always
## &"unaware" for a faction without an alert meter).
func alert_level(faction: int) -> StringName:
	return _levels.get(faction, LEVEL_UNAWARE)


## Where `faction` last noticed an intruder (or was attacked from); Vector3.INF if never.
func alert_position(faction: int) -> Vector3:
	return _alert_positions.get(faction, Vector3.INF)


## True if `faction` cannot see `unit` although its grid may cover it: the unit is
## below signature 1 and no watcher of `faction` has spotted it lately.
func is_concealed(faction: int, unit: Unit) -> bool:
	if unit == null or unit.faction == faction or unit.signature >= 1.0:
		return false
	var revealed: Dictionary = _revealed.get(faction, {})
	var until: int = revealed.get(unit, -1)
	return until < _tick


## `faction` sees `unit` for `ticks` sim ticks whatever its signature.
func reveal(faction: int, unit: Unit, ticks: int) -> void:
	if unit == null or faction < 0:
		return
	if not _revealed.has(faction):
		_revealed[faction] = {}
	var revealed: Dictionary = _revealed[faction]
	var until: int = revealed.get(unit, -1)
	revealed[unit] = maxi(until, _tick + ticks)


## `attacker` hit something of `faction`: it is revealed to that faction for a moment,
## a cloak opens, and a guard faction is alerted.
func notice_attack(faction: int, attacker: Node3D) -> void:
	var attacker_faction: int = Combat.faction_of(attacker)
	if attacker_faction < 0 or attacker_faction == faction or faction < 0:
		return
	var unit: Unit = attacker as Unit
	if unit != null:
		reveal(faction, unit, ATTACK_REVEAL_TICKS)
		if unit.cloak != null:
			unit.cloak.break_cloak()
	if guard_factions.has(faction) and not Factions.is_custodian(attacker_faction):
		_raise(faction, LEVEL_ALERTED, AttackCommand.position_of(attacker))


## Something of `building`'s faction was sabotaged: a guard faction grows suspicious there.
func notice_sabotage(building: Building) -> void:
	if building != null and guard_factions.has(building.faction):
		_raise(building.faction, LEVEL_SUSPICIOUS, building.position)


## One sim tick: every watcher looks, then the alert meters update.
func tick(tick_number: int, dt: float, units: Array[Unit]) -> void:
	var started: int = Time.get_ticks_usec()
	_tick = tick_number
	var stealthy_factions: Dictionary[int, bool] = {}
	for unit: Unit in units:
		if not unit.is_dead and unit.signature < 1.0:
			stealthy_factions[unit.faction] = true
	for unit: Unit in units:
		var watcher: Watcher = unit.watcher
		if watcher == null or unit.is_dead or unit.is_dormant:
			continue
		if Factions.is_custodian(unit.faction):
			continue
		var guard: bool = guard_factions.has(unit.faction)
		watcher.faction_alerted = alert_level(unit.faction) == LEVEL_ALERTED
		var anyone: bool = guard
		if not anyone:
			for faction: int in stealthy_factions:
				anyone = anyone or faction != unit.faction
		var found: Unit = _look(unit, guard) if anyone else null
		if not anyone:
			watcher.focus = null
		_update_watcher(unit, found, dt)
	for faction: int in guard_factions:
		_step_down(faction)
	if tick_number % 50 == 0:
		_forget_freed()
	last_tick_usec = Time.get_ticks_usec() - started


## How fast `watcher` grows suspicious of `target` now, per second (0 = it cannot
## notice it: outside its cone or reach, unseen by its grid, or behind terrain).
## `guard` lets it notice full-signature targets too.
func suspicion_rate(watcher: Unit, target: Unit, guard: bool) -> float:
	if not _may_notice(watcher, target, guard):
		return 0.0
	var signature: float = minf(target.signature, 1.0)
	var origin: Vector3 = watcher.sim_position()
	var there: Vector3 = target.sim_position()
	var distance: float = Vector2(there.x - origin.x, there.z - origin.z).length()
	var sensor: float = watcher.def.sensor
	var reach: float = maxf(watcher.sight_range * clampf(signature * sensor, 0.0, 1.0), CLOSE_RANGE)
	if distance > reach:
		return 0.0
	if distance > CLOSE_RANGE and not in_cone(watcher, there):
		return 0.0
	if grid != null and not grid.is_visible(watcher.faction, there):
		return 0.0
	if not has_line_of_sight(origin, there):
		return 0.0
	var near: float = 1.0 - clampf(distance / reach, 0.0, 1.0)
	return sensor * signature * lerpf(RISE_AT_EDGE, RISE_CLOSE, near)


## True if `point` lies inside `watcher`'s sight cone (direction only).
static func in_cone(watcher: Unit, point: Vector3) -> bool:
	var angle: float = watcher.sight_angle
	if angle >= 360.0:
		return true
	var origin: Vector3 = watcher.sim_position()
	var offset: Vector3 = Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	if offset.length_squared() < 0.0001:
		return true
	var yaw: float = (
		watcher.locomotion.mover.yaw if watcher.locomotion != null else watcher.rotation.y
	)
	var forward: Vector3 = Mover.forward_for(yaw)
	return forward.angle_to(offset) <= deg_to_rad(angle) * 0.5


## True unless terrain rises between an eye at `from` and a target at `to`.
func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	if heights == null:
		return true
	var start: Vector3 = Vector3(from.x, heights.sample(from.x, from.z) + EYE_HEIGHT, from.z)
	var end: Vector3 = Vector3(to.x, heights.sample(to.x, to.z) + TARGET_HEIGHT, to.z)
	var steps: int = ceili(Vector2(end.x - start.x, end.z - start.z).length() / LOS_STEP)
	for i: int in range(1, steps):
		var point: Vector3 = start.lerp(end, float(i) / steps)
		if heights.sample(point.x, point.z) > point.y:
			return false
	return true


func to_dict() -> Dictionary:
	var levels: Dictionary = {}
	for faction: int in _levels:
		levels[str(faction)] = String(_levels[faction])
	var noticed: Dictionary = {}
	for faction: int in _last_noticed_tick:
		noticed[str(faction)] = _last_noticed_tick[faction]
	var positions: Dictionary = {}
	for faction: int in _alert_positions:
		positions[str(faction)] = var_to_str(_alert_positions[faction])
	return {
		"version": SAVE_VERSION,
		"tick": _tick,
		"guard_factions": guard_factions.duplicate(),
		"levels": levels,
		"noticed": noticed,
		"positions": positions,
	}


## Restores the alert meters (reveals end with a load).
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported StealthSystem save version")
	_tick = data.get("tick", 0)
	var saved_guards: Array = data.get("guard_factions", [])
	for entry: Variant in saved_guards:
		var faction: int = entry
		add_guard_faction(faction)
	var levels: Dictionary = data.get("levels", {})
	for key: Variant in levels:
		var level: String = levels[key]
		_levels[int(str(key))] = StringName(level)
	var noticed: Dictionary = data.get("noticed", {})
	for key: Variant in noticed:
		var at: int = noticed[key]
		_last_noticed_tick[int(str(key))] = at
	var positions: Dictionary = data.get("positions", {})
	for key: Variant in positions:
		var text: String = positions[key]
		_alert_positions[int(str(key))] = str_to_var(text)


## True if `target` is someone `watcher` could grow suspicious of at all.
static func _may_notice(watcher: Unit, target: Unit, guard: bool) -> bool:
	if target == null or target.is_dead or target.faction == watcher.faction:
		return false
	if Factions.is_custodian(target.faction) or target.is_dormant:
		return false
	return guard or target.signature < 1.0


## The intruder `watcher` grows most suspicious of now, or null.
func _look(watcher: Unit, guard: bool) -> Unit:
	if combat == null:
		return null
	var best: Unit = null
	var best_rate: float = 0.0
	for entity: Node3D in combat.entities_near(watcher.sim_position(), watcher.sight_range):
		var target: Unit = entity as Unit
		if target == null:
			continue
		var rate: float = suspicion_rate(watcher, target, guard)
		if rate > best_rate:
			best = target
			best_rate = rate
	watcher.watcher.focus = best
	watcher.watcher.rate = best_rate
	return best


func _update_watcher(unit: Unit, found: Unit, dt: float) -> void:
	var watcher: Watcher = unit.watcher
	var faction: int = unit.faction
	if found != null:
		watcher.suspicion = minf(watcher.suspicion + watcher.rate * dt, 1.0)
		watcher.last_noticed = found.sim_position()
		watcher.has_noticed = true
		watcher.last_seen_tick = _tick
		if not watcher.noticed_announced and watcher.suspicion >= NOTICE_AT:
			watcher.noticed_announced = true
			Events.suspicion_raised.emit(unit, found)
		if guard_factions.has(faction) and watcher.suspicion >= NOTICE_AT:
			_last_noticed_tick[faction] = _tick
			if watcher.suspicion >= SUSPICIOUS_AT:
				_raise(faction, LEVEL_SUSPICIOUS, watcher.last_noticed)
		if watcher.suspicion >= 1.0:
			reveal(faction, found, SPOTTED_TICKS)
			if not watcher.spotted:
				watcher.spotted = true
				Events.intruder_spotted.emit(unit, found)
			if guard_factions.has(faction):
				_raise(faction, LEVEL_ALERTED, watcher.last_noticed)
		return
	watcher.rate = 0.0
	if _tick - watcher.last_seen_tick <= HOLD_TICKS:
		return
	watcher.suspicion = maxf(watcher.suspicion - DECAY_PER_SECOND * dt, 0.0)
	if watcher.suspicion <= 0.0:
		watcher.calm()


## Raises `faction`'s alert to at least `level`, noting where.
func _raise(faction: int, level: StringName, at: Vector3) -> void:
	if not guard_factions.has(faction):
		return
	_last_noticed_tick[faction] = _tick
	_alert_positions[faction] = at
	var current: StringName = alert_level(faction)
	if LEVELS.find(level) > LEVELS.find(current):
		_set_level(faction, level)


## After a quiet period the alert steps down one level.
func _step_down(faction: int) -> void:
	var current: StringName = alert_level(faction)
	if current == LEVEL_UNAWARE:
		return
	var quiet: int = _tick - _last_noticed_tick.get(faction, _tick)
	if current == LEVEL_ALERTED and quiet >= ALERTED_QUIET_TICKS:
		_last_noticed_tick[faction] = _tick
		_set_level(faction, LEVEL_SUSPICIOUS)
	elif current == LEVEL_SUSPICIOUS and quiet >= SUSPICIOUS_QUIET_TICKS:
		_set_level(faction, LEVEL_UNAWARE)


func _set_level(faction: int, level: StringName) -> void:
	var previous: StringName = alert_level(faction)
	if previous == level:
		return
	_levels[faction] = level
	Events.alert_level_changed.emit(faction, level, previous)


func _forget_freed() -> void:
	for faction: int in _revealed:
		var revealed: Dictionary = _revealed[faction]
		for key: Variant in revealed.keys():
			var until: int = revealed[key]
			if not is_instance_valid(key) or until < _tick:
				revealed.erase(key)
