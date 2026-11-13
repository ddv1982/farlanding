class_name TideSound
extends Node
## The tide (Phase 8a, Thalassa Low's planet rule) -> sound. Listens to
## `Events.tide_turning`, `tide_changed` and `mission_started`; the rules live in
## TideCues.
##
## - tide_turning: the warning, `tide_turn_rising` or `tide_turn_falling` (flat,
##   Weather bus), so the player learns the two by ear.
## - tide_changed: the heard level follows the reported one (TideCues), and
##   every frame it sets the four loops on this node's own players (Weather bus:
##   the dark low-water bed and the bright high-water one crossfaded by level,
##   the rising rush and the falling pull by how fast the sea moves), the
##   score's tide layer (`set_music_gain`) and the planet ambience's water level
##   (`set_ambience_tide`).
## - The first report after a reset is where the sea already is: a restored
##   landing re-emits tide_changed and the tide fades in at that level (no jump
##   cut, no false rush). No report, no tide: other planets never hear it.
## - mission_started (and leaving for the ship: `handle_mission_started`):
##   everything stops and resets at once.
## Advisor phrases (tide_rising, tide_falling, units_in_water) arrive as
## `advisor_alert` kinds from gameplay and go through the AdvisorQueue.

const WEATHER_BUS: StringName = &"Weather"

## Looks up a SoundEvent: `func(id: StringName) -> SoundEvent`.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## Plays the first existing event flat: `func(ids: Array[StringName], at: Vector3) -> StringName`.
var play_first: Callable = func(_ids: Array[StringName], _at: Vector3) -> StringName: return &""
## Sets the score's tide layer gain: `func(gain_db: float) -> void`.
var set_music_gain: Callable = func(_db: float) -> void: pass
## Tells the planet ambience the water level: `func(level: float) -> void`.
var set_ambience_tide: Callable = func(_level: float) -> void: pass

var cues: TideCues = TideCues.new()

var _players: Dictionary[StringName, AudioStreamPlayer] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _music_db: float = INF
var _ambience_level: float = -1.0


func _ready() -> void:
	for layer: StringName in TideCues.LAYERS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Tide_%s" % layer
		player.bus = WEATHER_BUS
		player.volume_db = AudioMix.SILENT_DB
		add_child(player)
		_players[layer] = player
	Events.tide_turning.connect(handle_tide_turning)
	Events.tide_changed.connect(handle_tide_changed)
	Events.mission_started.connect(handle_mission_started)
	_apply()


func _process(delta: float) -> void:
	advance(delta)


## Advances the tide by `delta` seconds (tests call this directly).
func advance(delta: float) -> void:
	cues.step(delta)
	_apply()


## The warning before the tide turns. Returns the cue played, or &"".
func handle_tide_turning(_seconds: float, rising: bool) -> StringName:
	var ids: Array[StringName] = [TideCues.turn_cue(rising)]
	var started: StringName = play_first.call(ids, Vector3.INF)
	return started


func handle_tide_changed(level: float) -> void:
	cues.report(level)


func handle_mission_started() -> void:
	cues.reset()
	for player: AudioStreamPlayer in _players.values():
		player.stop()
		player.volume_db = AudioMix.SILENT_DB
	_apply()


## The heard water level (after smoothing), for the mix and tests.
func level() -> float:
	return cues.level


## Current volume of a layer's player (dB), for tests.
func layer_volume_db(layer: StringName) -> float:
	var player: AudioStreamPlayer = _players.get(layer, null)
	return player.volume_db if player != null else AudioMix.SILENT_DB


func layer_playing(layer: StringName) -> bool:
	var player: AudioStreamPlayer = _players.get(layer, null)
	return player != null and player.playing


## Seeds the loop start offsets (tests).
func seed_rng(value: int) -> void:
	_rng.seed = value


func _apply() -> void:
	for layer: StringName in TideCues.LAYERS:
		_set_layer(layer, TideCues.layer_db(layer, cues.level, cues.speed, cues.presence))
	var music: float = AudioMix.SILENT_DB
	if cues.primed:
		music = TideCues.music_gain_db(cues.level)
	if music != _music_db:
		_music_db = music
		set_music_gain.call(music)
	var water: float = cues.level if cues.primed else 0.0
	if absf(water - _ambience_level) >= 0.005:
		_ambience_level = water
		set_ambience_tide.call(water)


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
		var event: SoundEvent = resolve_event.call(TideCues.LAYER_EVENTS[layer])
		if event == null or event.streams.is_empty():
			return
		player.stream = event.streams[0]
		# Start each loop somewhere else: two tides never line up.
		player.play(_rng.randf() * maxf(player.stream.get_length() - 1.0, 0.0))
	player.volume_db = volume_db
