class_name VisionSystem
extends RefCounted
## Runs the VisionGrid for a mission (PLAN 3.4). Staggered: each sim tick updates
## one faction's grid from all its units' and buildings' `vision_range`, round robin,
## so with two factions each sees anew five times a second. After the player's
## update it applies the player's view to the world: enemy units are shown only on
## visible cells, enemy buildings once they have been seen (then they stay, as last
## seen), resource nodes once explored. Every entity gets `is_visible_to_player`.
## A unit or building that hits another faction is exposed to that faction for
## EXPOSE_TICKS (a small disc around it on their grid), so attackers firing from
## beyond the defenders' sight can still be seen and answered. Timed reveals (an
## orbital scan, a discovery that shows the enemy) add discs to one faction's grid
## only, for a number of ticks: at a fixed point, or following an entity.

## `faction`'s grid was just recomputed (presentation re-uploads the fog).
signal updated(faction: int)

const SAVE_VERSION: int = 2
## How long a shooter stays exposed to the faction it hit (2 s).
const EXPOSE_TICKS: int = 20
## Radius of the disc an exposed shooter shows, in metres.
const EXPOSE_RADIUS: float = 3.0

var grid: VisionGrid
var player_faction: int = 0
## Wall-clock cost of the last faction update (grid plus applying the view), in µs.
var last_update_usec: int = 0

var _factions: Array[int] = []
## Per faction: exposed entity -> sim tick its exposure ends.
var _exposed: Dictionary[int, Dictionary] = {}
var _tick: int = 0
## Per faction: timed area reveals, Vector4(x, z, radius, until tick).
var _area_reveals: Dictionary[int, Array] = {}
## Per faction: followed entity -> Vector2(radius, until tick).
var _entity_reveals: Dictionary[int, Dictionary] = {}


func _init(area: Rect2, cell_size: float = 2.0, p_player_faction: int = 0) -> void:
	grid = VisionGrid.new(area, cell_size)
	player_faction = p_player_faction
	add_faction(player_faction)


## Lets `faction` see (called for every spawned unit or building's faction).
func add_faction(faction: int) -> void:
	if faction >= 0 and not _factions.has(faction):
		_factions.append(faction)
		_factions.sort()


func factions() -> Array[int]:
	return _factions.duplicate()


## The faction whose grid is updated on sim tick `tick`.
func faction_for_tick(tick: int) -> int:
	return _factions[posmod(tick, _factions.size())]


## One sim tick: updates one faction (round robin) and, for the player, the view.
func tick(
	tick_number: int,
	units: Array[Unit],
	buildings: Array[Building],
	nodes: Array[ResourceNode] = [],
) -> int:
	_tick = tick_number
	var faction: int = faction_for_tick(tick_number)
	update_faction(faction, units, buildings, nodes)
	return faction


## Recomputes `faction`'s grid now from its living units and buildings.
func update_faction(
	faction: int,
	units: Array[Unit],
	buildings: Array[Building],
	nodes: Array[ResourceNode] = [],
) -> void:
	var started: int = Time.get_ticks_usec()
	grid.begin_update(faction)
	for unit: Unit in units:
		if unit.faction == faction and not unit.is_dead and unit.def != null:
			grid.reveal(faction, unit.sim_position(), unit.def.vision_range)
	for building: Building in buildings:
		if building.faction == faction and not building.is_dead and building.def != null:
			grid.reveal(faction, building.position, building.def.vision_range)
	_reveal_exposed(faction)
	_reveal_timed(faction)
	grid.end_update(faction)
	if faction == player_faction:
		apply_player_view(units, buildings, nodes)
	last_update_usec = Time.get_ticks_usec() - started
	updated.emit(faction)


## `shooter` hit something of `faction`: that faction sees it for EXPOSE_TICKS.
func expose(shooter: Node3D, faction: int) -> void:
	if shooter == null or faction < 0:
		return
	if not _exposed.has(faction):
		_exposed[faction] = {}
	_exposed[faction][shooter] = _tick + EXPOSE_TICKS


## `faction` sees a disc of `radius` around `at` for `ticks` sim ticks.
func reveal_area(faction: int, at: Vector3, radius: float, ticks: int) -> void:
	if faction < 0 or radius <= 0.0 or ticks <= 0:
		return
	add_faction(faction)
	if not _area_reveals.has(faction):
		_area_reveals[faction] = []
	_area_reveals[faction].append(Vector4(at.x, at.z, radius, _tick + ticks))


## `faction` sees a disc of `radius` around `entity`, wherever it goes, for `ticks`.
func reveal_entity(faction: int, entity: Node3D, radius: float, ticks: int) -> void:
	if faction < 0 or entity == null or radius <= 0.0 or ticks <= 0:
		return
	add_faction(faction)
	if not _entity_reveals.has(faction):
		_entity_reveals[faction] = {}
	_entity_reveals[faction][entity] = Vector2(radius, _tick + ticks)


## Timed reveals still running for `faction` (areas plus followed entities).
func reveal_count(faction: int) -> int:
	var areas: Array = _area_reveals.get(faction, [])
	var entities: Dictionary = _entity_reveals.get(faction, {})
	return areas.size() + entities.size()


## True if `faction` sees `entity` now (buildings: any part of the footprint).
func can_see(faction: int, entity: Node3D) -> bool:
	var building: Building = entity as Building
	if building != null:
		return grid.is_area_visible(faction, building.footprint())
	return grid.is_visible(faction, AttackCommand.position_of(entity))


## Shows or hides every non-player entity by what the player knows.
func apply_player_view(
	units: Array[Unit], buildings: Array[Building], nodes: Array[ResourceNode]
) -> void:
	for unit: Unit in units:
		refresh_unit(unit)
	for building: Building in buildings:
		refresh_building(building)
	for node: ResourceNode in nodes:
		refresh_node(node)


func refresh_unit(unit: Unit) -> void:
	var seen: bool = (
		unit.faction == player_faction or grid.is_visible(player_faction, unit.sim_position())
	)
	unit.is_visible_to_player = seen
	unit.visible = seen


func refresh_building(building: Building) -> void:
	if building.faction == player_faction:
		building.is_visible_to_player = true
		building.seen_by_player = true
		building.visible = true
		return
	var seen: bool = grid.is_area_visible(player_faction, building.footprint())
	building.is_visible_to_player = seen
	if seen:
		building.seen_by_player = true
	building.visible = building.seen_by_player


func refresh_node(node: ResourceNode) -> void:
	var rect: Rect2 = node.blocked_area()
	node.is_visible_to_player = grid.is_area_visible(player_faction, rect)
	if not node.visible and grid.is_area_explored(player_faction, rect):
		node.visible = true


func _reveal_exposed(faction: int) -> void:
	if not _exposed.has(faction):
		return
	var exposed: Dictionary = _exposed[faction]
	for key: Variant in exposed.keys():
		var until: int = exposed[key]
		if not Combat.is_alive(key) or until < _tick:
			exposed.erase(key)
			continue
		var shooter: Node3D = key
		grid.reveal(faction, AttackCommand.position_of(shooter), EXPOSE_RADIUS)


func _reveal_timed(faction: int) -> void:
	if _area_reveals.has(faction):
		var kept: Array = []
		for entry: Variant in _area_reveals[faction]:
			var reveal: Vector4 = entry
			if reveal.w < _tick:
				continue
			kept.append(reveal)
			grid.reveal(faction, Vector3(reveal.x, 0.0, reveal.y), reveal.z)
		_area_reveals[faction] = kept
	if _entity_reveals.has(faction):
		var followed: Dictionary = _entity_reveals[faction]
		for key: Variant in followed.keys():
			var reveal: Vector2 = followed[key]
			if not Combat.is_alive(key) or reveal.y < _tick:
				followed.erase(key)
				continue
			var entity: Node3D = key
			grid.reveal(faction, AttackCommand.position_of(entity), reveal.x)


## Saves the factions, what each explored and the timed area reveals (reveals that
## follow an entity end with a load).
func to_dict() -> Dictionary:
	var areas: Dictionary = {}
	for faction: int in _area_reveals:
		var saved: Array[String] = []
		for entry: Variant in _area_reveals[faction]:
			var reveal: Vector4 = entry
			saved.append(var_to_str(reveal))
		areas[str(faction)] = saved
	return {
		"version": SAVE_VERSION,
		"factions": _factions.duplicate(),
		"grid": grid.to_dict(),
		"tick": _tick,
		"area_reveals": areas,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported VisionSystem save version")
	_tick = data.get("tick", _tick)
	var areas: Dictionary = data.get("area_reveals", {})
	for key: Variant in areas:
		var faction: int = int(str(key))
		var saved: Array = areas[key]
		var restored: Array = []
		for entry: Variant in saved:
			var text: String = entry
			var reveal: Vector4 = str_to_var(text)
			restored.append(reveal)
		_area_reveals[faction] = restored
	var saved: Array = data.get("factions", [])
	for entry: Variant in saved:
		var faction: int = entry
		add_faction(faction)
	var grid_data: Dictionary = data.get("grid", {})
	if not grid_data.is_empty():
		grid.from_dict(grid_data)
