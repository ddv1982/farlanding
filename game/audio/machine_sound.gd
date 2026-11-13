class_name MachineSound
extends Node
## Hollow Meridian's old engines -> sound (Phase 8d). Listens to
## `Events.machine_reactivated`, `machine_lost` and `mission_started`; the
## rules live in MachineCues. It depends on nothing of gameplay but those
## signals, node positions and `is_visible_to_player` (duck-typed, optional).
##
## - One-shots (spin-up, wind-down, the enemy's colder seizure) play at the
##   machine through `play_at` (positional, the SoundEvent's own distance).
## - While an engine runs for the player, `loop_engine_run` hums at it on this
##   node's own positional players (at most MachineCues.MAX_HUMS, nearest the
##   camera's focus within HUM_RADIUS), fading in after the spin-up.
## - Every machine it has heard of is "tracked": BaseLoops leaves tracked nodes
##   alone, so an engine that is also in group &"buildings" is not hummed twice.
## - mission_started (and going aboard the ship): everything stops and resets.

## Plays a positional event: `func(id: StringName, at: Vector3) -> bool`.
var play_at: Callable = func(_id: StringName, _at: Vector3) -> bool: return false
## Looks up a SoundEvent: `func(id: StringName) -> SoundEvent`.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## Listener focus on the ground; set by the AudioService.
var focus: Vector3 = Vector3.ZERO
## Whose engines spin up and hum.
var player_faction: int = 0
## One-shots started so far (tests count them).
var played: Array[StringName] = []

## Instance id -> machine running for the player (weak), and when its hum may start.
var _running: Dictionary[int, WeakRef] = {}
var _hum_from: Dictionary[int, float] = {}
## Instance id -> when the player lost it (for folding a seizure into it).
var _lost_at: Dictionary[int, float] = {}
## Every machine heard of (instance ids), for BaseLoops.
var _known: Dictionary[int, bool] = {}
var _players: Array[AudioStreamPlayer3D] = []
var _owners: Array[int] = []
## Per slot: fading out (its machine no longer wants it).
var _fading: Array[bool] = []
var _levels: PackedFloat32Array = []
var _clock: float = 0.0


func _ready() -> void:
	for i: int in MachineCues.MAX_HUMS:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "EngineHum%d" % i
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 8.0
		player.volume_db = AudioMix.SILENT_DB
		add_child(player)
		_players.append(player)
		_owners.append(0)
		_fading.append(false)
	_levels.resize(MachineCues.MAX_HUMS)
	Events.machine_reactivated.connect(handle_reactivated)
	Events.machine_lost.connect(handle_lost)
	Events.mission_started.connect(handle_mission_started)


func _process(delta: float) -> void:
	advance(delta)


## Moves the clock and the hums by `delta` seconds (tests call this directly).
func advance(delta: float) -> void:
	_clock += maxf(delta, 0.0)
	var wanted: Array[int] = _wanted_hums()
	for i: int in _players.size():
		if _owners[i] != 0 and not wanted.has(_owners[i]):
			_fading[i] = true
	for id: int in wanted:
		var slot_of: int = _owners.find(id)
		if slot_of >= 0:
			_fading[slot_of] = false
			continue
		var slot: int = _free_slot()
		if slot >= 0:
			_start_hum(slot, id)
	for i: int in _players.size():
		_step_hum(i, delta)


## `machine` came alive for `faction`. Returns the one-shot played (or &"").
func handle_reactivated(machine: Node3D, faction: int) -> StringName:
	if machine == null or not is_instance_valid(machine):
		return &""
	var id: int = machine.get_instance_id()
	_known[id] = true
	var at: Vector3 = _position_of(machine)
	if faction == player_faction:
		_running[id] = weakref(machine)
		_hum_from[id] = _clock + MachineCues.RUN_DELAY
	else:
		_running.erase(id)
	var seen: bool = not CombatCues.is_hidden(machine) and MachineCues.in_view(at, focus)
	var event: StringName = MachineCues.reactivated_event(faction, player_faction, seen)
	var lost_at: float = _lost_at.get(id, -INF)
	if event == MachineCues.SEIZED and MachineCues.folds(_clock, lost_at):
		return &""
	return _play(event, at)


## `machine` stopped working for `faction`. Returns the one-shot played (or &"").
func handle_lost(machine: Node3D, faction: int) -> StringName:
	if machine == null or not is_instance_valid(machine):
		return &""
	var id: int = machine.get_instance_id()
	_known[id] = true
	if faction != player_faction:
		return &""
	_running.erase(id)
	_hum_from.erase(id)
	_lost_at[id] = _clock
	return _play(MachineCues.lost_event(faction, player_faction), _position_of(machine))


func handle_mission_started() -> void:
	_running.clear()
	_hum_from.clear()
	_lost_at.clear()
	_known.clear()
	for i: int in _players.size():
		_players[i].stop()
		_players[i].volume_db = AudioMix.SILENT_DB
		_owners[i] = 0
		_fading[i] = false
		_levels[i] = 0.0


## True for a machine this node has heard of (BaseLoops leaves it alone).
func is_tracked(node: Node) -> bool:
	return node != null and _known.has(node.get_instance_id())


## Engines running for the player.
func running_count() -> int:
	return _running.size()


## Run loops sounding now.
func humming_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer3D in _players:
		if player.playing:
			count += 1
	return count


# --- Internals ----------------------------------------------------------------


func _play(event_id: StringName, at: Vector3) -> StringName:
	if event_id == &"":
		return &""
	if play_at.call(event_id, at):
		played.append(event_id)
		return event_id
	return &""


## The running machines that should hum now, nearest first.
func _wanted_hums() -> Array[int]:
	var candidates: Array[int] = []
	var distances: Array[float] = []
	for id: int in _running.keys():
		var machine: Node3D = _machine(id)
		if machine == null:
			_running.erase(id)
			_hum_from.erase(id)
			continue
		if _clock < _hum_from.get(id, 0.0):
			continue
		var at: Vector3 = _position_of(machine)
		if not MachineCues.in_view(at, focus, MachineCues.HUM_RADIUS):
			continue
		var distance: float = Vector2(at.x - focus.x, at.z - focus.z).length()
		var k: int = 0
		while k < distances.size() and distances[k] <= distance:
			k += 1
		candidates.insert(k, id)
		distances.insert(k, distance)
	return candidates.slice(0, MachineCues.MAX_HUMS)


func _free_slot() -> int:
	for i: int in _owners.size():
		if _owners[i] == 0:
			return i
	return -1


func _start_hum(slot: int, id: int) -> void:
	var event: SoundEvent = resolve_event.call(MachineCues.RUN)
	if event == null or event.streams.is_empty():
		return
	var player: AudioStreamPlayer3D = _players[slot]
	player.stream = event.streams[0]
	player.bus = event.bus
	player.max_distance = event.max_distance
	player.volume_db = AudioMix.SILENT_DB
	_owners[slot] = id
	_fading[slot] = false
	_levels[slot] = 0.0
	player.play(randf() * player.stream.get_length())


## Fades a slot toward its target; a fading-out slot frees itself when silent.
func _step_hum(slot: int, delta: float) -> void:
	var owner_id: int = _owners[slot]
	if owner_id == 0:
		return
	var player: AudioStreamPlayer3D = _players[slot]
	var target: float = 0.0 if _fading[slot] else 1.0
	_levels[slot] = move_toward(_levels[slot], target, maxf(delta, 0.0) / MachineCues.HUM_FADE)
	if not _fading[slot] and _running.has(owner_id):
		var machine: Node3D = _machine(owner_id)
		if machine != null:
			player.global_position = _position_of(machine)
		if not player.playing and player.stream != null:
			# Stopped from outside (Audio.stop_all_voices): the engine still runs.
			player.play(randf() * player.stream.get_length())
	var event: SoundEvent = resolve_event.call(MachineCues.RUN)
	var base_db: float = event.volume_db if event != null else 0.0
	player.volume_db = base_db + AudioMix.linear_to_db_safe(_levels[slot])
	if _fading[slot] and _levels[slot] <= 0.0:
		player.stop()
		_owners[slot] = 0
		_fading[slot] = false


## The running machine with instance id `id`, or null if it is gone.
func _machine(id: int) -> Node3D:
	var ref: Object = _running[id].get_ref()
	if ref == null or not is_instance_valid(ref):
		return null
	return ref as Node3D


static func _position_of(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position
