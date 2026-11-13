class_name Discovery
extends Node
## Exploration for one mission (PLAN 2.4, ADR 0009): the discovery sites, resolving
## them (Intel, codex entry, payoff, chain), the payoffs that last a while (heal
## fields), and the Survey Lab's field options. Created by SimWorld and ticked on the
## sim clock; registered on the MissionContext as `SERVICE_KEY`.
##
## Everything a discovery gives goes to the faction that resolved it and to no one
## else: Intel and unlocks to its stockpile, reveals to its own vision grid only.
## Deposits it uncovers are ordinary map nodes that other factions must find by sight.

const SERVICE_KEY: StringName = &"discovery"
const SAVE_VERSION: int = 1

var world: SimWorld = null
var player_faction: int = 0
var sites: Array[DiscoverySite] = []
var field_options: FieldOptions = null

## Per faction: resolved DiscoveryDefs in the order found (the codex).
var _codex: Dictionary[int, Array] = {}
## Running heal fields: { faction, x, z, radius, amount, until }.
var _heal_fields: Array[Dictionary] = []
var _tick: int = 0


## Sim ticks in `seconds`.
static func ticks(seconds: float) -> int:
	return roundi(seconds * SimClock.TICK_RATE)


func setup(p_world: SimWorld, p_player_faction: int) -> void:
	world = p_world
	player_faction = p_player_faction
	field_options = FieldOptions.new(world, player_faction)


func add_site(site: DiscoverySite) -> void:
	sites.append(site)
	site.tree_exiting.connect(func() -> void: sites.erase(site))


## The site of the discovery with id `id`, or null.
func site_of(id: StringName) -> DiscoverySite:
	for site: DiscoverySite in sites:
		if site.def != null and site.def.id == id:
			return site
	return null


## True if some site leads to a discovery with id `id` (it then starts uncharted).
static func is_led_to(defs: Array[DiscoveryDef], id: StringName) -> bool:
	for def: DiscoveryDef in defs:
		if def != null and def.leads_to == id:
			return true
	return false


## The faction's codex: DiscoveryDefs resolved so far, oldest first.
func codex(faction: int) -> Array[DiscoveryDef]:
	var entries: Array[DiscoveryDef] = []
	var stored: Array = _codex.get(faction, [])
	entries.assign(stored)
	return entries


## Running heal fields (for presentation): { faction, x, z, radius, amount, until }.
func heal_fields() -> Array[Dictionary]:
	return _heal_fields.duplicate()


## A scan began at `site`: dormant Custodians guarding it wake.
func on_scan_started(site: DiscoverySite) -> void:
	world.disturb(site.position)


## `faction` finished scanning `site`: it is resolved, the faction earns its Intel and
## codex entry, the payoff happens and the next site of a chain is charted.
func resolve(site: DiscoverySite, faction: int) -> void:
	if site == null or site.is_resolved or site.def == null:
		return
	var def: DiscoveryDef = site.def
	site.resolve(faction)
	world.economy.add_intel(faction, def.intel_reward)
	if not _codex.has(faction):
		_codex[faction] = []
	_codex[faction].append(def)
	Events.discovery_made.emit(site, def, faction)
	if faction == player_faction:
		Events.codex_entry_added.emit(def)
		Events.advisor_alert.emit(&"discovery")
	_apply_payoff(site, faction)
	if def.leads_to != &"":
		var next: DiscoverySite = site_of(def.leads_to)
		if next != null and not next.charted:
			next.chart()


## One sim tick: heal fields, field option cooldowns, the player's view of the sites.
func tick(tick_number: int, dt: float) -> void:
	_tick = tick_number
	field_options.tick(tick_number)
	_tick_heal_fields(dt)
	for site: DiscoverySite in sites:
		if world.vision == null:
			site.is_visible_to_player = site.charted
		else:
			site.is_visible_to_player = (
				site.charted
				and world.vision.grid.is_area_visible(player_faction, site.blocked_area())
			)


func _apply_payoff(site: DiscoverySite, faction: int) -> void:
	var def: DiscoveryDef = site.def
	match def.payoff:
		DiscoveryDef.PAYOFF_DEPOSIT:
			if def.payoff_node != null:
				world.spawn_resource_node(def.payoff_node, site.position + def.payoff_offset)
		DiscoveryDef.PAYOFF_HEAL_FIELD:
			(
				_heal_fields
				. append(
					{
						"faction": faction,
						"x": site.position.x,
						"z": site.position.z,
						"radius": def.payoff_radius,
						"amount": def.payoff_amount,
						"until": _tick + ticks(def.payoff_seconds),
					}
				)
			)
		DiscoveryDef.PAYOFF_UNLOCK_OPTION:
			field_options.unlock(faction, def.unlocks_option)
			if faction == player_faction:
				Events.advisor_alert.emit(&"field_option_ready")
		DiscoveryDef.PAYOFF_REVEAL_ENEMY:
			_reveal_enemies(faction, def)


## The faction sees around every enemy unit and building (not Custodians) for a while.
func _reveal_enemies(faction: int, def: DiscoveryDef) -> void:
	if world.vision == null:
		return
	var duration: int = ticks(def.payoff_seconds)
	for unit: Unit in world.units:
		if _is_enemy(faction, unit.faction) and Combat.is_alive(unit):
			world.vision.reveal_entity(faction, unit, def.payoff_radius, duration)
	for building: Building in world.buildings:
		if _is_enemy(faction, building.faction) and Combat.is_alive(building):
			var radius: float = def.payoff_radius + building.def.footprint_radius()
			world.vision.reveal_entity(faction, building, radius, duration)


func _tick_heal_fields(dt: float) -> void:
	if _heal_fields.is_empty():
		return
	var kept: Array[Dictionary] = []
	for field: Dictionary in _heal_fields:
		var until: int = field["until"]
		if until < _tick:
			continue
		kept.append(field)
		var faction: int = field["faction"]
		var x: float = field["x"]
		var z: float = field["z"]
		var centre: Vector2 = Vector2(x, z)
		var radius: float = field["radius"]
		var amount: float = field["amount"]
		for unit: Unit in world.units:
			if unit.faction != faction or unit.health == null or unit.is_dead:
				continue
			var at: Vector3 = unit.sim_position()
			if centre.distance_to(Vector2(at.x, at.z)) <= radius:
				unit.health.heal(amount * dt)
	_heal_fields = kept


static func _is_enemy(faction: int, other: int) -> bool:
	return other != faction and other >= 0 and not Factions.is_custodian(other)


func to_dict() -> Dictionary:
	var codex_ids: Dictionary = {}
	for faction: int in _codex:
		var paths: Array[String] = []
		for entry: Variant in _codex[faction]:
			var def: DiscoveryDef = entry
			paths.append(def.resource_path)
		codex_ids[str(faction)] = paths
	var fields: Array[Dictionary] = []
	for field: Dictionary in _heal_fields:
		var saved: Dictionary = field.duplicate()
		var until: int = field["until"]
		saved["until"] = until - _tick
		fields.append(saved)
	return {
		"version": SAVE_VERSION,
		"codex": codex_ids,
		"heal_fields": fields,
		"field_options": field_options.to_dict(),
	}


## Restores the codex, heal fields and field options (sites are restored by SimWorld).
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Discovery save version")
	_codex.clear()
	var codex_ids: Dictionary = data.get("codex", {})
	for key: Variant in codex_ids:
		var paths: Array = codex_ids[key]
		var entries: Array = []
		for entry: Variant in paths:
			var path: String = entry
			if ResourceLoader.exists(path):
				entries.append(load(path))
		_codex[int(str(key))] = entries
	_heal_fields.clear()
	var fields: Array = data.get("heal_fields", [])
	for entry: Variant in fields:
		var field: Dictionary = entry
		var left: int = field.get("until", 0)
		field["until"] = _tick + left
		_heal_fields.append(field)
	var options_data: Dictionary = data.get("field_options", {})
	if not options_data.is_empty():
		field_options.from_dict(options_data)
