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

var _map: KesselProving
var _frames: int = 0
var _started_msec: int = -1
var _seconds: float = 40.0
var _storm: bool = false
var _tick_ms: Array[float] = []
var _vision_ms: Array[float] = []
var _frame_ms: Array[float] = []
var _last_frame_usec: int = 0
var _peak_units: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_storm = args.has("--storm")
	for arg: String in args:
		if arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
	_map = (load("res://maps/kessel_proving/kessel_proving.tscn") as PackedScene).instantiate()
	_map.mission = load(MISSION) as MissionDef
	if args.has("--no-props"):
		_map.prop_layout = null
	add_child(_map)
	Events.sim_ticked.connect(_on_sim_ticked)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _started_msec >= 0 and _last_frame_usec > 0:
		_frame_ms.append((now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now
	_frames += 1
	if _frames == SETTLE_FRAMES:
		_drop_armies()
	if _started_msec >= 0 and Time.get_ticks_msec() - _started_msec > _seconds * 1000.0:
		_report()


func _drop_armies() -> void:
	var world: SimWorld = _map.world
	_spawn(world, PLAYER_ROSTER, 0, PLAYER_CENTRE, ENEMY_CENTRE)
	_spawn(world, ENEMY_ROSTER, 1, ENEMY_CENTRE, PLAYER_CENTRE)
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
	if _started_msec < 0:
		return
	var world: SimWorld = _map.world
	_tick_ms.append(world.last_tick_usec / 1000.0)
	if world.vision != null:
		_vision_ms.append(world.vision.last_update_usec / 1000.0)
	_peak_units = maxi(_peak_units, world.units.size())


func _report() -> void:
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
