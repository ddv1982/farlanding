extends Node
## Phase 6 performance bench (not part of check.sh): a late Conquest fight on Kessel
## Proving. The Conquest mission runs as in play (fog of war, the Combine commander,
## the dust storm rule); then ARMY units per side are dropped in the middle of the map
## and sent at each other. Reports the sim tick cost by section, the vision update,
## the commander's decisions and the frame time while they fight.
##
## Headless:  godot --headless --path game res://tests/bench/bench_battle.tscn
## Add `-- --storm` to hold a full dust storm, `-- --seconds=N` to run longer,
## `-- --no-props` to leave the map's boulders out, `-- --sections` to split the tick
## cost by system (the split itself costs a little).

const MISSION: String = "res://data/missions/conquest.tres"
const ARMY: int = 110
const SETTLE_FRAMES: int = 30
const WEB_WARMUP_MSEC: int = 5000
const PLAYER_CENTRE: Vector3 = Vector3(-34.0, 0.0, 22.0)
const ENEMY_CENTRE: Vector3 = Vector3(30.0, 0.0, -14.0)
const PLAYER_ROSTER: Array[String] = [
	"res://data/units/concord_ranger.tres",
	"res://data/units/concord_ranger.tres",
	"res://data/units/concord_lancer.tres",
	"res://data/units/concord_bulwark.tres",
	"res://data/units/concord_kite.tres",
	"res://data/units/concord_arc.tres",
]
const ENEMY_ROSTER: Array[String] = [
	"res://data/units/combine_skitter.tres",
	"res://data/units/combine_skitter.tres",
	"res://data/units/combine_stinger.tres",
	"res://data/units/combine_mauler.tres",
]

var _map: LandingMap
var _frames: int = 0
var _started_msec: int = -1
var _seconds: float = 40.0
var _storm: bool = false
var _tick_ms: Array[float] = []
var _vision_ms: Array[float] = []
var _frame_ms: Array[float] = []
var _last_frame_usec: int = 0
var _peak_units: int = 0
var _finished: bool = false
var _logic_start: int = 0
var _render_start: int = 0
var _physics_start: int = 0
var _logic_ms: Array[float] = []
var _render_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _draw_calls: Array[float] = []


func _ready() -> void:
	seed(1729)
	get_tree().process_frame.connect(_on_process_frame)
	get_tree().physics_frame.connect(_on_physics_frame)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_storm = args.has("--storm")
	for arg: String in args:
		if arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
	_map = (load("res://maps/kessel_proving/kessel_proving.tscn") as PackedScene).instantiate()
	_map.mission = load(MISSION) as MissionDef
	if args.has("--no-props"):
		_map.with_props = false
	add_child(_map)
	Events.sim_ticked.connect(_on_sim_ticked)
	if OS.has_feature("web"):
		GraphicsSettings.apply(_map, Settings.QUALITY_MEDIUM)
		_map.camera.center_on(Vector3.ZERO)
		JavaScriptBridge.eval("window.farlanding.ready = true")


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _measuring() and _last_frame_usec > 0:
		_frame_ms.append((now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now
	_frames += 1
	if _frames == SETTLE_FRAMES:
		_drop_armies()
	if (
		_started_msec >= 0
		and Time.get_ticks_msec() - _started_msec > _seconds * 1000.0 + _warmup_msec()
	):
		_report()


func _drop_armies() -> void:
	var world: SimWorld = _map.world
	_spawn(world, PLAYER_ROSTER, 0, PLAYER_CENTRE, ENEMY_CENTRE)
	_spawn(world, ENEMY_ROSTER, 1, ENEMY_CENTRE, PLAYER_CENTRE)
	_peak_units = world.units.size()
	world.profiling = OS.get_cmdline_user_args().has("--sections")
	world.profiling_units = world.profiling
	world.section_usec.clear()
	if _storm and world.planet != null:
		var storms: DustStormSystem = world.planet as DustStormSystem
		storms.schedule_climax(world.context.sim_clock.get_tick() + 10)
	_started_msec = Time.get_ticks_msec()
	print("bench_battle: %d units in the world" % world.units.size())


func _spawn(
	world: SimWorld, roster: Array[String], faction: int, centre: Vector3, goal: Vector3
) -> void:
	var defs: Array[UnitDef] = []
	for i: int in ARMY:
		defs.append(load(roster[i % roster.size()]) as UnitDef)
	var units: Array[Unit] = _map.runner.spawn_group(defs, faction, centre, goal - centre)
	var nodes: Array[Node3D] = []
	nodes.assign(units)
	world.context.command_queue.push(MoveCommand.new(MoveCommand.KIND_MOVE, faction, nodes, goal))


func _on_sim_ticked(_tick: int) -> void:
	if not _measuring():
		return
	var world: SimWorld = _map.world
	_tick_ms.append(world.last_tick_usec / 1000.0)
	if world.vision != null:
		_vision_ms.append(world.vision.last_update_usec / 1000.0)
	_peak_units = maxi(_peak_units, world.units.size())


func _report() -> void:
	_finished = true
	set_process(false)
	var world: SimWorld = _map.world
	var ticks: int = _tick_ms.size()
	var lines: PackedStringArray = [
		(
			"bench_battle: %d s, %d sim ticks, peak %d units, %d left, storm %s"
			% [roundi(_seconds), ticks, _peak_units, world.units.size(), str(_storm)]
		),
		"  sim tick       mean %.2f ms  p95 %.2f  max %.2f" % _stats(_tick_ms),
		"  vision update  mean %.2f ms  p95 %.2f  max %.2f" % _stats(_vision_ms),
		"  frame          mean %.2f ms  p95 %.2f  max %.2f" % _stats(_frame_ms),
	]
	lines.append("  scene process  mean %.2f ms  p95 %.2f  max %.2f" % _stats(_logic_ms))
	lines.append("  render submit  mean %.2f ms  p95 %.2f  max %.2f" % _stats(_render_ms))
	lines.append("  physics span   mean %.2f ms  p95 %.2f  max %.2f" % _stats(_physics_ms))
	lines.append("  draw calls     mean %.0f  p95 %.0f  max %.0f" % _stats(_draw_calls))
	var sections: Array[StringName] = world.section_usec.keys()
	sections.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return world.section_usec[a] > world.section_usec[b]
	)
	for section: StringName in sections:
		var per_tick: float = world.section_usec[section] / 1000.0 / maxf(ticks, 1.0)
		lines.append("  %-15s %.3f ms per tick" % [section, per_tick])
	var commander: Commander = _map.runner.commander
	if commander != null:
		lines.append(
			(
				"  commander      %d decisions, mean %.2f ms, max %.2f ms"
				% [
					commander.decisions,
					commander.average_decision_usec() / 1000.0,
					commander.max_decision_usec / 1000.0
				]
			)
		)
	print("\n".join(lines))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.farlanding.benchmark = " + JSON.stringify(lines))
		_map.context.sim_clock.paused = true
		set_process(false)
	else:
		get_tree().quit()


static func _stats(values: Array[float]) -> Array[float]:
	if values.is_empty():
		return [0.0, 0.0, 0.0]
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted:
		total += value
	var p95: float = sorted[mini(floori(sorted.size() * 0.95), sorted.size() - 1)]
	return [total / sorted.size(), p95, sorted[sorted.size() - 1]]


func _warmup_msec() -> int:
	return WEB_WARMUP_MSEC if OS.has_feature("web") else 0


func _measuring() -> bool:
	return (
		not _finished
		and _started_msec >= 0
		and Time.get_ticks_msec() - _started_msec >= _warmup_msec()
	)


func _on_physics_frame() -> void:
	if _physics_start == 0:
		_physics_start = Time.get_ticks_usec()


func _on_process_frame() -> void:
	_logic_start = Time.get_ticks_usec()
	if _measuring() and _physics_start > 0:
		_physics_ms.append((_logic_start - _physics_start) / 1000.0)
	_physics_start = 0


func _on_pre_draw() -> void:
	_render_start = Time.get_ticks_usec()
	if _measuring() and _logic_start > 0:
		_logic_ms.append((_render_start - _logic_start) / 1000.0)


func _on_post_draw() -> void:
	if _measuring() and _render_start > 0:
		_render_ms.append((Time.get_ticks_usec() - _render_start) / 1000.0)
		_draw_calls.append(
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			)
		)
