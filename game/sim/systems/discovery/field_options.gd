class_name FieldOptions
extends RefCounted
## Survey Lab field options for one mission (PLAN 1): which options each faction has
## unlocked, their cooldowns, and their effects. Paid in Intel when used. Owned by
## the Discovery system; options are used through FieldOptionCommand.

## Why an option cannot be used now.
const OK: StringName = &""
const LOCKED: StringName = &"locked"
const COOLDOWN: StringName = &"cooldown"
const NO_INTEL: StringName = &"no_intel"
const NO_LAB: StringName = &"no_lab"
const BAD_TARGET: StringName = &"bad_target"
const SAVE_VERSION: int = 2

var world: SimWorld = null
var player_faction: int = 0

## Per faction: option id -> true once unlocked by a discovery.
var _unlocked: Dictionary[int, Dictionary] = {}
## Per faction: option id -> sim tick it is ready again.
var _ready_at: Dictionary[int, Dictionary] = {}
## Per faction: option id -> FieldOptionDef, for options on cooldown (ready alerts).
var _waiting: Dictionary[int, Dictionary] = {}
## Per faction: option id -> uses left that cost no Intel and start no cooldown
## (a charge brought along in the landing's loadout).
var _charges: Dictionary[int, Dictionary] = {}
var _tick: int = 0
## Set by from_dict: deadlines were rebuilt on `_tick`, which a fresh system has
## not yet synchronised with the restored clock; the next tick rebases them.
var _restored: bool = false


func _init(p_world: SimWorld = null, p_player_faction: int = 0) -> void:
	world = p_world
	player_faction = p_player_faction


func unlock(faction: int, option_id: StringName) -> void:
	if option_id == &"":
		return
	if not _unlocked.has(faction):
		_unlocked[faction] = {}
	_unlocked[faction][option_id] = true


## Gives `faction` `count` free uses of the option `option_id`.
func add_charges(faction: int, option_id: StringName, count: int) -> void:
	if option_id == &"" or count <= 0:
		return
	if not _charges.has(faction):
		_charges[faction] = {}
	var held: int = _charges[faction].get(option_id, 0)
	_charges[faction][option_id] = held + count


## Free uses of `option` `faction` has left.
func charges(faction: int, option: FieldOptionDef) -> int:
	var held: Dictionary = _charges.get(faction, {})
	return held.get(option.id, 0)


## Intel `faction` pays for `option` (its perks may make it cheaper).
func cost(faction: int, option: FieldOptionDef) -> int:
	if world == null:
		return option.intel_cost
	return roundi(
		FactionPerks.of(world.perks, faction).apply(
			option.id, FactionPerks.INTEL_COST, option.intel_cost
		)
	)


## Cooldown of `option` for `faction`, in seconds (after its perks).
func cooldown(faction: int, option: FieldOptionDef) -> float:
	if world == null:
		return option.cooldown
	return FactionPerks.of(world.perks, faction).apply(
		option.id, FactionPerks.COOLDOWN, option.cooldown
	)


func is_unlocked(faction: int, option: FieldOptionDef) -> bool:
	if world != null and FactionPerks.of(world.perks, faction).is_locked(option.id):
		return false
	if not option.requires_unlock:
		return true
	var unlocked: Dictionary = _unlocked.get(faction, {})
	return unlocked.has(option.id)


## Seconds until `option` may be used again by `faction` (0 = ready).
func cooldown_left(faction: int, option: FieldOptionDef) -> float:
	var ready: Dictionary = _ready_at.get(faction, {})
	var at: int = ready.get(option.id, 0)
	return maxf(at - _tick, 0) * SimClock.TICK_DELTA


## Why `faction` cannot use `option` now (OK if it can), ignoring the target point.
func check(faction: int, option: FieldOptionDef) -> StringName:
	if option == null or not is_unlocked(faction, option):
		return LOCKED
	if charges(faction, option) > 0:
		return OK
	if cooldown_left(faction, option) > 0.0:
		return COOLDOWN
	if world != null and world.economy.stockpile(faction).intel < cost(faction, option):
		return NO_INTEL
	return OK


## Uses `option` for `faction` at `at`: pays its Intel, starts its cooldown, applies
## the effect and announces it. Returns why it was refused, or OK.
func use(faction: int, option: FieldOptionDef, at: Vector3) -> StringName:
	var refused: StringName = check(faction, option)
	if refused != OK:
		return refused
	if option.effect == FieldOptionDef.EFFECT_SUPPLY_DROP and not _drop_spot_ok(option, at):
		return BAD_TARGET
	if charges(faction, option) > 0:
		_charges[faction][option.id] = charges(faction, option) - 1
		_apply(faction, option, at)
		Events.field_option_used.emit(option, faction, at)
		return OK
	if not world.economy.spend_intel(faction, cost(faction, option)):
		return NO_INTEL
	if not _ready_at.has(faction):
		_ready_at[faction] = {}
		_waiting[faction] = {}
	_ready_at[faction][option.id] = _tick + Discovery.ticks(cooldown(faction, option))
	_waiting[faction][option.id] = option
	_apply(faction, option, at)
	Events.field_option_used.emit(option, faction, at)
	return OK


## One sim tick: tells the player when an option comes off cooldown.
func tick(tick_number: int) -> void:
	if _restored:
		_restored = false
		var shift: int = tick_number - 1 - _tick
		for faction: int in _ready_at:
			for id: Variant in _ready_at[faction]:
				_ready_at[faction][id] += shift
	_tick = tick_number
	for faction: int in _waiting:
		var waiting: Dictionary = _waiting[faction]
		for id: Variant in waiting.keys():
			var option: FieldOptionDef = waiting[id]
			if cooldown_left(faction, option) > 0.0:
				continue
			waiting.erase(id)
			if faction == player_faction:
				Events.advisor_alert.emit(&"field_option_ready")


func _apply(faction: int, option: FieldOptionDef, at: Vector3) -> void:
	match option.effect:
		FieldOptionDef.EFFECT_REVEAL:
			if world.vision != null:
				world.vision.reveal_area(
					faction, at, option.radius, Discovery.ticks(option.seconds)
				)
		FieldOptionDef.EFFECT_SUPPLY_DROP:
			world.economy.add(faction, option.alloy, option.flux)
			if option.node != null:
				world.spawn_resource_node(option.node, at)
		FieldOptionDef.EFFECT_STRIKE:
			_strike(faction, option, at)


## Damages every unit and building not of `faction` within the radius (Custodians
## too: they wake).
func _strike(faction: int, option: FieldOptionDef, at: Vector3) -> void:
	if world.combat == null:
		return
	var targets: Array[Node3D] = []
	targets.append_array(world.units)
	targets.append_array(world.buildings)
	for entity: Node3D in targets:
		var owner: int = Combat.faction_of(entity)
		if owner < 0 or owner == faction or not Combat.is_alive(entity):
			continue
		if Combat.reach_to(entity, at) > option.radius:
			continue
		world.combat.damage(entity, option.damage, option.damage_type, null)


## A supply cache needs open, walkable ground clear of buildings, nodes and sites.
func _drop_spot_ok(option: FieldOptionDef, at: Vector3) -> bool:
	if option.node == null:
		return true
	if not world.paths.is_terrain_walkable(at):
		return false
	var reach: float = option.node.radius + 1.0
	var area: Rect2 = Rect2(at.x - reach, at.z - reach, reach * 2.0, reach * 2.0)
	for building: Building in world.buildings:
		if building.footprint().intersects(area):
			return false
	for node: ResourceNode in world.resource_nodes:
		if node.blocked_area().intersects(area):
			return false
	if world.discovery != null:
		for site: DiscoverySite in world.discovery.sites:
			if is_instance_valid(site) and site.def != null:
				if site.blocked_area().intersects(area):
					return false
	return true


func to_dict() -> Dictionary:
	var unlocked: Dictionary = {}
	for faction: int in _unlocked:
		unlocked[str(faction)] = _unlocked[faction].keys()
	var cooldowns: Dictionary = {}
	for faction: int in _ready_at:
		var left: Dictionary = {}
		for id: Variant in _ready_at[faction]:
			var at: int = _ready_at[faction][id]
			left[str(id)] = maxi(at - _tick, 0)
		cooldowns[str(faction)] = left
	var charge_data: Dictionary = {}
	for faction: int in _charges:
		charge_data[str(faction)] = _charges[faction].duplicate()
	return {
		"version": SAVE_VERSION,
		"unlocked": unlocked,
		"cooldowns": cooldowns,
		"charges": charge_data,
	}


## Restores unlocks and cooldowns (cooldowns end without a ready alert).
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported FieldOptions save version")
	_restored = true
	_unlocked.clear()
	_ready_at.clear()
	_waiting.clear()
	_charges.clear()
	var charge_data: Dictionary = data.get("charges", {})
	for key: Variant in charge_data:
		var held: Dictionary = charge_data[key]
		for id: Variant in held:
			var count: int = held[id]
			add_charges(int(str(key)), StringName(str(id)), count)
	var unlocked: Dictionary = data.get("unlocked", {})
	for key: Variant in unlocked:
		var ids: Array = unlocked[key]
		for id: Variant in ids:
			unlock(int(str(key)), StringName(str(id)))
	var cooldowns: Dictionary = data.get("cooldowns", {})
	for key: Variant in cooldowns:
		var faction: int = int(str(key))
		var left: Dictionary = cooldowns[key]
		_ready_at[faction] = {}
		_waiting[faction] = {}
		for id: Variant in left:
			var ticks: int = left[id]
			_ready_at[faction][StringName(str(id))] = _tick + ticks
