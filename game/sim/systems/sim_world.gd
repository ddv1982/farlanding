class_name SimWorld
extends Node3D
## Owns the units of one mission: spawns them, ticks them on the sim clock and moves
## their nodes between ticks. Registered on the MissionContext as `SERVICE_KEY`.

const SERVICE_KEY: StringName = &"world"

var context: MissionContext = null
var paths: PathService = PathService.new()
var heights: HeightField = null
var units: Array[Unit] = []
## Wall-clock cost of the last sim tick for all units, in microseconds.
var last_tick_usec: int = 0


## Wires the world into a mission. Call before spawning.
func setup(p_context: MissionContext, p_paths: PathService, p_heights: HeightField) -> void:
	context = p_context
	paths = p_paths
	heights = p_heights
	context.set_service(SERVICE_KEY, self)
	context.sim_clock.ticked.connect(_on_ticked)


## Creates a unit of type `def` for `faction` standing at `at` facing `yaw`.
func spawn_unit(def: UnitDef, faction: int, at: Vector3, yaw: float = 0.0) -> Unit:
	assert(def.scene != null, "UnitDef %s has no scene" % def.id)
	var unit: Unit = def.scene.instantiate() as Unit
	assert(unit != null, "Scene of %s is not a Unit" % def.id)
	unit.def = def
	unit.faction = faction
	unit.name = "%s_%d" % [def.id, units.size()]
	add_child(unit)
	if unit.locomotion != null:
		unit.locomotion.setup(def, at, yaw, paths, heights)
	units.append(unit)
	unit.tree_exiting.connect(_on_unit_exiting.bind(unit))
	Events.entity_spawned.emit(unit)
	return unit


## Units of `faction`.
func units_of(faction: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in units:
		if unit.faction == faction:
			result.append(unit)
	return result


func _process(_delta: float) -> void:
	if context == null:
		return
	var fraction: float = context.sim_clock.get_interpolation_fraction()
	for unit: Unit in units:
		if unit.locomotion != null:
			unit.locomotion.interpolate(fraction)


func _on_ticked(_tick: int) -> void:
	var started: int = Time.get_ticks_usec()
	var dt: float = context.sim_clock.get_tick_delta()
	for unit: Unit in units:
		unit.sim_tick(dt)
	last_tick_usec = Time.get_ticks_usec() - started


func _on_unit_exiting(unit: Unit) -> void:
	units.erase(unit)
