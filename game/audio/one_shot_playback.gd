class_name OneShotPlayback
extends Node
## Owns one-shot players, allocation, variation history and randomness.
## Audio supplies registered events and the listener's ground focus. Players stay
## below Audio so its last-added ShutdownGuard stops them before tree teardown.

const FLAT_VOICES: int = 16
const POSITIONAL_VOICES: int = 32

## Distance culling starts only once Audio has activated its listener.
var listener_active: bool = false
var focus: Vector3 = Vector3.ZERO
## Sampled at allocation, after variation and pitch draws, like Audio's clock.
var now: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var _last_variation: Dictionary[StringName, int] = {}
var _flat_budget: VoiceBudget = VoiceBudget.new(FLAT_VOICES)
var _positional_budget: VoiceBudget = VoiceBudget.new(POSITIONAL_VOICES)
var _flat_players: Array[AudioStreamPlayer] = []
var _positional_players: Array[AudioStreamPlayer3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_build_pools()


func start(
	event_id: StringName,
	event: SoundEvent,
	position: Vector3,
	volume_offset_db: float = 0.0,
) -> bool:
	if event == null or event.streams.is_empty():
		return false
	var positional: bool = event.positional and position.is_finite()
	if positional and listener_active and event.max_distance > 0.0:
		if Vector2(position.x - focus.x, position.z - focus.z).length() > event.max_distance:
			return false
	var last: int = _last_variation.get(event_id, -1)
	var index: int = SoundEvent.pick_index(
		event.streams.size(), last, _rng.randf(), event.avoid_repeat
	)
	var stream: AudioStream = event.streams[index]
	var pitch: float = 1.0
	if event.pitch_variation > 0.0:
		pitch = pow(2.0, _rng.randf_range(-event.pitch_variation, event.pitch_variation) / 12.0)
	var budget: VoiceBudget = _positional_budget if positional else _flat_budget
	var allocated_at: float = now.call()
	var voice: int = (
		budget
		. request(
			event_id,
			event.priority,
			event.max_instances,
			event.cooldown,
			stream.get_length() / pitch,
			allocated_at,
		)
	)
	if voice == VoiceBudget.REJECTED:
		return false
	_last_variation[event_id] = index
	if positional:
		var player3d: AudioStreamPlayer3D = _positional_players[voice]
		player3d.stop()
		player3d.stream = stream
		player3d.bus = event.bus
		player3d.volume_db = event.volume_db + volume_offset_db
		player3d.pitch_scale = pitch
		player3d.max_distance = event.max_distance
		player3d.global_position = position
		player3d.play()
	else:
		var player: AudioStreamPlayer = _flat_players[voice]
		player.stop()
		player.stream = stream
		player.bus = event.bus
		player.volume_db = event.volume_db + volume_offset_db
		player.pitch_scale = pitch
		player.play()
	return true


## Stops flat voices first, then the world's positional voices. Releasing a
## voice keeps its event's cooldown and variation history intact.
func stop_all() -> void:
	for i: int in _flat_players.size():
		_flat_players[i].stop()
		_flat_budget.release(i)
	stop_world()


func stop_world() -> void:
	for i: int in _positional_players.size():
		_positional_players[i].stop()
		_positional_budget.release(i)


func active_voices() -> int:
	return _flat_budget.active_count() + _positional_budget.active_count()


func _build_pools() -> void:
	for i: int in FLAT_VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Flat%d" % i
		player.finished.connect(_flat_budget.release.bind(i))
		add_child(player)
		_flat_players.append(player)
	for i: int in POSITIONAL_VOICES:
		var player3d: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player3d.name = "Positional%d" % i
		player3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player3d.unit_size = 10.0
		player3d.finished.connect(_positional_budget.release.bind(i))
		add_child(player3d)
		_positional_players.append(player3d)
