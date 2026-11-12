## Autoload `Audio`: the only way sound gets played. Gameplay never calls this for
## its own events — `audio/` listens to `Events` and decides what is heard. The
## public surface below is a contract other systems rely on.
##
## Inside: every SoundEvent under `res://data/sounds/` is registered by id at
## startup. Flat (interface, replies, Advisor) and positional sounds each have a
## pool of players behind a VoiceBudget (priority stealing, per-event caps and
## cooldowns). An AudioListener3D sits above the camera's ground focus point;
## zoom moves it up and reshapes bus levels (AudioMix). Child nodes: the
## AudioEventRouter (Events -> sounds, Advisor alert queue), MovementLoops,
## BaseLoops (construction, production, mining, building hum) and the
## MusicDirector.
extends Node

const EVENTS_DIR: String = "res://data/sounds"
const DEFAULT_SCORE: String = "res://data/sounds/music/kessel_reach.tres"
const FLAT_VOICES: int = 16
const POSITIONAL_VOICES: int = 32
## Zoom changes smaller than this do not touch the bus volumes.
const ZOOM_EPSILON: float = 0.01

var _events: Dictionary[StringName, SoundEvent] = {}
var _last_variation: Dictionary[StringName, int] = {}
var _flat_budget: VoiceBudget = VoiceBudget.new(FLAT_VOICES)
var _positional_budget: VoiceBudget = VoiceBudget.new(POSITIONAL_VOICES)
var _flat_players: Array[AudioStreamPlayer] = []
var _positional_players: Array[AudioStreamPlayer3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _listener: AudioListener3D
var _listener_active: bool = false
var _focus: Vector3 = Vector3.ZERO
var _zoom: float = 0.5
var _applied_zoom: float = -1.0
var _router: AudioEventRouter
var _loops: MovementLoops
var _base_loops: BaseLoops
var _music: MusicDirector


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_events(EVENTS_DIR)
	_build_pools()
	_listener = AudioListener3D.new()
	_listener.name = &"Listener"
	add_child(_listener)
	_router = AudioEventRouter.new()
	_router.name = &"EventRouter"
	_router.play_first = play_first
	_router.event_seconds = func(event_id: StringName) -> float:
		var event: SoundEvent = get_event(event_id)
		return event.longest_seconds() if event != null else 0.0
	add_child(_router)
	_loops = MovementLoops.new()
	_loops.name = &"MovementLoops"
	_loops.resolve_event = get_event
	add_child(_loops)
	_base_loops = BaseLoops.new()
	_base_loops.name = &"BaseLoops"
	_base_loops.resolve_event = get_event
	add_child(_base_loops)
	_music = MusicDirector.new()
	_music.name = &"MusicDirector"
	add_child(_music)
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()
	if ResourceLoader.exists(DEFAULT_SCORE):
		var score: MusicScore = load(DEFAULT_SCORE)
		play_score(score)
	# Added last so it leaves the tree first (siblings exit in reverse order).
	var guard: ShutdownGuard = ShutdownGuard.new()
	guard.name = &"ShutdownGuard"
	guard.target = self
	add_child(guard)


## Plays a sound event by id. Leave `position` at Vector3.INF for non-positional
## sounds (interface, advisor).
func play(event_id: StringName, position: Vector3 = Vector3.INF) -> void:
	_start(event_id, position)


## Called by the camera every frame. `focus` is the ground point the camera looks
## at; `zoom` runs from 0 (closest) to 1 (furthest) and shapes the mix.
func set_listener_focus(focus: Vector3, zoom: float) -> void:
	_focus = focus
	_zoom = clampf(zoom, 0.0, 1.0)
	_listener.global_position = focus + Vector3.UP * AudioMix.listener_height(_zoom)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var yaw: float = camera.global_rotation.y if camera != null else 0.0
	_listener.global_basis = Basis(Vector3.UP, yaw)
	if not _listener_active:
		_listener.make_current()
		_listener_active = true
	_loops.focus = focus
	_base_loops.focus = focus
	if absf(_zoom - _applied_zoom) >= ZOOM_EPSILON:
		_apply_volumes()


## Requests a music state, e.g. &"explore", &"tension", &"combat".
func set_music_state(state: StringName) -> void:
	_music.set_state(state)


# --- Additions beyond the original contract -----------------------------------


## Starts a planet's score (and its ambience bed).
func play_score(score: MusicScore) -> void:
	var bed: AudioStream = null
	var ambience: SoundEvent = get_event(score.ambience)
	if ambience != null and not ambience.streams.is_empty():
		bed = ambience.streams[0]
	_music.play_score(score, bed)


func has_event(event_id: StringName) -> bool:
	return _events.has(event_id)


func get_event(event_id: StringName) -> SoundEvent:
	var event: SoundEvent = _events.get(event_id, null)
	return event


## Plays the first candidate that exists as an event; returns its id or &"".
func play_first(candidates: Array[StringName], position: Vector3 = Vector3.INF) -> StringName:
	for event_id: StringName in candidates:
		if _events.has(event_id):
			_start(event_id, position)
			return event_id
	return &""


## Voices in use (flat + positional), for the debug overlay and tests.
func active_voices() -> int:
	return _flat_budget.active_count() + _positional_budget.active_count()


# --- Internals ----------------------------------------------------------------


func _start(event_id: StringName, position: Vector3) -> bool:
	var event: SoundEvent = _events.get(event_id, null)
	if event == null or event.streams.is_empty():
		return false
	var positional: bool = event.positional and position.is_finite()
	if positional and _listener_active and event.max_distance > 0.0:
		if Vector2(position.x - _focus.x, position.z - _focus.z).length() > event.max_distance:
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
	var voice: int = (
		budget
		. request(
			event_id,
			event.priority,
			event.max_instances,
			event.cooldown,
			stream.get_length() / pitch,
			_now(),
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
		player3d.volume_db = event.volume_db
		player3d.pitch_scale = pitch
		player3d.max_distance = event.max_distance
		player3d.global_position = position
		player3d.play()
	else:
		var player: AudioStreamPlayer = _flat_players[voice]
		player.stop()
		player.stream = stream
		player.bus = event.bus
		player.volume_db = event.volume_db
		player.pitch_scale = pitch
		player.play()
	return true


func _register_events(dir_path: String) -> void:
	for entry: String in ResourceLoader.list_directory(dir_path):
		var path: String = dir_path.path_join(entry)
		if entry.ends_with("/"):
			_register_events(path.trim_suffix("/"))
			continue
		if not (entry.ends_with(".tres") or entry.ends_with(".res")):
			continue
		var event: SoundEvent = load(path) as SoundEvent
		if event == null:
			continue
		if event.id == &"" or _events.has(event.id):
			push_error("Audio: SoundEvent %s has an empty or duplicate id '%s'" % [path, event.id])
			continue
		_events[event.id] = event


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


func _apply_volumes() -> void:
	_applied_zoom = _zoom
	for i: int in AudioServer.bus_count:
		var bus: StringName = AudioServer.get_bus_name(i)
		var setting: float = 1.0
		if AudioMix.SETTING_FOR_BUS.has(bus):
			var value: Variant = Settings.get(AudioMix.SETTING_FOR_BUS[bus])
			if value is float:
				setting = value
		AudioServer.set_bus_volume_db(i, AudioMix.bus_volume_db(bus, setting, _zoom))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Leaves the tree before the players do. A player that leaves the tree only
## pauses its stream, and on quit the audio server shuts down before the mixer
## frees paused streams, which then show up as leaked. So: stop everything
## while still in the tree, and give the mix thread a moment to let go.
class ShutdownGuard:
	extends Node

	const GRACE_MSEC: int = 100

	var target: Node

	func _exit_tree() -> void:
		if target != null and _stop_all(target) > 0:
			OS.delay_msec(GRACE_MSEC)

	## Stops every player under `node` (a real stop, not the pause a player does
	## when it leaves the tree). Returns how many were playing.
	static func _stop_all(node: Node) -> int:
		var count: int = 0
		for child: Node in node.get_children():
			count += _stop_all(child)
			var flat: AudioStreamPlayer = child as AudioStreamPlayer
			if flat != null and flat.playing:
				flat.stop()
				count += 1
			var spatial: AudioStreamPlayer3D = child as AudioStreamPlayer3D
			if spatial != null and spatial.playing:
				spatial.stop()
				count += 1
		return count
