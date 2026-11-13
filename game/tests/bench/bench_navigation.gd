extends Node
## Phase 0 navigation spike (not part of check.sh): spawns UNIT_COUNT units on Kessel
## Proving, orders all of them across the map in one MoveCommand and reports the sim
## cost per tick, the path-request burst and frame times until everyone has arrived.
##
## Headless:  godot --headless --path game res://tests/bench/bench_navigation.tscn
## Windowed:  same without --headless (or play the scene from the editor).
## Add `-- --no-avoidance` to run without RVO agents.

const MAP: PackedScene = preload("res://maps/kessel_proving/kessel_proving.tscn")
const UNIT_COUNT: int = 200
const SPAWN_AREA: Rect2 = Rect2(-112.0, 62.0, 100.0, 48.0)
const SPAWN_SPACING: float = 4.0
const TARGET: Vector3 = Vector3(55.0, 0.0, -40.0)
const TIMEOUT_SECONDS: float = 120.0
const REPORT_PATH: String = "user://bench_navigation.txt"
const ROSTER: Array[String] = [
	"res://data/units/concord_ranger.tres",
	"res://data/units/concord_ranger.tres",
	"res://data/units/concord_ranger.tres",
	"res://data/units/concord_surveyor.tres",
	"res://data/units/concord_kite.tres",
	"res://data/units/concord_bulwark.tres",
]

var _map: LandingMap
var _frame: int = 0
var _spawned_at_msec: int = -1
var _ordered_at_msec: int = -1
var _physics_started_usec: int = 0
var _tick_costs: Array[float] = []
var _world_costs: Array[float] = []
var _frame_ms: Array[float] = []
var _process_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _navigation_ms: Array[float] = []
var _all_arrived_seconds: float = -1.0
var _ninety_five_seconds: float = -1.0
var _path_burst_usec: int = 0
var _slot_burst_usec: int = 0
var _command_usec: int = 0
var _safe_seen: int = 0
var _target_walkable: bool = false
var _last_frame_usec: int = 0
var _avoidance: bool = true


func _ready() -> void:
	process_physics_priority = -100
	_avoidance = not OS.get_cmdline_user_args().has("--no-avoidance")
	_map = MAP.instantiate() as LandingMap
	_map.with_mission = false
	add_child(_map)
	(_map.world.paths as NavmeshPathService).avoidance_enabled = _avoidance
	Events.sim_ticked.connect(_on_sim_ticked)


func _physics_process(_delta: float) -> void:
	_physics_started_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	_frame += 1
	var now: int = Time.get_ticks_usec()
	if _ordered_at_msec >= 0 and _last_frame_usec > 0:
		_frame_ms.append((now - _last_frame_usec) / 1000.0)
		_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_navigation_ms.append(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0)
	_last_frame_usec = now
	# Wait for the navigation map to sync before spawning (closest_point needs it),
	# then give avoidance agents a moment before ordering.
	if _spawned_at_msec < 0:
		var map: RID = get_viewport().world_3d.navigation_map
		if NavigationServer3D.map_get_closest_point(map, _map.map_def.landing_zone) != Vector3.ZERO:
			_spawn()
			_spawned_at_msec = Time.get_ticks_msec()
	elif _ordered_at_msec < 0:
		if Time.get_ticks_msec() - _spawned_at_msec > 1000:
			_order()
	else:
		_check_done()


func _spawn() -> void:
	var paths: PathService = _map.world.paths
	var count: int = 0
	var z: float = SPAWN_AREA.position.y
	while z <= SPAWN_AREA.end.y and count < UNIT_COUNT:
		var x: float = SPAWN_AREA.position.x
		while x <= SPAWN_AREA.end.x and count < UNIT_COUNT:
			var point: Vector3 = Vector3(x, _map.heights.sample(x, z), z)
			var walkable: Vector3 = paths.closest_point(point)
			if Vector2(walkable.x - x, walkable.z - z).length() < 0.5:
				var def: UnitDef = load(ROSTER[count % ROSTER.size()])
				_map.world.spawn_unit(def, 0, walkable, Mover.yaw_for(TARGET - point))
				count += 1
			x += SPAWN_SPACING
		z += SPAWN_SPACING
	print("bench: spawned %d units (avoidance %s)" % [count, "on" if _avoidance else "off"])
	var map: RID = get_viewport().world_3d.navigation_map
	print("bench: navigation map %s" % map)


func _order() -> void:
	var entities: Array[Node3D] = []
	entities.assign(_map.world.units)
	# The path bursts on their own: one query per unit, to formation slots (what an
	# order does) and to a single point (worst case if that point is unreachable).
	var starts: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for unit: Unit in _map.world.units:
		starts.append(unit.locomotion.mover.position)
		radii.append(unit.def.radius)
	var formation: Formation = Formation.new(
		starts.size(),
		TARGET,
		TARGET - starts[0],
		Formation.spacing_for(radii),
		_map.world.paths.is_walkable
	)
	var started: int = Time.get_ticks_usec()
	for i: int in starts.size():
		_map.world.paths.find_path(starts[i], formation.slots[i])
	_slot_burst_usec = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for i: int in starts.size():
		_map.world.paths.find_path(starts[i], TARGET)
	_path_burst_usec = Time.get_ticks_usec() - started
	_target_walkable = _map.world.paths.is_walkable(TARGET)
	# Executed directly (not via the queue) so its cost can be timed on its own.
	var command: MoveCommand = MoveCommand.new(MoveCommand.KIND_MOVE, 0, entities, TARGET)
	started = Time.get_ticks_usec()
	command.execute()
	_command_usec = Time.get_ticks_usec() - started
	_ordered_at_msec = Time.get_ticks_msec()


func _on_sim_ticked(_tick: int) -> void:
	if _ordered_at_msec < 0:
		return
	var cost: float = (Time.get_ticks_usec() - _physics_started_usec) / 1000.0
	for unit: Unit in _map.world.units:
		if unit.locomotion.get(&"_has_safe_velocity"):
			_safe_seen += 1
	_tick_costs.append(cost)
	_world_costs.append(_map.world.last_tick_usec / 1000.0)


func _check_done() -> void:
	var elapsed: float = (Time.get_ticks_msec() - _ordered_at_msec) / 1000.0
	var idle: int = 0
	for unit: Unit in _map.world.units:
		if unit.orders.is_idle() and unit.locomotion.mover.speed == 0.0:
			idle += 1
	var total: int = _map.world.units.size()
	if _ninety_five_seconds < 0.0 and idle >= ceili(total * 0.95):
		_ninety_five_seconds = elapsed
	if idle == total or elapsed > TIMEOUT_SECONDS:
		if idle == total:
			_all_arrived_seconds = elapsed
		_report(idle, total)
		get_tree().quit()


func _report(idle: int, total: int) -> void:
	var lines: PackedStringArray = [
		"bench: ==== navigation benchmark ====",
		(
			"bench: renderer %s, avoidance %s"
			% [DisplayServer.get_name(), "on" if _avoidance else "off"]
		),
		"bench: units %d, arrived %d" % [total, idle],
		(
			"bench: 95%% arrived after %.1f s, all after %.1f s"
			% [_ninety_five_seconds, _all_arrived_seconds]
		),
		"bench: path burst to slots       %d queries %.2f ms" % [total, _slot_burst_usec / 1000.0],
		(
			"bench: path burst to one point   %d queries %.2f ms (point walkable: %s)"
			% [total, _path_burst_usec / 1000.0, _target_walkable]
		),
		(
			"bench: MoveCommand.execute (formation + %d paths) %.2f ms"
			% [total, _command_usec / 1000.0]
		),
		(
			"bench: group corridors %d, members needing their own query %d"
			% [
				(_map.world.paths as NavmeshPathService).shared_paths_built,
				(_map.world.paths as NavmeshPathService).group_fallback_paths,
			]
		),
		"bench: unit-ticks with an avoidance velocity: %d" % _safe_seen,
		"bench: sim per tick (all)    %s" % _stats(_tick_costs),
		"bench: world per tick        %s" % _stats(_world_costs),
		"bench: frame time            %s" % _stats(_frame_ms),
		"bench: process time          %s" % _stats(_process_ms),
		"bench: physics time          %s" % _stats(_physics_ms),
		"bench: navigation time       %s" % _stats(_navigation_ms),
	]
	var text: String = "\n".join(lines)
	print(text)
	# Also saved, since an editor-launched run's output is gone once it quits.
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(text + "\n")


static func _stats(values: Array[float]) -> String:
	if values.is_empty():
		return "n/a"
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted:
		total += value
	var p95: float = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]
	return (
		"mean %.2f ms  p95 %.2f ms  max %.2f ms  (n=%d)"
		% [total / sorted.size(), p95, sorted[sorted.size() - 1], sorted.size()]
	)
