class_name EruptionSystem
extends PlanetRuleSystem
## Emberfall's eruptions (PLAN 2.5, ADR 0015), played from an EruptionRule.
##
## Every erupting vent (`ResourceNode.erupts()`) has its own cycle:
##
##   calm (pressure builds) -> warning (`Events.eruption_warning`) -> burst
##   (`Events.eruption`, damage, the Tap knocked out) -> quiet -> calm ...
##
## Pressure builds fast while a working Flux Tap draws on the vent and slowly on its
## own; each cycle the vent bursts at a threshold drawn from the rule's seed (the RNG
## state is saved). The Tap's owner may vent it early (`vent()`): a small controlled
## burst that hurts only the Tap a little and empties the pressure, then a cooldown.
## A surge (`schedule_surge()`, a mission's climax) makes every vent on the caldera
## erupt in turn. Everything here is public knowledge (the AI reads it through its
## AiPort); a geological forecast (`forecast()`) names the vent that will burst next.

const SAVE_VERSION: int = 1
const STATE_CALM: StringName = &"calm"
const STATE_WARNING: StringName = &"warning"
## A vent counts as dangerous for the AI from this pressure on.
const DANGER_PRESSURE: float = 0.8
## Vent refusals (`can_vent()`), "" when it may vent.
const OK: StringName = &""
const NOT_A_TAP: StringName = &"not_a_tap"
const TOO_LOW: StringName = &"pressure_low"
const COOLING: StringName = &"cooling_down"
const SURGING: StringName = &"surging"
## A player's thing at or below this health share after an eruption "nearly" died.
const NEARLY_LOST: float = 0.3

## The vent the indicator shows (the most pressing), or null.
var pressing: ResourceNode = null

var _eruption: EruptionRule = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _now: int = 0
## Vent entity id -> {pressure, threshold, state, burst_at, quiet_until, vent_ready_at}.
var _vents: Dictionary[int, Dictionary] = {}
## Tick the surge's first vent bursts; -1 = none scheduled.
var _surge_at: int = -1
var _surge_announced: bool = false
var _surge_started: bool = false
var _next_alert_tick: int = 0
## Per faction: the tick its forecast of the next eruption ends.
var _forecast_until: Dictionary[int, int] = {}


static func ticks(seconds: float) -> int:
	return roundi(seconds * SimClock.TICK_RATE)


func _setup() -> void:
	_eruption = rule as EruptionRule
	assert(_eruption != null, "EruptionSystem needs an EruptionRule")
	_rng.seed = rule.random_seed
	_now = world.context.sim_clock.get_tick() if world.context != null else 0
	for vent: ResourceNode in vents():
		_state_of(vent)


## The erupting vents in the world.
func vents() -> Array[ResourceNode]:
	var found: Array[ResourceNode] = []
	for node: ResourceNode in world.resource_nodes:
		if is_instance_valid(node) and node.erupts():
			found.append(node)
	return found


## The vent's pressure, 0..1 (0 for anything that does not erupt).
func pressure_of(vent: ResourceNode) -> float:
	if vent == null or not _vents.has(vent.entity_id):
		return 0.0
	var pressure: float = _vents[vent.entity_id]["pressure"]
	return pressure


## Seconds until the vent's announced eruption; INF when none is announced.
func seconds_to_burst(vent: ResourceNode) -> float:
	if vent == null or not _vents.has(vent.entity_id):
		return INF
	var state: Dictionary = _vents[vent.entity_id]
	if state["state"] != STATE_WARNING:
		return INF
	var burst_at: int = state["burst_at"]
	return maxf(float(burst_at - _now) / SimClock.TICK_RATE, 0.0)


## Seconds before the vent may be vented again (0 = ready).
func vent_cooldown_left(vent: ResourceNode) -> float:
	if vent == null or not _vents.has(vent.entity_id):
		return 0.0
	var ready_at: int = _vents[vent.entity_id]["vent_ready_at"]
	return maxf(float(ready_at - _now) / SimClock.TICK_RATE, 0.0)


## Why `tap` may not vent its vent now (OK = it may).
func can_vent(tap: Building) -> StringName:
	if tap == null or tap.is_dead or tap.vent == null or not tap.vent.erupts():
		return NOT_A_TAP
	if not tap.is_operational() or tap.flux_extractor == null:
		return NOT_A_TAP
	var state: Dictionary = _state_of(tap.vent)
	var burst_at: int = state["burst_at"]
	if _surge_started and state["state"] == STATE_WARNING and burst_at >= _now:
		return SURGING
	if vent_cooldown_left(tap.vent) > 0.0:
		return COOLING
	var pressure: float = state["pressure"]
	if pressure < _eruption.vent_min_pressure:
		return TOO_LOW
	return OK


## `tap` vents its vent on purpose: the pressure empties (an announced eruption is
## called off), the Tap takes light damage and stalls a few seconds, and the vent
## cools down. Returns false (nothing happens) when `can_vent()` refuses.
func vent(tap: Building) -> bool:
	if can_vent(tap) != OK:
		return false
	var vent_node: ResourceNode = tap.vent
	var state: Dictionary = _state_of(vent_node)
	var was_calm: bool = state.get("state", STATE_CALM) == STATE_CALM
	state["pressure"] = 0.0
	state["state"] = STATE_CALM
	if not was_calm:
		# An announced eruption is called off: negative seconds end its warning.
		Events.eruption_warning.emit(vent_node, -1.0, _eruption.radius)
	state["threshold"] = _draw_threshold()
	var cooldown: float = (
		_eruption.vent_cooldown_seconds * _perk(tap.faction, tap.def.id, FactionPerks.VENT_COOLDOWN)
	)
	state["vent_ready_at"] = _now + ticks(cooldown)
	tap.health.take(_eruption.vent_damage, null)
	tap.flux_extractor.stall(_eruption.vent_stall_seconds)
	_show(vent_node)
	return true


## Every vent on the caldera (the rule's `surge_area`) erupts in turn from `at_tick`,
## one every `surge_step_seconds`; announced `surge_warning_seconds` ahead (Advisor
## `surge_incoming`), each vent with its own `eruption_warning`. Venting is refused
## once a vent's surge warning runs.
func schedule_surge(at_tick: int) -> void:
	_surge_at = at_tick
	_surge_announced = false
	_surge_started = false


## The tick the surge starts, or -1.
func surge_tick() -> int:
	return _surge_at


## A planet climax is the surge (a mission naming a climax objective).
func schedule_climax(at_tick: int) -> void:
	schedule_surge(at_tick)


## Vents about to burst or close to it (public knowledge, for the AI): x, z, radius and
## seconds until the burst (an estimate from the current rate for a vent not yet
## announced; INF when it is not building).
func dangers() -> Array[Vector4]:
	var found: Array[Vector4] = []
	for vent: ResourceNode in vents():
		var state: Dictionary = _state_of(vent)
		var pressure: float = state["pressure"]
		var seconds: float = seconds_to_burst(vent)
		if seconds == INF and pressure < DANGER_PRESSURE:
			continue
		if seconds == INF:
			seconds = _estimate_seconds(vent, state)
		found.append(Vector4(vent.position.x, vent.position.z, _eruption.radius, seconds))
	return found


## The vent expected to burst first (from its hidden threshold and current rate),
## or null.
func next_to_erupt() -> ResourceNode:
	var best: ResourceNode = null
	var best_seconds: float = INF
	for vent: ResourceNode in vents():
		var seconds: float = seconds_to_burst(vent)
		if seconds == INF:
			seconds = _estimate_seconds(vent, _state_of(vent))
		if seconds < best_seconds:
			best = vent
			best_seconds = seconds
	return best


## `faction` learns which vent bursts next, for `seconds` (a geological discovery).
func forecast(faction: int, seconds: float) -> void:
	var until: int = _forecast_until.get(faction, 0)
	_forecast_until[faction] = maxi(until, _now + ticks(seconds))
	_update_forecast()


func indicator_title() -> String:
	return "VENTS"


func indicator_text(tick_number: int) -> String:
	if _surge_at >= 0 and _surge_announced and tick_number < _surge_at:
		return "SURGE IN " + _clock(float(_surge_at - tick_number) / SimClock.TICK_RATE)
	if pressing == null or not is_instance_valid(pressing):
		return "STABLE"
	var burst: float = seconds_to_burst(pressing)
	if burst < INF:
		return "ERUPTING IN " + _clock(burst)
	var pressure: float = pressure_of(pressing)
	if _has_forecast(world.player_faction):
		var next: ResourceNode = next_to_erupt()
		if next != null:
			var eta: float = _estimate_seconds(next, _state_of(next))
			if eta < INF:
				return "NEXT ~" + _clock(eta)
	if pressure < 0.5:
		return "STABLE"
	return "PRESSURE %d%%" % roundi(pressure * 100.0)


func indicator_level() -> float:
	if pressing == null or not is_instance_valid(pressing):
		return 0.0
	return 1.0 if seconds_to_burst(pressing) < INF else pressure_of(pressing)


func indicator_alarm() -> bool:
	if _surge_announced and _surge_at >= 0 and _now < _surge_at + ticks(30.0):
		return true
	return pressing != null and is_instance_valid(pressing) and seconds_to_burst(pressing) < INF


func _tick(tick_number: int, dt: float) -> void:
	_now = tick_number
	_tick_surge()
	for vent: ResourceNode in vents():
		var state: Dictionary = _state_of(vent)
		if state["state"] == STATE_WARNING:
			var burst_at: int = state["burst_at"]
			if _now >= burst_at:
				_erupt(vent, state)
		else:
			_build(vent, state, dt)
		_show(vent)
	_pick_pressing()
	if tick_number % 10 == 0:
		_update_forecast()


func _build(vent: ResourceNode, state: Dictionary, dt: float) -> void:
	var quiet_until: int = state["quiet_until"]
	if _now < quiet_until:
		return
	var pressure: float = state["pressure"]
	pressure = minf(pressure + _rate(vent) * dt, 1.0)
	state["pressure"] = pressure
	var threshold: float = state["threshold"]
	if pressure >= threshold:
		_warn(vent, state, ticks(_eruption.warning_seconds))


## Announces that `vent` bursts in `length` ticks.
func _warn(vent: ResourceNode, state: Dictionary, length: int) -> void:
	state["state"] = STATE_WARNING
	state["burst_at"] = _now + maxi(length, 1)
	var seconds: float = float(maxi(length, 1)) / SimClock.TICK_RATE
	Events.eruption_warning.emit(vent, seconds, _eruption.radius)
	if _concerns_player(vent) and _now >= _next_alert_tick:
		_next_alert_tick = _now + ticks(_eruption.alert_seconds)
		Events.advisor_alert.emit(&"eruption_warning")


## Pressure per second now: fast while a working Tap draws on it.
func _rate(vent: ResourceNode) -> float:
	var tap: Building = vent.tap if is_instance_valid(vent.tap) else null
	if tap != null and not tap.is_dead and tap.is_operational():
		if tap.flux_extractor != null and not tap.flux_extractor.is_stalled():
			return _eruption.tapped_rate
	return _eruption.idle_rate


func _erupt(vent: ResourceNode, state: Dictionary) -> void:
	state["state"] = STATE_CALM
	state["pressure"] = 0.0
	state["threshold"] = _draw_threshold()
	state["quiet_until"] = _now + ticks(_eruption.quiet_seconds)
	var radius: float = _eruption.radius
	Events.eruption.emit(vent, radius)
	var player_hurt: bool = false
	var at: Vector2 = Vector2(vent.position.x, vent.position.z)
	for building: Building in world.buildings.duplicate():
		if building.is_dead or not _reaches(building.footprint(), at, radius):
			continue
		var amount: float = (
			_eruption.building_damage
			* _perk(building.faction, building.def.id, FactionPerks.ERUPTION_DAMAGE)
		)
		building.health.take(amount, null)
		if building == vent.tap and building.flux_extractor != null and not building.is_dead:
			building.flux_extractor.stall(_eruption.knockout_seconds)
		player_hurt = player_hurt or _hurt_badly(building, building.faction, building.health)
	for unit: Unit in world.units.duplicate():
		if unit.is_dead or unit.health == null:
			continue
		var there: Vector3 = unit.sim_position()
		var reach: float = radius + (unit.def.radius if unit.def != null else 0.0)
		if Vector2(there.x, there.z).distance_to(at) > reach:
			continue
		unit.health.take(_eruption.unit_damage, null)
		player_hurt = player_hurt or _hurt_badly(unit, unit.faction, unit.health)
	if player_hurt:
		Events.advisor_alert.emit(&"eruption_damage")


## True when `entity` is the player's and died or is nearly gone.
func _hurt_badly(_entity: Node3D, faction: int, health: Health) -> bool:
	if faction != world.player_faction or health == null:
		return false
	return health.is_dead() or health.fraction() <= NEARLY_LOST


func _tick_surge() -> void:
	if _surge_at < 0:
		return
	var warning: int = ticks(_eruption.warning_seconds)
	if not _surge_announced and _now >= _surge_at - ticks(_eruption.surge_warning_seconds):
		_surge_announced = true
		Events.advisor_alert.emit(&"surge_incoming")
	if _surge_started or _now < _surge_at - warning:
		return
	_surge_started = true
	var step: int = ticks(_eruption.surge_step_seconds)
	var order: int = 0
	for vent: ResourceNode in _surge_vents():
		var state: Dictionary = _state_of(vent)
		var burst: int = _surge_at + order * step
		order += 1
		var current: int = state["burst_at"]
		if state["state"] == STATE_WARNING and current <= burst:
			continue
		state["quiet_until"] = 0
		_warn(vent, state, burst - _now)


## The vents a surge sets off, in a fixed order (round the caldera by angle).
func _surge_vents() -> Array[ResourceNode]:
	var found: Array[ResourceNode] = []
	var centre: Vector2 = _eruption.surge_area.get_center()
	for vent: ResourceNode in vents():
		if _eruption.surge_area.has_point(Vector2(vent.position.x, vent.position.z)):
			found.append(vent)
	found.sort_custom(
		func(a: ResourceNode, b: ResourceNode) -> bool:
			var angle_a: float = (Vector2(a.position.x, a.position.z) - centre).angle()
			var angle_b: float = (Vector2(b.position.x, b.position.z) - centre).angle()
			return angle_a < angle_b
	)
	return found


func _state_of(vent: ResourceNode) -> Dictionary:
	if not _vents.has(vent.entity_id):
		_vents[vent.entity_id] = {
			"pressure": _rng.randf_range(0.0, _eruption.start_pressure_max),
			"threshold": _draw_threshold(),
			"state": STATE_CALM,
			"burst_at": -1,
			"quiet_until": 0,
			"vent_ready_at": 0,
		}
	return _vents[vent.entity_id]


func _draw_threshold() -> float:
	return _rng.randf_range(minf(_eruption.threshold_min, 1.0), 1.0)


## Seconds until `vent` reaches its threshold at its current rate (INF if not building).
func _estimate_seconds(vent: ResourceNode, state: Dictionary) -> float:
	var rate: float = _rate(vent)
	if rate <= 0.0:
		return INF
	var pressure: float = state["pressure"]
	var threshold: float = state["threshold"]
	var quiet_until: int = state["quiet_until"]
	var quiet: float = maxf(float(quiet_until - _now) / SimClock.TICK_RATE, 0.0)
	return quiet + maxf(threshold - pressure, 0.0) / rate + _eruption.warning_seconds


## Hands the vent's pressure and countdown to the node (gauges, AI, UI).
func _show(vent: ResourceNode) -> void:
	var burst: float = seconds_to_burst(vent)
	vent.set_pressure(pressure_of(vent), burst if burst < INF else -1.0)


## The indicator's vent: the one bursting soonest, else the fullest the player knows of.
func _pick_pressing() -> void:
	pressing = null
	var soonest: float = INF
	var fullest: float = -1.0
	for vent: ResourceNode in vents():
		var burst: float = seconds_to_burst(vent)
		if burst < soonest:
			soonest = burst
			pressing = vent
		elif soonest == INF and _known_to_player(vent) and pressure_of(vent) > fullest:
			fullest = pressure_of(vent)
			pressing = vent


func _update_forecast() -> void:
	var next: ResourceNode = next_to_erupt() if _has_forecast(world.player_faction) else null
	for vent: ResourceNode in vents():
		vent.set_next_to_erupt(vent == next)


func _has_forecast(faction: int) -> bool:
	return _forecast_until.get(faction, -1) > _now


func _known_to_player(vent: ResourceNode) -> bool:
	if world.vision == null:
		return true
	return world.vision.grid.is_explored(world.player_faction, vent.position)


## The player hears about a vent they have seen or have something near.
func _concerns_player(vent: ResourceNode) -> bool:
	if _known_to_player(vent):
		return true
	var at: Vector2 = Vector2(vent.position.x, vent.position.z)
	for unit: Unit in world.units_of(world.player_faction):
		var there: Vector3 = unit.sim_position()
		if Vector2(there.x, there.z).distance_to(at) <= _eruption.alert_distance:
			return true
	for building: Building in world.buildings_of(world.player_faction):
		if _reaches(building.footprint(), at, _eruption.alert_distance):
			return true
	return false


func _perk(faction: int, id: StringName, stat: StringName) -> float:
	return FactionPerks.of(world.perks, faction).scale(id, stat)


## True when `rect` comes within `radius` of `at`.
static func _reaches(rect: Rect2, at: Vector2, radius: float) -> bool:
	var nearest: Vector2 = Vector2(
		clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y)
	)
	return nearest.distance_to(at) <= radius


static func _clock(seconds: float) -> String:
	var left: int = ceili(seconds)
	return "%d:%02d" % [floori(left / 60.0), left % 60]


func to_dict() -> Dictionary:
	var saved: Dictionary = {}
	for id: int in _vents:
		saved[str(id)] = _vents[id].duplicate()
	var forecasts: Dictionary = {}
	for faction: int in _forecast_until:
		forecasts[str(faction)] = _forecast_until[faction]
	return {
		"version": SAVE_VERSION,
		"tick": _now,
		"vents": saved,
		"surge_at": _surge_at,
		"surge_announced": _surge_announced,
		"surge_started": _surge_started,
		"next_alert": _next_alert_tick,
		"forecast": forecasts,
		"rng_state": str(_rng.state),
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported EruptionSystem save version")
	_now = data.get("tick", _now)
	_surge_at = data.get("surge_at", -1)
	_surge_announced = data.get("surge_announced", false)
	_surge_started = data.get("surge_started", false)
	_next_alert_tick = data.get("next_alert", 0)
	var rng_text: String = data.get("rng_state", "")
	if rng_text != "":
		_rng.state = int(rng_text)
	_vents.clear()
	var saved: Dictionary = data.get("vents", {})
	for key: Variant in saved:
		var entry: Dictionary = saved[key]
		var pressure: float = entry.get("pressure", 0.0)
		var threshold: float = entry.get("threshold", 1.0)
		var burst_at: int = entry.get("burst_at", -1)
		var quiet_until: int = entry.get("quiet_until", 0)
		var vent_ready_at: int = entry.get("vent_ready_at", 0)
		var state: Dictionary = {
			"pressure": pressure,
			"threshold": threshold,
			"state": StringName(str(entry.get("state", STATE_CALM))),
			"burst_at": burst_at,
			"quiet_until": quiet_until,
			"vent_ready_at": vent_ready_at,
		}
		_vents[int(str(key))] = state
	_forecast_until.clear()
	var forecasts: Dictionary = data.get("forecast", {})
	for key: Variant in forecasts:
		var until: int = forecasts[key]
		_forecast_until[int(str(key))] = until
	# A vent mid-warning is announced again, so its ring and sound come back.
	for vent: ResourceNode in vents():
		var seconds: float = seconds_to_burst(vent)
		if seconds < INF:
			Events.eruption_warning.emit(vent, seconds, _eruption.radius)
		_show(vent)
	_pick_pressing()
	_update_forecast()
