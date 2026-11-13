class_name StormSound
extends Node
## The dust storm (Phase 6, Kessel Reach's planet rule) -> sound. Listens to
## `Events.storm_incoming`, `storm_changed`, `mission_started` and
## `mission_ended`; the rules live in StormCues.
##
## - storm_incoming: the distant front (`storm_front_rumble`), once per warning.
## - storm_changed: the heard intensity follows the reported one smoothly
##   (StormCues.FOLLOW_RATE), and every frame it sets the three bed layers
##   (wind, grit, throb; looping on this node's own players on the Weather
##   bus), the world muffle (through `set_muffle`), the score's storm layer
##   (`set_music_gain`) and how much the planet ambience steps back
##   (`set_ambience_cover`). Gusts (flat, panned in the file) and debris
##   (positional, around the listener) are scheduled at random from the
##   intensity.
## - When a real storm clears, `storm_passed` plays (the release).
## - mission_ended: the storm freezes: if it is up it stays up and never
##   passes (Survey ends inside a storm that does not lift).
## - mission_started: everything resets at once.

const WEATHER_BUS: StringName = &"Weather"
## Debris lands this far from the listener focus (m).
const DEBRIS_RADIUS: Vector2 = Vector2(12.0, 38.0)

## Looks up a SoundEvent: `func(id: StringName) -> SoundEvent`.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## Plays the first existing event flat: `func(ids: Array[StringName], at: Vector3) -> StringName`.
var play_first: Callable = func(_ids: Array[StringName], _at: Vector3) -> StringName: return &""
## Plays a positional event: `func(id: StringName, at: Vector3, offset_db: float) -> bool`.
var play_at: Callable = func(_id: StringName, _at: Vector3, _db: float) -> bool: return false
## Applies the world muffle: `func(amount: float) -> void` (0 clear .. 1 full).
var set_muffle: Callable = func(_amount: float) -> void: pass
## Sets the score's storm layer gain: `func(gain_db: float) -> void`.
var set_music_gain: Callable = func(_db: float) -> void: pass
## How far the planet ambience should step back: `func(amount: float) -> void`.
var set_ambience_cover: Callable = func(_amount: float) -> void: pass
## Listener focus on the ground; set by the AudioService.
var focus: Vector3 = Vector3.ZERO

var cues: StormCues = StormCues.new()

var _players: Dictionary[StringName, AudioStreamPlayer] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_gust: float = INF
var _next_debris: float = INF
var _clock: float = 0.0
var _applied: float = -1.0


func _ready() -> void:
	for layer: StringName in StormCues.LAYERS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Storm_%s" % layer
		player.bus = WEATHER_BUS
		player.volume_db = AudioMix.SILENT_DB
		add_child(player)
		_players[layer] = player
	Events.storm_incoming.connect(_on_storm_incoming)
	Events.storm_changed.connect(handle_storm_changed)
	Events.mission_started.connect(handle_mission_started)
	Events.mission_ended.connect(_on_mission_ended)
	_apply(true)


func _process(delta: float) -> void:
	advance(delta)


## Advances the storm by `delta` seconds (tests call this directly). Returns
## the release cue if the storm passed on this step, else &"".
func advance(delta: float) -> StringName:
	_clock += delta
	var cue: StringName = cues.step(delta)
	if cue == StormCues.PASSED:
		_play(StormCues.PASSED)
	_apply(false)
	_schedule_one_shots()
	return cue


func handle_storm_incoming(_seconds: float) -> StringName:
	return _play(StormCues.FRONT_RUMBLE)


func handle_storm_changed(intensity: float) -> void:
	cues.report(intensity)


func handle_mission_started() -> void:
	cues.reset()
	_next_gust = INF
	_next_debris = INF
	for player: AudioStreamPlayer in _players.values():
		player.stop()
		player.volume_db = AudioMix.SILENT_DB
	_apply(true)


func handle_mission_ended(_won: bool) -> void:
	cues.freeze()


## The heard intensity (after smoothing), for the mix and tests.
func intensity() -> float:
	return cues.intensity


func is_final() -> bool:
	return cues.is_final()


## Current volume of a bed layer's player (dB), for tests.
func layer_volume_db(layer: StringName) -> float:
	var player: AudioStreamPlayer = _players.get(layer, null)
	return player.volume_db if player != null else AudioMix.SILENT_DB


func layer_playing(layer: StringName) -> bool:
	var player: AudioStreamPlayer = _players.get(layer, null)
	return player != null and player.playing


func _apply(force: bool) -> void:
	var value: float = cues.intensity
	if not force and absf(value - _applied) < 0.001:
		return
	_applied = value
	for layer: StringName in StormCues.LAYERS:
		_set_layer(layer, StormCues.layer_db(layer, value))
	var muffle: float = StormCues.muffle_amount(value)
	set_muffle.call(muffle)
	set_ambience_cover.call(clampf(value / 0.8, 0.0, 1.0))
	set_music_gain.call(StormCues.music_gain_db(value))


func _set_layer(layer: StringName, volume_db: float) -> void:
	var player: AudioStreamPlayer = _players.get(layer, null)
	if player == null:
		return
	if volume_db <= AudioMix.SILENT_DB:
		if player.playing:
			player.stop()
		player.volume_db = AudioMix.SILENT_DB
		return
	if not player.playing:
		var event: SoundEvent = resolve_event.call(StormCues.LAYER_EVENTS[layer])
		if event == null or event.streams.is_empty():
			return
		player.stream = event.streams[0]
		# Start each layer somewhere else in its loop: two storms never line up.
		player.play(_rng.randf() * maxf(player.stream.get_length() - 1.0, 0.0))
	player.volume_db = volume_db


func _schedule_one_shots() -> void:
	var value: float = cues.intensity
	if _next_gust == INF or _clock >= _next_gust:
		if _next_gust != INF and value >= StormCues.GUST_FROM:
			_play(StormCues.GUST)
		_next_gust = _clock + StormCues.gust_gap(value, _rng.randf())
	if _next_debris == INF or _clock >= _next_debris:
		if _next_debris != INF and value >= StormCues.DEBRIS_FROM:
			var angle: float = _rng.randf() * TAU
			var distance: float = _rng.randf_range(DEBRIS_RADIUS.x, DEBRIS_RADIUS.y)
			var at: Vector3 = focus + Vector3(cos(angle), 0.0, sin(angle)) * distance
			play_at.call(StormCues.DEBRIS, at, 0.0)
		_next_debris = _clock + StormCues.debris_gap(value, _rng.randf())


func _play(event_id: StringName) -> StringName:
	var ids: Array[StringName] = [event_id]
	var started: StringName = play_first.call(ids, Vector3.INF)
	return started


func _on_storm_incoming(seconds: float) -> void:
	handle_storm_incoming(seconds)


func _on_mission_ended(won: bool) -> void:
	handle_mission_ended(won)
