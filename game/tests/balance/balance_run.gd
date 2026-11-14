extends Node
## One balance run (ADR 0018, not part of check.sh): plays a mission on its real map
## with the ReferencePlayer in the player's seat (or nobody, `--player=idle`) until it
## ends or the time cap, then prints a short report and one `BALANCE {json}` line that
## `tools/balance.sh` collects. Deterministic for a seed as far as the sim is (the
## commanders' dice are seeded; avoidance timing can still differ slightly).
##
##   godot --headless --fixed-fps 60 --path game res://tests/balance/balance_run.tscn \
##       -- --mission=conquest --seed=1 --difficulty=normal [--player=idle]
##          [--minutes=45] [--techs=id,id] [--log]
##
## `--mission` takes a mission id or a campaign route node id; a route landing gets a
## fresh campaign's modifiers plus the typical techs for that landing (TECH_ORDER),
## or those in `--techs` (`--techs=all`: every tech; `--techs=none`: none).

const CATALOG: String = "res://data/missions/catalog.tres"
## Techs a route landing assumes owned unless `--techs` says otherwise: what a
## not-too-thorough player has bought by then, in buying order, and how many of them
## by each landing (`tools/balance_campaign.py -x 0.7 --gdscript`, ADR 0018).
const TECH_ORDER: PackedStringArray = [
	"survey_lab",
	"lancer_rails",
	"sentry_grid",
	"hauler_racks",
	"talon_frames",
	"heat_shielding",
	"pressure_valves",
	"scan_discount",
	"supply_manifest",
	"understory_optics",
	"arc_battery",
]
## Route node -> how many of TECH_ORDER are owned when it starts.
const TECHS_OWNED: Dictionary[String, int] = {
	"kessel_proving": 0,
	"kessel_storm": 2,
	"thalassa_shallows": 4,
	"thalassa_recovery": 6,
	"emberfall_conquest": 7,
	"emberfall_holdout": 8,
	"verdance_conquest": 8,
	"verdance_infiltration": 9,
	"hollow_power": 10,
	"hollow_finale": 11,
}
const CAMPAIGN: String = "res://data/campaign/kessel_trail.tres"

var _mission_id: String = "conquest"
var _seed: int = 1
var _difficulty: String = "normal"
var _player: String = "reference"
var _max_seconds: float = 45.0 * 60.0
var _techs: PackedStringArray = []
var _techs_given: bool = false
var _log: bool = false
var _map: LandingMap = null
var _reference: ReferencePlayer = null
var _recorder: BalanceRecorder = null
var _started_msec: int = 0
var _done: bool = false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--mission="):
			_mission_id = value
		elif arg.begins_with("--seed="):
			_seed = int(value)
		elif arg.begins_with("--difficulty="):
			_difficulty = value
		elif arg.begins_with("--player="):
			_player = value
		elif arg.begins_with("--minutes="):
			_max_seconds = float(value) * 60.0
		elif arg.begins_with("--techs="):
			_techs = value.split(",", false)
			_techs_given = true
		elif arg == "--log":
			_log = true
	_start.call_deferred()


func _start() -> void:
	var modifiers: Array[LandingModifiers] = [null]
	var def: MissionDef = _find_mission(_mission_id, modifiers)
	if def == null:
		printerr("balance: no mission or route node '%s'" % _mission_id)
		get_tree().quit(2)
		return
	def = def.duplicate() as MissionDef
	if def.commander_profile != null:
		var profile: CommanderProfile = def.commander_profile.duplicate() as CommanderProfile
		profile.random_seed += _seed * 131
		def.commander_profile = profile
	# The player's choice shifts the mission's own level (Difficulty.effective).
	if modifiers[0] == null:
		modifiers[0] = LandingModifiers.new()
	modifiers[0].difficulty = Difficulty.sanitize(_difficulty)
	_map = def.map_scene.instantiate() as LandingMap
	_map.mission = def
	_map.modifiers = modifiers[0]
	_map.log_enemy_ai = _log
	add_child(_map)
	var runner: Mission = _map.runner
	if _player == "reference" and ReferencePlayer.can_play(def):
		_reference = ReferencePlayer.new()
		_reference.name = &"Reference"
		add_child(_reference)
		_reference.setup(runner, _seed)
		_reference.commander.verbose = _log
	elif _player == "reference":
		print("balance: %s is not driven by the reference player (idle run)" % def.id)
	_recorder = BalanceRecorder.new(runner)
	runner.context.sim_clock.ticked.connect(_on_ticked)
	_started_msec = Time.get_ticks_msec()


func _on_ticked(tick: int) -> void:
	if _done:
		return
	_recorder.on_tick(tick)
	var runner: Mission = _map.runner
	if runner.result != null or runner.elapsed_seconds() >= _max_seconds:
		_done = true
		_report.call_deferred()


func _report() -> void:
	var summary: Dictionary = _recorder.summary()
	_recorder.stop()
	summary["mission"] = String(_map.runner.def.id)
	summary["seed"] = _seed
	summary["difficulty"] = _difficulty
	summary["enemy_level"] = String(_map.runner.commander_level())
	summary["player"] = _player if _reference != null else "idle"
	summary["techs"] = _techs.size()
	summary["wall_seconds"] = roundi((Time.get_ticks_msec() - _started_msec) / 1000.0)
	if _reference != null:
		summary["player_waves"] = _reference.commander.wave_sizes.duplicate()
	var outcome: String = "timeout"
	if summary["over"]:
		outcome = "WON" if summary["won"] else "LOST"
	var lines: PackedStringArray = [
		(
			"balance %s seed %d %s (%s): %s at %s"
			% [
				summary["mission"],
				_seed,
				_difficulty,
				summary["player"],
				outcome,
				_clock(summary["seconds"])
			]
		),
		(
			"  first enemy hit %s, first attack %s, enemy waves %s, player waves %s"
			% [
				_clock(summary["first_hit"]),
				_clock(summary["first_attack"]),
				str(summary["enemy_waves"]),
				str(summary.get("player_waves", []))
			]
		),
		(
			"  lost %d units %d buildings, destroyed %d; intel %d; alloy in %d flux in %d"
			% [
				summary["units_lost"],
				summary["buildings_lost"],
				summary["enemies_destroyed"],
				summary["intel"],
				summary["alloy_income"],
				summary["flux_income"]
			]
		),
		"  objectives %s" % str(summary["objectives"]),
		(
			"  damage to player %s, to enemy %s, eruptions %d"
			% [
				str(summary["damage_taken"]),
				str(summary["enemy_damage_taken"]),
				summary["eruptions"]
			]
		),
		(
			"  losses: player %s, enemy %s"
			% [str(summary["player_losses"]), str(summary["enemy_losses"])]
		),
		"  minute: player army / enemy army / alloy banked",
	]
	var left: PackedStringArray = summary["enemy_left"]
	if not left.is_empty():
		lines.insert(7, "  enemy left: %s" % ", ".join(left.slice(0, 12)))
	var row: PackedStringArray = []
	for sample: Array in summary["samples"]:
		row.append("%d:%d/%d/%d" % [_minute(sample[0]), sample[1], sample[2], sample[3]])
	lines.append("  " + " ".join(row))
	print("\n".join(lines))
	print("BALANCE " + JSON.stringify(summary))
	get_tree().quit(0)


## The mission `id` names (a mission id or a route node id); a route landing's
## modifiers go into `modifiers[0]`.
func _find_mission(id: String, modifiers: Array[LandingModifiers]) -> MissionDef:
	var campaign: CampaignDef = load(CAMPAIGN)
	for route_node: RouteNodeDef in campaign.nodes:
		if String(route_node.id) == id or String(route_node.mission.id) == id:
			var state: CampaignState = CampaignState.new(campaign)
			if not _techs_given:
				var owned: int = TECHS_OWNED.get(String(route_node.id), 0)
				_techs = TECH_ORDER.slice(0, owned)
			for tech: TechDef in campaign.techs:
				if _techs.has("all") or _techs.has(String(tech.id)):
					state.techs.append(tech.id)
			modifiers[0] = LandingBuilder.build(
				campaign, LandingPlan.from_state(state, route_node.id)
			)
			return route_node.mission
	var catalog: MissionCatalog = load(CATALOG)
	for mission: MissionDef in catalog.missions:
		if String(mission.id) == id:
			return mission
	return null


static func _minute(value: Variant) -> int:
	var seconds: int = value
	return seconds / 60


static func _clock(value: Variant) -> String:
	var seconds: int = value
	if seconds < 0:
		return "never"
	return "%d:%02d" % [seconds / 60, seconds % 60]
