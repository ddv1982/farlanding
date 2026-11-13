class_name SuspicionTones
extends Node
## The tightening tone of a watcher noticing something (Phase 5).
##
## Watchers are learnt from `Events.suspicion_raised` and `intruder_spotted`
## (and any node in group &"watchers"). Every SCAN_INTERVAL each is read
## duck-typed: `suspicion` (0..1), `is_alerted`, `is_visible_to_player`. A
## watcher is eligible while it is visible to the player (missing = visible),
## not alerted (the alarm has taken over) and its suspicion is above
## StealthCues.MIN_SUSPICION. StealthCues.pick_tones keeps the best of them
## (highest suspicion, nearest; at most MAX_TONES and the event's
## `max_instances`, within its `max_distance`). Each chosen watcher carries a
## positional `stealth_suspicion` loop whose level and pitch follow its
## suspicion (StealthCues.tone_db / tone_pitch), smoothed, so the beat speeds up
## as it tightens. A watcher whose suspicion is back at zero is forgotten until
## it raises suspicion again. mission_started forgets everything.

const WATCHERS_GROUP: StringName = &"watchers"
const MAX_TONES: int = 2
const SCAN_INTERVAL: float = 0.1
const FADE_IN_SECONDS: float = 0.25
const FADE_OUT_SECONDS: float = 0.6
## How fast level and pitch follow suspicion (fraction of the gap per second).
const FOLLOW_RATE: float = 6.0

## Ground point the listener is centred on.
var focus: Vector3 = Vector3.ZERO
## Looks up a SoundEvent by id; set by the AudioService.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null

var _tracked: Dictionary[int, bool] = {}
var _chosen: Array[Node3D] = []
var _players: Array[AudioStreamPlayer3D] = []
var _owners: Array[Node3D] = []
var _levels: PackedFloat32Array = []
var _wanted: Array[bool] = []
var _suspicion: PackedFloat32Array = []
var _scan_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	for i: int in MAX_TONES:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "Tone%d" % i
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 10.0
		add_child(player)
		_players.append(player)
		_owners.append(null)
		_wanted.append(false)
	_levels.resize(MAX_TONES)
	_suspicion.resize(MAX_TONES)
	Events.suspicion_raised.connect(_on_watcher_event)
	Events.intruder_spotted.connect(_on_watcher_event)
	Events.mission_started.connect(reset)


func _process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		rescan()
	step(delta)


## Starts following `watcher` (normally learnt from the Events bus).
func track(watcher: Node3D) -> void:
	if is_instance_valid(watcher):
		_tracked[watcher.get_instance_id()] = true


func tracked_count() -> int:
	return _tracked.size()


## Watchers carrying a tone after the last scan, best first.
func chosen_watchers() -> Array[Node3D]:
	return _chosen.duplicate()


## Tones currently sounding (fading ones included).
func playing_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer3D in _players:
		if player.playing:
			count += 1
	return count


## Pitch scale of the tone on `watcher`, or 0 if it has none.
func tone_pitch_of(watcher: Node3D) -> float:
	var i: int = _owners.find(watcher)
	return _players[i].pitch_scale if i != -1 and _players[i].playing else 0.0


## Forgets every watcher and silences the tones (a new mission).
func reset() -> void:
	_tracked.clear()
	_chosen.clear()
	for i: int in _players.size():
		_players[i].stop()
		_owners[i] = null
		_wanted[i] = false
		_levels[i] = 0.0


func rescan() -> void:
	_chosen.clear()
	_learn_group()
	var event: SoundEvent = resolve_event.call(StealthCues.SUSPICION_LOOP)
	var nodes: Array[Node3D] = []
	var suspicions: PackedFloat32Array = []
	var distances: PackedFloat32Array = []
	var eligible: Array[bool] = []
	for key: int in _tracked.keys():
		var watcher: Node3D = instance_from_id(key) as Node3D
		if watcher == null or not watcher.is_inside_tree():
			_tracked.erase(key)
			continue
		var suspicion: float = StealthCues.suspicion_of(watcher)
		if suspicion <= 0.0:
			_tracked.erase(key)
			continue
		nodes.append(watcher)
		suspicions.append(suspicion)
		var at: Vector3 = watcher.global_position
		distances.append(Vector2(at.x - focus.x, at.z - focus.z).length())
		eligible.append(
			(
				StealthCues.flag(watcher, &"is_visible_to_player", true)
				and not StealthCues.flag(watcher, &"is_alerted", false)
			)
		)
	if event == null or event.streams.is_empty():
		_want([], null)
		return
	var cap: int = mini(MAX_TONES, maxi(event.max_instances, 1))
	var picked: PackedInt32Array = StealthCues.pick_tones(
		suspicions, distances, eligible, cap, event.max_distance
	)
	for i: int in picked:
		_chosen.append(nodes[i])
	_want(_chosen, event)


## Advances fades and makes level and pitch follow each watcher's suspicion.
func step(delta: float) -> void:
	var event: SoundEvent = resolve_event.call(StealthCues.SUSPICION_LOOP)
	var base_db: float = event.volume_db if event != null else 0.0
	var follow: float = clampf(delta * FOLLOW_RATE, 0.0, 1.0)
	for i: int in _players.size():
		var player: AudioStreamPlayer3D = _players[i]
		var owner_node: Node3D = _owners[i]
		var alive: bool = is_instance_valid(owner_node) and owner_node.is_inside_tree()
		if not alive:
			_wanted[i] = false
		var rate: float = FADE_IN_SECONDS if _wanted[i] else FADE_OUT_SECONDS
		_levels[i] = move_toward(_levels[i], 1.0 if _wanted[i] else 0.0, delta / rate)
		if _levels[i] <= 0.0:
			if player.playing:
				player.stop()
			_owners[i] = null
			continue
		if alive:
			player.global_position = owner_node.global_position
			_suspicion[i] = lerpf(_suspicion[i], StealthCues.suspicion_of(owner_node), follow)
		player.volume_db = (
			base_db + StealthCues.tone_db(_suspicion[i]) + AudioMix.linear_to_db_safe(_levels[i])
		)
		player.pitch_scale = StealthCues.tone_pitch(_suspicion[i])


func _want(targets: Array[Node3D], event: SoundEvent) -> void:
	for i: int in _players.size():
		_wanted[i] = is_instance_valid(_owners[i]) and _owners[i] in targets
	if event == null:
		return
	for target: Node3D in targets:
		if not _owners.has(target):
			_assign(target, event)


func _assign(target: Node3D, event: SoundEvent) -> void:
	var slot: int = -1
	for i: int in _players.size():
		if not _wanted[i] and _levels[i] <= 0.0:
			slot = i
			break
	if slot == -1:
		return
	var player: AudioStreamPlayer3D = _players[slot]
	var stream: AudioStream = event.streams[_rng.randi_range(0, event.streams.size() - 1)]
	player.stream = stream
	player.bus = event.bus
	player.max_distance = event.max_distance
	player.volume_db = AudioMix.SILENT_DB
	player.global_position = target.global_position
	_suspicion[slot] = StealthCues.suspicion_of(target)
	player.pitch_scale = StealthCues.tone_pitch(_suspicion[slot])
	player.play(_rng.randf() * maxf(stream.get_length() - 0.05, 0.0))
	_owners[slot] = target
	_wanted[slot] = true
	_levels[slot] = 0.0


func _learn_group() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(WATCHERS_GROUP):
		var watcher: Node3D = node as Node3D
		if watcher != null:
			_tracked[watcher.get_instance_id()] = true


func _on_watcher_event(watcher: Node3D, _target: Node3D) -> void:
	track(watcher)
