class_name CoreScript
extends MissionScript
## The finale on Hollow Meridian (ADR 0017): wake the Beacon Core. Data in the mission's
## CoreRules (`script_rules`).
##
## Each side (the player and the Combine) has its own charge of the Core, 0..1. A side
## charges while it runs at least `engines_needed` Antecedent engines and one of its
## units that can scan (a Surveyor, a Rigger) stands within `link_radius` of the Core;
## faster with every engine beyond that. With both sides linked at once the dais is
## contested and nobody charges. The Core shows the leading charge
## (`Events.core_charge_changed`), and as it passes each of `stage_charges` the next
## stage of Custodians wakes (every dormant one within that stage's radius of the Core)
## and converges on the dais as a last-stand group. When the player's charge is full
## the Core wakes (`Events.core_awakened`, the player's `core_charge` objective is
## done); when the Combine's is full first, its objective fails the mission.
##
## The Combine plays the race through the same command queue: from
## `enemy_link_after_seconds`, once it runs enough engines, it sends a Rigger to the dais
## with an escort, and while the player is linked it sends a strike at the dais.

## The Core's charge is announced at most this often while it moves, in sim ticks.
const SHOW_TICKS: int = 3
## A linker is sent to stand this far from the Core's centre (on the dais).
const LINK_STAND: float = 10.0

var rules: CoreRules = null
## Faction -> its charge of the Core, 0..1.
var charges: Dictionary[int, float] = {}
## Custodian stages woken so far.
var stages_woken: int = 0
var awakened: bool = false
## The Custodians converging on the dais, and the Combine's strike at it.
var custodian_groups: Array[AttackGroup] = []
var strike: AttackGroup = null
## The Combine unit sent to link, by save id (-1 = none).
var enemy_linker: int = -1
var enemy_warned: bool = false

var _enemy_port: WorldAiPort = null
var _custodian_port: WorldAiPort = null
var _profile: CommanderProfile = CommanderProfile.new()
var _core: Prop = null
var _shown: float = -1.0
var _shown_tick: int = -1000


func setup(p_mission: Mission) -> void:
	super(p_mission)
	rules = mission.def.script_rules as CoreRules
	_enemy_port = WorldAiPort.new(mission.context, mission.world, mission.def.hostile_faction)
	_custodian_port = WorldAiPort.new(mission.context, mission.world, Factions.CUSTODIANS)


## The Beacon Core prop on the map, or null.
func core() -> Prop:
	if _core != null and is_instance_valid(_core):
		return _core
	_core = null
	if rules == null:
		return null
	for prop: Prop in mission.world.props:
		if prop.def != null and prop.def.id == rules.core_id:
			_core = prop
			break
	return _core


## `faction`'s charge of the Core, 0..1.
func charge_of(faction: int) -> float:
	return charges.get(faction, 0.0)


## The charge the Core shows: the leading side's.
func leading_charge() -> float:
	var best: float = 0.0
	for faction: int in charges:
		best = maxf(best, charges[faction])
	return best


## True while a unit of `faction` that can scan stands linked at the Core.
func is_linked(faction: int) -> bool:
	return _linker_of(faction) != null


## Engines `faction` runs now.
func engines_of(faction: int) -> int:
	var machinery: MachinerySystem = mission.world.planet as MachinerySystem
	return machinery.held_by(faction).size() if machinery != null else 0


## What holds `faction`'s charge back, in one line (the objective's progress).
func status_line(faction: int) -> String:
	if rules == null:
		return ""
	var percent: int = floori(charge_of(faction) * 100.0)
	var engines: int = engines_of(faction)
	var player: bool = faction == mission.player_faction
	var who: String = "Charge" if player else "Combine charge"
	var state: String = "charging"
	if engines < rules.engines_needed:
		state = "%d of %d engines" % [engines, rules.engines_needed]
	elif not is_linked(faction):
		state = "no Surveyor on the dais" if player else "not linked"
	elif _contested():
		state = "dais contested"
	return "%s %d%%  ·  %s" % [who, percent, state]


func on_started() -> void:
	core()


func on_tick(tick: int) -> void:
	if rules == null or mission.result != null or core() == null:
		return
	var dt: float = SimClock.TICK_DELTA
	var contested: bool = _contested()
	# The first side to fill the Core has it: nothing charges or drains after that.
	var sides: Array[int] = [mission.player_faction, mission.def.hostile_faction]
	if charge_of(sides[0]) >= 1.0 or charge_of(sides[1]) >= 1.0:
		sides = []
	for faction: int in sides:
		var charge: float = charge_of(faction)
		if is_linked(faction):
			if not contested and engines_of(faction) >= rules.engines_needed:
				charge += _rate(faction) * dt
		elif rules.drain_per_second > 0.0:
			charge -= rules.drain_per_second * dt
		charges[faction] = clampf(charge, 0.0, 1.0)
	_show(tick)
	_wake_stages()
	if tick % _profile.behaviour_interval_ticks == 0:
		_command_enemy(tick)
		_tick_groups(tick)
	var enemy_has_it: bool = charge_of(mission.def.hostile_faction) >= 1.0
	if not awakened and not enemy_has_it and charge_of(mission.player_faction) >= 1.0:
		awakened = true
		Events.core_awakened.emit(_core)


func stop() -> void:
	# The groups hold callables back to this script: let go of them.
	custodian_groups.clear()
	strike = null


func on_resumed() -> void:
	core()
	_shown = -1.0
	_show(mission.now())


func to_dict() -> Dictionary:
	var saved_charges: Dictionary = {}
	for faction: int in charges:
		saved_charges[str(faction)] = charges[faction]
	var groups: Array[Dictionary] = []
	for group: AttackGroup in custodian_groups:
		if not group.finished:
			groups.append(group.to_dict())
	return {
		"version": 1,
		"charges": saved_charges,
		"stages": stages_woken,
		"awakened": awakened,
		"linker": enemy_linker,
		"enemy_warned": enemy_warned,
		"custodians": groups,
		"strike": strike.to_dict() if strike != null and not strike.finished else {},
	}


func from_dict(data: Dictionary) -> void:
	charges.clear()
	var saved_charges: Dictionary = data.get("charges", {})
	for key: Variant in saved_charges:
		var charge: float = saved_charges[key]
		charges[int(str(key))] = charge
	stages_woken = data.get("stages", 0)
	awakened = data.get("awakened", false)
	enemy_linker = data.get("linker", -1)
	_reserve_linker()
	enemy_warned = data.get("enemy_warned", false)
	custodian_groups.clear()
	var groups: Array = data.get("custodians", [])
	for entry: Variant in groups:
		var group_data: Dictionary = entry
		var group: AttackGroup = _restore_group(group_data, _custodian_port)
		if group != null:
			custodian_groups.append(group)
	var strike_data: Dictionary = data.get("strike", {})
	strike = _restore_group(strike_data, _enemy_port) if not strike_data.is_empty() else null


func _rate(faction: int) -> float:
	var extra: int = maxi(engines_of(faction) - rules.engines_needed, 0)
	return (1.0 + rules.extra_engine_rate * extra) / rules.charge_seconds


func _contested() -> bool:
	return is_linked(mission.player_faction) and is_linked(mission.def.hostile_faction)


## A living unit of `faction` that can scan, standing within the link radius, or null.
func _linker_of(faction: int) -> Unit:
	if core() == null:
		return null
	for unit: Unit in mission.world.units_of(faction):
		if unit.is_dead or unit.scanner == null or unit.flies:
			continue
		if AiGroup.flat_distance(unit.sim_position(), _core.position) <= rules.link_radius:
			return unit
	return null


## Announces the leading charge as it moves (and at once on reaching 0 or 1).
func _show(tick: int) -> void:
	var leading: float = leading_charge()
	if is_equal_approx(leading, _shown):
		return
	var ends: bool = leading <= 0.0 or leading >= 1.0
	if not ends and tick - _shown_tick < SHOW_TICKS:
		return
	if _shown <= 0.0 and leading > 0.0 and charge_of(mission.player_faction) > 0.0:
		Events.advisor_alert.emit(&"core_charging")
	_shown = leading
	_shown_tick = tick
	Events.core_charge_changed.emit(leading)


## As the leading charge passes each stage, that stage's Custodians wake and converge.
func _wake_stages() -> void:
	var leading: float = leading_charge()
	while stages_woken < mini(rules.stage_charges.size(), rules.stage_radii.size()):
		if leading < rules.stage_charges[stages_woken]:
			return
		var radius: float = rules.stage_radii[stages_woken]
		stages_woken += 1
		var stage: Array[Unit] = []
		for unit: Unit in mission.world.units_of(Factions.CUSTODIANS):
			if unit.is_dead or unit.orders == null:
				continue
			if AiGroup.flat_distance(unit.sim_position(), _core.position) > radius:
				continue
			if unit.is_dormant:
				unit.dormancy.wake()
			if not _in_group(unit):
				stage.append(unit)
		if stage.is_empty():
			continue
		var group: AttackGroup = _make_group(stage, _custodian_port)
		group.start()
		custodian_groups.append(group)
		Events.advisor_alert.emit(&"custodians_awake")


## The Combine's side of the race: a linker with an escort once it runs enough engines,
## and a strike at the dais while the player charges.
func _command_enemy(_tick: int) -> void:
	var enemy: int = mission.def.hostile_faction
	if mission.elapsed_seconds() < rules.enemy_link_after_seconds:
		return
	if engines_of(enemy) >= rules.engines_needed:
		_send_linker(enemy)
	if is_linked(enemy) and not enemy_warned:
		enemy_warned = true
		Events.advisor_alert.emit(&"core_contested")
	var player: int = mission.player_faction
	if is_linked(player) and charge_of(player) > 0.0 and (strike == null or strike.finished):
		var squad: Array[Unit] = _idle_army(enemy, rules.enemy_strike)
		if squad.size() >= 2:
			strike = _make_group(squad, _enemy_port)
			strike.start()


## The commander leaves the linker alone: it may be a builder it would send elsewhere.
func _reserve_linker() -> void:
	if mission.commander != null:
		mission.commander.hands_off.clear()
		if enemy_linker >= 0:
			mission.commander.hands_off[enemy_linker] = true


func _send_linker(enemy: int) -> void:
	var linker: Unit = mission.world.entity(enemy_linker) as Unit
	var spot: Vector3 = _link_spot(enemy)
	if linker == null or linker.is_dead:
		linker = null
		for unit: Unit in mission.world.units_of(enemy):
			if unit.is_dead or unit.scanner == null or unit.orders == null:
				continue
			if linker == null or unit.orders.is_idle():
				linker = unit
			if unit.orders.is_idle():
				break
		if linker == null:
			return
		enemy_linker = linker.entity_id
		_reserve_linker()
		var escort: Array[Unit] = _idle_army(enemy, rules.enemy_escort)
		if not escort.is_empty():
			_enemy_port.push(
				MoveCommand.new(MoveCommand.KIND_MOVE, enemy, AiGroup._as_nodes(escort), spot)
			)
	var far: bool = AiGroup.flat_distance(linker.sim_position(), _core.position) > LINK_STAND + 2.0
	if far and linker.orders != null and not linker.locomotion.is_travelling():
		_enemy_port.push(
			MoveCommand.new(MoveCommand.KIND_MOVE, enemy, [linker] as Array[Node3D], spot)
		)


## A place on the dais facing `faction`'s base.
func _link_spot(faction: int) -> Vector3:
	var towards: Vector3 = mission.def.hostile_start - _core.position
	if faction == mission.player_faction:
		towards = mission.def.player_start - _core.position
	towards.y = 0.0
	var direction: Vector3 = towards.normalized() if towards.length() > 0.1 else Vector3.BACK
	return mission.world.paths.closest_point(_core.position + direction * LINK_STAND)


## Up to `count` idle armed units of `faction` that no group or patrol has.
func _idle_army(faction: int, count: int) -> Array[Unit]:
	var found: Array[Unit] = []
	var patrols: Array[Unit] = []
	if mission.guards != null:
		patrols = mission.guards.guards()
	for unit: Unit in mission.world.units_of(faction):
		if found.size() >= count:
			break
		if unit.is_dead or unit.weapon == null or unit.orders == null or unit.flies:
			continue
		if not unit.orders.is_idle() or patrols.has(unit) or _in_group(unit):
			continue
		if unit.entity_id == enemy_linker:
			continue
		found.append(unit)
	return found


func _in_group(unit: Unit) -> bool:
	for group: AttackGroup in custodian_groups:
		if group.has_member(unit):
			return true
	return strike != null and strike.has_member(unit)


## A last-stand group going for the Core and holding the dais.
func _make_group(units: Array[Unit], port: WorldAiPort) -> AttackGroup:
	var target: Vector3 = _core.position if _core != null else Vector3.ZERO
	var group: AttackGroup = AttackGroup.new(
		port, _profile, units, AttackGroup.MODE_LAST_STAND, target, target, target
	)
	group.next_target = func(_from: Vector3) -> Vector3: return target
	return group


func _restore_group(data: Dictionary, port: WorldAiPort) -> AttackGroup:
	var ids: Array = data.get("members", [])
	var units: Array[Unit] = AiGroup.units_from_ids(ids, mission.world.entity)
	if units.is_empty():
		return null
	core()
	var group: AttackGroup = _make_group(units, port)
	group.from_dict(data)
	return group


func _tick_groups(tick: int) -> void:
	for group: AttackGroup in custodian_groups.duplicate():
		group.tick(tick)
		if group.finished:
			custodian_groups.erase(group)
	if strike != null:
		strike.tick(tick)
		if strike.finished:
			strike = null
