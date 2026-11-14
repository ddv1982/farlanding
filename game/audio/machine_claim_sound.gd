class_name MachineClaimSound
extends Node
## Work in progress at Hollow Meridian's old engines (Phase 9): while the
## player's workers bring an engine back, `loop_engine_claim` (a ratchet over a
## faint D+A drone) runs at it, its pitch rising with the work done, so the
## ticks quicken and the tone climbs until the spin-up (MachineSound) takes over.
##
## It depends on no gameplay class: every SCAN_SECONDS it looks through group
## `buildings` for a node whose `machine` property is an object with a
## `progress_changed(progress: float, claimant: int)` signal (the sim's Machine
## component) and listens to it. A claim is heard while its claimant is the
## player's faction, the work is between 0 and 1, the work last moved forward
## within IDLE_SECONDS (workers stopped or driven off and the progress decaying:
## it fades) and the engine is within RANGE of
## the camera's focus; at most MAX_VOICES, nearest first, on this node's own
## positional players (Buildings bus). An enemy claim is not heard: the
## enemy's seizure (MachineSound) is its news. `mission_started` and going
## aboard reset it.

const BUILDINGS_GROUP: StringName = &"buildings"
const MACHINE_PROPERTY: StringName = &"machine"
const PROGRESS_SIGNAL: StringName = &"progress_changed"
const EVENT: StringName = &"loop_engine_claim"
const BUS: StringName = &"Buildings"
const SCAN_SECONDS: float = 1.0
const MAX_VOICES: int = 2
const RANGE: float = 60.0
const IDLE_SECONDS: float = 0.6
## Pitch at no work done .. at the last moment before the spin-up.
const PITCH_FROM: float = 0.8
const PITCH_TO: float = 1.3
## Level change per second (fade in and out).
const FADE_RATE: float = 4.0

## Looks up a SoundEvent: `func(id: StringName) -> SoundEvent`.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## The camera's ground focus (set by the AudioService).
var focus: Vector3 = Vector3.ZERO
var player_faction: int = 0

## Building instance id -> its node (weak), last progress, claimant, and when
## that news came (this node's clock).
var _buildings: Dictionary[int, WeakRef] = {}
var _progress: Dictionary[int, float] = {}
var _claimant: Dictionary[int, int] = {}
var _news_at: Dictionary[int, float] = {}
## Machines already listened to (instance ids).
var _listening: Dictionary[int, bool] = {}
var _players: Array[AudioStreamPlayer3D] = []
var _owners: Array[int] = []
var _levels: PackedFloat32Array = []
var _clock: float = 0.0
var _scan_in: float = 0.0


func _ready() -> void:
	for i: int in MAX_VOICES:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "Claim%d" % i
		player.bus = BUS
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 10.0
		player.max_distance = RANGE + 20.0
		add_child(player)
		_players.append(player)
		_owners.append(0)
		_levels.append(0.0)
	Events.mission_started.connect(handle_mission_started)
	Events.campaign_screen_changed.connect(
		func(screen: StringName) -> void:
			if screen != &"":
				handle_mission_started()
	)


func _process(delta: float) -> void:
	advance(delta)


## The pitch of the claim loop at `progress` (0..1).
static func pitch_for(progress: float) -> float:
	return lerpf(PITCH_FROM, PITCH_TO, clampf(progress, 0.0, 1.0))


## Steps the clock: rescans now and then, picks the claims to hear, fades.
func advance(delta: float) -> void:
	_clock += delta
	_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = SCAN_SECONDS
		scan()
	var wanted: Array[int] = _wanted()
	for slot: int in MAX_VOICES:
		if _owners[slot] != 0 and not wanted.has(_owners[slot]) and _levels[slot] <= 0.0:
			_players[slot].stop()
			_owners[slot] = 0
	for id: int in wanted:
		if _owners.has(id):
			continue
		var free: int = _owners.find(0)
		if free >= 0:
			_start(free, id)
	for slot: int in MAX_VOICES:
		_step(slot, wanted.has(_owners[slot]), delta)


## Listens to every machine in group `buildings` it has not met yet.
func scan() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(BUILDINGS_GROUP):
		var building: Node3D = node as Node3D
		if building == null:
			continue
		var value: Variant = building.get(MACHINE_PROPERTY)
		if not (value is Object):
			continue
		var machine: Object = value
		if machine == null or not machine.has_signal(PROGRESS_SIGNAL):
			continue
		var key: int = machine.get_instance_id()
		if _listening.has(key):
			continue
		_listening[key] = true
		machine.connect(PROGRESS_SIGNAL, handle_progress.bind(building))


## Work on `building`'s machine moved (the Machine's `progress_changed`).
func handle_progress(progress: float, claimant: int, building: Node3D) -> void:
	if not is_instance_valid(building):
		return
	var id: int = building.get_instance_id()
	# Only work moving forward is news: the sim also reports the progress
	# decaying once the workers leave, and that should let the claim fade.
	var rising: bool = progress > _progress.get(id, 0.0) or _claimant.get(id, -1) != claimant
	_buildings[id] = weakref(building)
	_progress[id] = progress
	_claimant[id] = claimant
	if rising:
		_news_at[id] = _clock
	elif not _news_at.has(id):
		_news_at[id] = -INF


func handle_mission_started() -> void:
	_buildings.clear()
	_progress.clear()
	_claimant.clear()
	_news_at.clear()
	for slot: int in _players.size():
		_players[slot].stop()
		_owners[slot] = 0
		_levels[slot] = 0.0


## Claims heard now (players sounding).
func active_count() -> int:
	var count: int = 0
	for slot: int in _players.size():
		if _owners[slot] != 0 and _players[slot].playing:
			count += 1
	return count


## The pitch the loop plays at for `building` now (0 if it is not heard).
func pitch_of(building: Node3D) -> float:
	var slot: int = _owners.find(building.get_instance_id())
	return _players[slot].pitch_scale if slot >= 0 else 0.0


func _wanted() -> Array[int]:
	var ids: Array[int] = []
	var distances: Array[float] = []
	for id: int in _buildings:
		var building: Node3D = _building(id)
		if building == null or not building.is_inside_tree():
			continue
		if _claimant[id] != player_faction or _clock - _news_at[id] > IDLE_SECONDS:
			continue
		var progress: float = _progress[id]
		if progress <= 0.0 or progress >= 1.0:
			continue
		var at: Vector3 = building.global_position
		var distance: float = Vector2(at.x - focus.x, at.z - focus.z).length()
		if distance > RANGE:
			continue
		var k: int = 0
		while k < distances.size() and distances[k] <= distance:
			k += 1
		ids.insert(k, id)
		distances.insert(k, distance)
	return ids.slice(0, MAX_VOICES)


func _building(id: int) -> Node3D:
	var ref: WeakRef = _buildings.get(id, null)
	if ref == null:
		return null
	var node: Object = ref.get_ref()
	return node as Node3D


func _start(slot: int, id: int) -> void:
	var event: SoundEvent = resolve_event.call(EVENT)
	if event == null or event.streams.is_empty():
		return
	var player: AudioStreamPlayer3D = _players[slot]
	player.stream = event.streams[0]
	_owners[slot] = id
	_levels[slot] = 0.0
	player.volume_db = AudioMix.SILENT_DB
	player.play()


func _step(slot: int, wanted: bool, delta: float) -> void:
	var id: int = _owners[slot]
	if id == 0:
		return
	var player: AudioStreamPlayer3D = _players[slot]
	if wanted and not player.playing and player.stream != null:
		player.play()  # stopped from outside (Audio.stop_all_voices) while still wanted
	var target: float = 1.0 if wanted else 0.0
	_levels[slot] = move_toward(_levels[slot], target, FADE_RATE * delta)
	var building: Node3D = _building(id)
	if building != null and building.is_inside_tree():
		player.global_position = building.global_position
	var progress: float = _progress.get(id, 0.0)
	player.pitch_scale = pitch_for(progress)
	var event: SoundEvent = resolve_event.call(EVENT)
	var base_db: float = event.volume_db if event != null else 0.0
	player.volume_db = base_db + AudioMix.linear_to_db_safe(_levels[slot])
