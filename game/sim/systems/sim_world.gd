class_name SimWorld
extends Node3D
## Owns the entities of one mission — units, buildings, resource nodes and discovery
## sites — the faction economies, combat, discovery and (once enabled) vision. Spawns
## entities, ticks them on the sim clock (power, combat grid, one faction's vision,
## units, buildings, projectiles, discovery), moves unit and projectile nodes between
## ticks, and removes entities whose health runs out. Registered on the
## MissionContext as `SERVICE_KEY`; the Economy as `Economy.SERVICE_KEY`, Combat as
## `Combat.SERVICE_KEY`, Discovery as `Discovery.SERVICE_KEY`.

const SERVICE_KEY: StringName = &"world"
const SAVE_VERSION: int = 3
## Produced units without a rally point walk this far out of the door.
const DOOR_CLEARANCE: float = 4.0

var context: MissionContext = null
var paths: PathService = PathService.new()
var heights: HeightField = null
var units: Array[Unit] = []
var buildings: Array[Building] = []
var resource_nodes: Array[ResourceNode] = []
## Discovery sites, Intel payoffs and field options (created by setup()).
var discovery: Discovery = null
var economy: Economy = null
## Shots, projectiles and damage (created by setup()).
var combat: Combat = null
## Fog of war, or null when the mission has none (everything is seen).
var vision: VisionSystem = null
var rules: EconomyRules = EconomyRules.new()
var player_faction: int = 0
## Area buildings may be placed in (world X/Z).
var build_bounds: Rect2 = Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6)
## Wall-clock cost of the last sim tick for all units, in microseconds.
var last_tick_usec: int = 0

var _next_id: int = 1
var _entities: Dictionary[int, Node3D] = {}
var _blocks: Dictionary[int, int] = {}  # entity id -> PathService block handle


## Wires the world into a mission. Call before spawning.
func setup(
	p_context: MissionContext,
	p_paths: PathService,
	p_heights: HeightField,
	p_rules: EconomyRules = null,
	p_player_faction: int = 0,
	p_damage_table: DamageTable = null,
) -> void:
	context = p_context
	paths = p_paths
	heights = p_heights
	if p_rules != null:
		rules = p_rules
	player_faction = p_player_faction
	economy = Economy.new(rules, player_faction)
	context.set_service(SERVICE_KEY, self)
	context.set_service(Economy.SERVICE_KEY, economy)
	combat = Combat.new()
	combat.name = &"Combat"
	combat.setup(self, p_damage_table, player_faction)
	add_child(combat)
	context.set_service(Combat.SERVICE_KEY, combat)
	discovery = Discovery.new()
	discovery.name = &"Discovery"
	discovery.setup(self, player_faction)
	add_child(discovery)
	context.set_service(Discovery.SERVICE_KEY, discovery)
	context.sim_clock.ticked.connect(_on_ticked)


## Turns on fog of war over `area` (world X/Z) with `cell_size` metre cells. Call
## before spawning. Every faction then sees only what its units and buildings see.
func enable_vision(area: Rect2, cell_size: float = 2.0) -> VisionSystem:
	vision = VisionSystem.new(area, cell_size, player_faction)
	return vision


## Creates a unit of type `def` for `faction` standing at `at` facing `yaw`. A def
## without a scene gets a bare unit composed from its data (tests).
func spawn_unit(def: UnitDef, faction: int, at: Vector3, yaw: float = 0.0) -> Unit:
	var unit: Unit = _instantiate_unit(def)
	unit.def = def
	unit.faction = faction
	unit.world = self
	unit.entity_id = _register(unit)
	unit.name = "%s_%d" % [def.id, unit.entity_id]
	add_child(unit)
	if unit.locomotion != null:
		unit.locomotion.setup(def, at, yaw, paths, heights)
	units.append(unit)
	unit.tree_exiting.connect(_on_unit_exiting.bind(unit))
	if unit.health != null:
		unit.health.died.connect(_on_entity_killed.bind(unit))
	if vision != null:
		vision.add_faction(faction)
		vision.refresh_unit(unit)
	Events.entity_spawned.emit(unit)
	return unit


## Creates a building of `def` for `faction` at `at`: a construction site, or a
## finished building when `complete`. Blocks its footprint for movement, pushes units
## out of it, and claims the vent it stands on.
func spawn_building(def: BuildingDef, faction: int, at: Vector3, complete: bool) -> Building:
	var building: Building = (
		def.scene.instantiate() as Building if def.scene != null else Building.new()
	)
	assert(building != null, "Scene of %s is not a Building" % def.id)
	building.def = def
	building.faction = faction
	building.world = self
	building.entity_id = _register(building)
	building.name = "%s_%d" % [def.id, building.entity_id]
	building.position = _on_ground(at)
	building.setup(complete)
	var vent: ResourceNode = placement_rules().vent_at(def, at)
	if vent != null:
		vent.tap = building
		building.vent = vent
	add_child(building)
	buildings.append(building)
	building.tree_exiting.connect(_on_building_exiting.bind(building))
	_blocks[building.entity_id] = paths.block_area(building.footprint())
	evacuate(building.footprint())
	building.health.died.connect(_on_entity_killed.bind(building))
	if vision != null:
		vision.add_faction(faction)
		building.seen_by_player = faction == player_faction
		vision.refresh_building(building)
	Events.entity_spawned.emit(building)
	return building


## Places a resource node of `def` at `at`. Deposits block movement.
func spawn_resource_node(def: ResourceNodeDef, at: Vector3) -> ResourceNode:
	var node: ResourceNode = (
		def.scene.instantiate() as ResourceNode if def.scene != null else ResourceNode.new()
	)
	assert(node != null, "Scene of %s is not a ResourceNode" % def.id)
	node.setup(def)
	node.entity_id = _register(node)
	node.name = "%s_%d" % [def.id, node.entity_id]
	node.position = _on_ground(at)
	add_child(node)
	resource_nodes.append(node)
	node.tree_exiting.connect(_on_node_exiting.bind(node))
	if def.blocks_movement:
		_blocks[node.entity_id] = paths.block_area(node.blocked_area())
		# A node that appears mid-mission (a supply drop, an uncovered deposit).
		evacuate(node.blocked_area())
	if vision != null:
		node.visible = false
		vision.refresh_node(node)
	return node


## Places a discovery site of `def` at `at`. An uncharted site (a later step of a
## chain) stays hidden and cannot be scanned until it is charted.
func spawn_site(def: DiscoveryDef, at: Vector3, charted: bool = true) -> DiscoverySite:
	var site: DiscoverySite = (
		def.scene.instantiate() as DiscoverySite if def.scene != null else DiscoverySite.new()
	)
	assert(site != null, "Scene of %s is not a DiscoverySite" % def.id)
	site.setup(def, charted)
	site.entity_id = _register(site)
	site.name = "%s_%d" % [def.id, site.entity_id]
	site.position = _on_ground(at)
	add_child(site)
	discovery.add_site(site)
	site.tree_exiting.connect(_on_site_exiting.bind(site))
	if def.blocks_movement:
		_blocks[site.entity_id] = paths.block_area(site.blocked_area())
	return site


## Something stirred at `at` (a scan began): dormant Custodians whose guard radius
## reaches it wake up.
func disturb(at: Vector3) -> void:
	for unit: Unit in units:
		if not unit.is_dormant:
			continue
		var there: Vector3 = unit.sim_position()
		if Vector2(there.x - at.x, there.z - at.z).length() <= unit.def.guard_radius:
			unit.dormancy.wake()


## The entity with save id `id`, or null.
func entity(id: int) -> Node3D:
	var found: Node3D = _entities.get(id, null)
	return found if is_instance_valid(found) else null


## Units of `faction`.
func units_of(faction: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in units:
		if unit.faction == faction:
			result.append(unit)
	return result


func buildings_of(faction: int) -> Array[Building]:
	var result: Array[Building] = []
	for building: Building in buildings:
		if building.faction == faction:
			result.append(building)
	return result


## Placement rules over the current buildings, nodes and terrain.
func placement_rules() -> PlacementRules:
	var placement: PlacementRules = PlacementRules.new()
	placement.rules = rules
	placement.bounds = build_bounds
	for building: Building in buildings:
		placement.footprints.append(building.footprint())
	placement.nodes = resource_nodes.duplicate()
	for site: DiscoverySite in discovery.sites:
		if site.def.blocks_movement:
			placement.footprints.append(site.blocked_area())
	placement.is_walkable = paths.is_terrain_walkable
	if heights != null:
		placement.height_at = heights.sample
	return placement


## The nearest Alloy deposit with something left within `max_distance` of `from`,
## other than `exclude`.
func nearest_deposit(
	from: Vector3, max_distance: float = INF, exclude: ResourceNode = null
) -> ResourceNode:
	var best: ResourceNode = null
	var best_distance: float = max_distance
	for node: ResourceNode in resource_nodes:
		if not node.is_minable() or node == exclude:
			continue
		var distance: float = _flat_distance(node.position, from)
		if distance <= best_distance:
			best = node
			best_distance = distance
	return best


## Where haulers of `faction` unload: the nearest operational drop-off among those
## of the highest priority, or null.
func nearest_dropoff(faction: int, from: Vector3) -> Building:
	var best: Building = null
	var best_distance: float = INF
	for building: Building in buildings:
		if not building.accepts_alloy_from(faction):
			continue
		var distance: float = _flat_distance(building.dock_position(), from)
		if (
			best == null
			or building.def.dropoff_priority > best.def.dropoff_priority
			or (
				building.def.dropoff_priority == best.def.dropoff_priority
				and distance < best_distance
			)
		):
			best = building
			best_distance = distance
	return best


## A hauler unloaded `amount` Alloy.
func deliver(hauler: Unit, amount: int) -> void:
	if amount <= 0:
		return
	economy.add(hauler.faction, amount, 0)
	Events.harvest_delivered.emit(hauler, amount)


## `node` ran out (mined by `faction`): announce it and take it off the map.
func deplete(node: ResourceNode, faction: int) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	Events.resource_depleted.emit(node)
	if faction == player_faction:
		Events.advisor_alert.emit(&"deposit_depleted")
	node.queue_free()


## Sends a harvester to work the deposit nearest `near` on its own (new Haulers).
## Returns true if it found one.
func auto_harvest(unit: Unit, near: Vector3) -> bool:
	if unit.harvester == null or unit.orders == null:
		return false
	var deposit: ResourceNode = nearest_deposit(near, rules.deposit_search_radius * 2.0)
	if deposit == null:
		return false
	var order: Order = Order.new(Harvester.KIND, deposit.position)
	order.target_entity = deposit
	unit.orders.give(order)
	return true


func _process(_delta: float) -> void:
	if context == null:
		return
	var fraction: float = context.sim_clock.get_interpolation_fraction()
	for unit: Unit in units:
		if unit.locomotion != null:
			unit.locomotion.interpolate(fraction)
	combat.interpolate(fraction)


func _on_ticked(tick: int) -> void:
	var started: int = Time.get_ticks_usec()
	var dt: float = context.sim_clock.get_tick_delta()
	economy.update_power(buildings)
	combat.begin_tick(units, buildings)
	if vision != null:
		vision.tick(tick, units, buildings, resource_nodes)
	for unit: Unit in units:
		unit.sim_tick(dt)
	for building: Building in buildings.duplicate():
		_tick_building(building, dt)
	combat.tick_projectiles(dt)
	discovery.tick(tick, dt)
	last_tick_usec = Time.get_ticks_usec() - started


func _tick_building(building: Building, dt: float) -> void:
	if building.is_dead:
		return
	var rate: float = economy.work_rate(building.faction)
	building.tick_weapon(dt)
	if building.sim_tick():
		_on_construction_completed(building)
		return
	if not building.is_operational():
		return
	if building.producer != null:
		var finished: UnitDef = building.producer.tick(dt * rate)
		if finished != null:
			_on_unit_produced(building, finished)
	if building.flux_extractor != null:
		var flux: int = building.flux_extractor.tick(dt * rate)
		if flux > 0:
			economy.add(building.faction, 0, flux)


func _on_construction_completed(building: Building) -> void:
	Events.construction_completed.emit(building)
	if building.faction == player_faction:
		Events.advisor_alert.emit(&"construction_complete")
	economy.update_power(buildings)
	for def: UnitDef in building.def.free_units:
		_release_unit(building, def)


func _on_unit_produced(building: Building, def: UnitDef) -> void:
	var unit: Unit = _release_unit(building, def)
	Events.production_completed.emit(building, unit)
	if building.faction == player_faction:
		Events.advisor_alert.emit(&"unit_ready")
	var next: UnitDef = building.producer.current()
	if next != null:
		Events.production_started.emit(building, next)


## Spawns a unit of `def` at the building's door and sends it on: Haulers go
## harvesting near the rally point (or the building), others walk to the rally point
## or out of the door.
func _release_unit(building: Building, def: UnitDef) -> Unit:
	var door: Vector3 = building.door_position()
	var outward: Vector3 = Vector3(door.x - building.position.x, 0.0, door.z - building.position.z)
	var yaw: float = Mover.yaw_for(outward) if outward.length_squared() > 0.01 else 0.0
	var unit: Unit = spawn_unit(def, building.faction, door, yaw)
	var producer: Producer = building.producer
	var has_rally: bool = producer != null and producer.has_rally_point
	var rally: Vector3 = producer.rally_point if has_rally else door
	if unit.harvester != null and auto_harvest(unit, rally):
		return unit
	var goal: Vector3 = rally if has_rally else door + outward.normalized() * DOOR_CLEARANCE
	if unit.orders != null:
		unit.orders.give(Order.new(MoveCommand.KIND_MOVE, goal))
	return unit


## Units standing inside `area` (a new building or node) walk out of it first, then carry
## on with whatever they were doing. Builders too: they build from the edge.
func evacuate(area: Rect2) -> void:
	var grown: Rect2 = area.grow(1.0)
	for unit: Unit in units:
		var at: Vector3 = unit.sim_position()
		if not grown.has_point(Vector2(at.x, at.z)) or unit.orders == null:
			continue
		var exit: Vector3 = _nearest_outside(grown.grow(NavmeshPathService.CUT_MARGIN), at)
		unit.orders.interrupt(Order.new(MoveCommand.KIND_MOVE, exit))


static func _nearest_outside(area: Rect2, at: Vector3) -> Vector3:
	var to_left: float = at.x - area.position.x
	var to_right: float = area.end.x - at.x
	var to_top: float = at.z - area.position.y
	var to_bottom: float = area.end.y - at.z
	var nearest: float = minf(minf(to_left, to_right), minf(to_top, to_bottom))
	if nearest == to_left:
		return Vector3(area.position.x - 0.5, at.y, at.z)
	if nearest == to_right:
		return Vector3(area.end.x + 0.5, at.y, at.z)
	if nearest == to_top:
		return Vector3(at.x, at.y, area.position.y - 0.5)
	return Vector3(at.x, at.y, area.end.y + 0.5)


func _instantiate_unit(def: UnitDef) -> Unit:
	if def.scene != null:
		var scene_unit: Unit = def.scene.instantiate() as Unit
		assert(scene_unit != null, "Scene of %s is not a Unit" % def.id)
		return scene_unit
	var unit: Unit = Unit.new()
	var locomotion: Locomotion = Locomotion.new()
	locomotion.name = &"Locomotion"
	unit.add_child(locomotion)
	var orders: UnitOrders = UnitOrders.new()
	orders.name = &"Orders"
	unit.add_child(orders)
	if def.can_harvest():
		var harvester: Harvester = Harvester.new()
		harvester.name = &"Harvester"
		unit.add_child(harvester)
	if def.can_build():
		var builder: Builder = Builder.new()
		builder.name = &"Builder"
		unit.add_child(builder)
	return unit


func _register(node: Node3D) -> int:
	var id: int = _next_id
	_next_id += 1
	_entities[id] = node
	return id


func _on_ground(point: Vector3) -> Vector3:
	if heights != null:
		point.y = heights.sample(point.x, point.z)
	return point


## Health ran out: announce the death, take the entity out of play at once (its
## navmesh cut-out is freed now) and free it after the frame.
func _on_entity_killed(_attacker: Node3D, entity: Node3D) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return
	var unit: Unit = entity as Unit
	if unit != null and unit.orders != null:
		unit.orders.stop()
	var building: Building = entity as Building
	if building != null:
		_unblock(building.entity_id)
		if building.vent != null and is_instance_valid(building.vent):
			building.vent.tap = null
	Events.entity_died.emit(entity)
	if building != null:
		economy.update_power(buildings)
	entity.queue_free()


func _on_unit_exiting(unit: Unit) -> void:
	units.erase(unit)
	_entities.erase(unit.entity_id)


func _on_building_exiting(building: Building) -> void:
	buildings.erase(building)
	_entities.erase(building.entity_id)
	_unblock(building.entity_id)
	if building.vent != null and is_instance_valid(building.vent):
		building.vent.tap = null


func _on_site_exiting(site: DiscoverySite) -> void:
	_entities.erase(site.entity_id)
	_unblock(site.entity_id)


func _on_node_exiting(node: ResourceNode) -> void:
	resource_nodes.erase(node)
	_entities.erase(node.entity_id)
	_unblock(node.entity_id)


func _unblock(id: int) -> void:
	if _blocks.has(id):
		paths.unblock_area(_blocks[id])
		_blocks.erase(id)


func to_dict() -> Dictionary:
	var saved_buildings: Array[Dictionary] = []
	for building: Building in buildings:
		saved_buildings.append(building.to_dict())
	var saved_nodes: Array[Dictionary] = []
	for node: ResourceNode in resource_nodes:
		saved_nodes.append(node.to_dict())
	var saved_units: Array[Dictionary] = []
	for unit: Unit in units:
		saved_units.append(unit.to_dict())
	var saved_sites: Array[Dictionary] = []
	for site: DiscoverySite in discovery.sites:
		saved_sites.append(site.to_dict())
	return {
		"version": SAVE_VERSION,
		"next_id": _next_id,
		"economy": economy.to_dict(),
		"buildings": saved_buildings,
		"resource_nodes": saved_nodes,
		"units": saved_units,
		"sites": saved_sites,
		"discovery": discovery.to_dict(),
		"combat": combat.to_dict(),
		"vision": vision.to_dict() if vision != null else {},
	}


## Restores a world saved by `to_dict()` into this (empty) world: economy, nodes,
## buildings and units with their ids, then reconnects orders to their targets.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported SimWorld save version")
	var economy_data: Dictionary = data.get("economy", {})
	if not economy_data.is_empty():
		economy.from_dict(economy_data)
	var saved_nodes: Array = data.get("resource_nodes", [])
	for entry: Variant in saved_nodes:
		var node_data: Dictionary = entry
		var node_def: ResourceNodeDef = _load_def(node_data) as ResourceNodeDef
		if node_def != null:
			var node: ResourceNode = spawn_resource_node(node_def, _saved_position(node_data))
			_restore_id(node, node.entity_id, node_data)
			node.from_dict(node_data)
	var saved_sites: Array = data.get("sites", [])
	for entry: Variant in saved_sites:
		var site_data: Dictionary = entry
		var site_path: String = site_data.get("def", "")
		if site_path == "" or not ResourceLoader.exists(site_path):
			continue
		var site_def: DiscoveryDef = load(site_path) as DiscoveryDef
		if site_def != null:
			var site: DiscoverySite = spawn_site(site_def, _saved_position(site_data))
			_restore_id(site, site.entity_id, site_data)
			site.from_dict(site_data)
	var discovery_data: Dictionary = data.get("discovery", {})
	if not discovery_data.is_empty():
		discovery.from_dict(discovery_data)
	var saved_buildings: Array = data.get("buildings", [])
	for entry: Variant in saved_buildings:
		var building_data: Dictionary = entry
		var building_def: BuildingDef = _load_def(building_data) as BuildingDef
		if building_def != null:
			var faction: int = building_data.get("faction", 0)
			var building: Building = spawn_building(
				building_def, faction, _saved_position(building_data), false
			)
			_restore_id(building, building.entity_id, building_data)
			building.from_dict(building_data)
	var saved_units: Array = data.get("units", [])
	for entry: Variant in saved_units:
		var unit_data: Dictionary = entry
		var unit_def: UnitDef = _load_def(unit_data) as UnitDef
		if unit_def != null:
			var faction: int = unit_data.get("faction", 0)
			var unit: Unit = spawn_unit(unit_def, faction, Vector3.ZERO)
			_restore_id(unit, unit.entity_id, unit_data)
			unit.from_dict(unit_data)
	var saved_next: int = data.get("next_id", _next_id)
	_next_id = maxi(_next_id, saved_next)
	for unit: Unit in units:
		if unit.orders != null:
			unit.orders.resolve_targets(entity)
	var vision_data: Dictionary = data.get("vision", {})
	if vision != null and not vision_data.is_empty():
		vision.from_dict(vision_data)
	var combat_data: Dictionary = data.get("combat", {})
	if not combat_data.is_empty():
		combat.from_dict(combat_data, entity)


func _restore_id(node: Node3D, current_id: int, data: Dictionary) -> void:
	var saved_id: int = data.get("entity_id", current_id)
	if saved_id == current_id:
		return
	_entities.erase(current_id)
	_entities[saved_id] = node
	if _blocks.has(current_id):
		_blocks[saved_id] = _blocks[current_id]
		_blocks.erase(current_id)
	_next_id = maxi(_next_id, saved_id + 1)


static func _load_def(data: Dictionary) -> EntityDef:
	var path: String = data.get("def", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as EntityDef


static func _saved_position(data: Dictionary) -> Vector3:
	var text: String = data.get("position", "Vector3(0, 0, 0)")
	var position: Vector3 = str_to_var(text)
	return position


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
