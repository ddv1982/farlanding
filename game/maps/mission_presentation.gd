class_name MissionPresentation
extends Node
## Gives a running mission its look on the map (the glue between missions/sim and the
## presentation pieces): an ObjectiveMarker for every known objective with an area
## (following its state and moves), a SightConeVisual on every watcher of a faction
## with an alert meter (fed with its suspicion and alert each frame, shrinking with a
## dust storm's sight factor; hidden with the unit when the player cannot see it) and
## the cloak shimmer on the player's own cloaked units. Reads the simulation, never
## changes it.

## How fast the cloak look fades in and out, per second.
const CLOAK_FADE: float = 3.0
## Markers float this far above the ground point.
const MARKER_LIFT: float = 0.4

var world: SimWorld = null
var player_faction: int = 0

var _markers: Dictionary[Objective, ObjectiveMarker] = {}
var _cones: Dictionary[Unit, SightConeVisual] = {}
var _cone_ranges: Dictionary[Unit, float] = {}
var _cloaks: Dictionary[Unit, float] = {}


func setup(p_world: SimWorld, p_player_faction: int) -> void:
	world = p_world
	player_faction = p_player_faction
	Events.entity_spawned.connect(_on_entity_spawned)
	Events.objective_added.connect(_on_objective_changed)
	Events.objective_updated.connect(_on_objective_changed)
	Events.objective_completed.connect(_on_objective_changed)
	Events.objective_failed.connect(_on_objective_changed)
	Events.entity_sabotaged.connect(_on_entity_sabotaged)
	for unit: Unit in world.units:
		_on_entity_spawned(unit)


## After a saved game was restored: give the restored world the looks the events
## that made it would have given (sabotaged buildings). Objective markers follow the
## objectives the mission announces again; damage, construction, cloak and storm
## looks follow the components' own signals.
func show_restored_state() -> void:
	for building: Building in world.buildings:
		if building.is_sabotaged:
			_on_entity_sabotaged(building, null)


func _process(delta: float) -> void:
	_drop_freed()
	for unit: Variant in _cones.keys():
		var watcher: Unit = unit
		var cone: SightConeVisual = _cones[watcher]
		if watcher.is_dead:
			cone.visible = false
			continue
		cone.set_suspicion(watcher.suspicion)
		cone.set_alerted(watcher.is_alerted)
		var reach: float = watcher.sight_range
		var shown: float = _cone_ranges.get(watcher, reach)
		if absf(reach - shown) > 0.25:
			_cone_ranges[watcher] = reach
			cone.set_cone(reach, watcher.sight_angle)
	for unit: Variant in _cloaks.keys():
		var cloaked: Unit = unit
		var target: float = 1.0 if cloaked.is_cloaked else 0.0
		var amount: float = move_toward(_cloaks[cloaked], target, CLOAK_FADE * delta)
		if amount != _cloaks[cloaked]:
			_cloaks[cloaked] = amount
			var visual: UnitVisual = _visual_of(cloaked)
			if visual != null:
				visual.set_cloaked(amount)


## Forgets units that were freed. A freed object cannot be erased from a typed
## dictionary (the engine refuses the key), so the dictionaries are rebuilt instead.
func _drop_freed() -> void:
	var stale: bool = false
	for unit: Variant in _cones.keys():
		stale = stale or not is_instance_valid(unit)
	for unit: Variant in _cloaks.keys():
		stale = stale or not is_instance_valid(unit)
	if not stale:
		return
	var cones: Dictionary[Unit, SightConeVisual] = {}
	var ranges: Dictionary[Unit, float] = {}
	for unit: Variant in _cones.keys():
		if is_instance_valid(unit):
			var watcher: Unit = unit
			cones[watcher] = _cones[watcher]
			ranges[watcher] = _cone_ranges.get(watcher, 0.0)
	var cloaks: Dictionary[Unit, float] = {}
	for unit: Variant in _cloaks.keys():
		if is_instance_valid(unit):
			var cloaked: Unit = unit
			cloaks[cloaked] = _cloaks[cloaked]
	_cones = cones
	_cone_ranges = ranges
	_cloaks = cloaks


func _on_entity_spawned(entity: Node3D) -> void:
	var unit: Unit = entity as Unit
	if unit == null or unit.def == null:
		return
	var visual: UnitVisual = _visual_of(unit)
	if visual == null:
		return
	if unit.faction == player_faction and unit.cloak != null:
		_cloaks[unit] = 0.0
	if unit.watcher != null and unit.sight_angle < 360.0 and _has_alert_meter(unit.faction):
		var cone: SightConeVisual = SightConeVisual.new()
		cone.name = &"SightCone"
		visual.add_child(cone)
		cone.set_cone(unit.sight_range, unit.sight_angle)
		_cones[unit] = cone
		_cone_ranges[unit] = unit.sight_range


func _on_entity_sabotaged(building: Node3D, _saboteur: Node3D) -> void:
	if not is_instance_valid(building):
		return
	for child: Node in building.get_children():
		var visual: BuildingVisual = child as BuildingVisual
		if visual != null:
			visual.set_sabotaged(true)


func _on_objective_changed(objective: RefCounted) -> void:
	var changed: Objective = objective as Objective
	if changed == null or not changed.is_known:
		return
	var marker: ObjectiveMarker = _markers.get(changed, null)
	if not changed.has_area:
		return
	if marker == null:
		marker = ObjectiveMarker.new()
		marker.name = &"ObjectiveMarker"
		marker.kind = changed.kind
		add_child(marker)
		_markers[changed] = marker
	marker.radius = changed.area_radius
	marker.position = _ground(changed.area_center)
	marker.set_state(changed.state)


func _has_alert_meter(faction: int) -> bool:
	return world.stealth != null and world.stealth.guard_factions.has(faction)


func _ground(point: Vector3) -> Vector3:
	if world.heights != null:
		point.y = world.heights.sample(point.x, point.z)
	return point + Vector3.UP * MARKER_LIFT


static func _visual_of(unit: Unit) -> UnitVisual:
	for child: Node in unit.get_children():
		if child is UnitVisual:
			return child
	return null
