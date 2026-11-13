class_name CoreSound
extends Node
## The Beacon Core's finale -> sound (Phase 8d, Hollow Meridian). Listens to
## `Events.core_charge_changed`, `core_awakened` and `mission_started`; the rules
## live in CoreCues. It depends on nothing of gameplay but those signals.
##
## - Charge: the score's Core layers come in by threshold with hysteresis
##   (`set_music_gain(layer, gain_db)`, which the AudioService passes to the
##   MusicDirector: layer changes land on the beat and fade at the state's speed).
## - Awakened (once per mission): the Core layers go, `mus_core_awakened` plays
##   on this node's own player on the Music bus (so stopping the world's voices
##   never cuts the campaign's peak), and the score dips under it
##   (`dip_music(seconds, dip_db)`) until its calm tail. While it rings,
##   `is_peaking()` is true: the AudioService then leaves out the mission's
##   victory sting (the awakening is the victory).
## - mission_started: everything resets (the awakening stops).

const MUSIC_BUS: StringName = &"Music"

## Looks up a SoundEvent: `func(id: StringName) -> SoundEvent`.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## Sets a score layer's gain: `func(layer: StringName, gain_db: float) -> void`.
var set_music_gain: Callable = func(_layer: StringName, _db: float) -> void: pass
## Dips the score under the awakening: `func(seconds: float, dip_db: float) -> void`.
var dip_music: Callable = func(_seconds: float, _db: float) -> void: pass

var _level: int = 0
var _charge: float = 0.0
var _awakened: bool = false
var _player: AudioStreamPlayer
## Layer gains last sent (one per CoreCues.LAYERS entry), so repeats are skipped.
var _sent: PackedFloat32Array = []


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = &"Awakening"
	_player.bus = MUSIC_BUS
	add_child(_player)
	Events.core_charge_changed.connect(handle_charge_changed)
	Events.core_awakened.connect(handle_awakened)
	Events.mission_started.connect(handle_mission_started)
	_apply(true)


## The Core's charge changed (0..1). Returns the number of Core layers sounding.
func handle_charge_changed(fraction: float) -> int:
	if _awakened or is_nan(fraction):
		return _level
	_charge = clampf(fraction, 0.0, 1.0)
	_level = CoreCues.level_for(_charge, _level)
	_apply()
	return _level


## The Core is awake: the peak plays (once). Returns true if it started.
## `start_at` (seconds into the cue) is for measuring the peak in tests; the
## dip is shortened to match.
func handle_awakened(_core: Node3D = null, start_at: float = 0.0) -> bool:
	if _awakened:
		return false
	_awakened = true
	_level = 0
	_apply()
	var event: SoundEvent = resolve_event.call(CoreCues.AWAKENED)
	if event == null or event.streams.is_empty():
		return false
	_player.stream = event.streams[0]
	_player.volume_db = event.volume_db
	var from: float = clampf(start_at, 0.0, _player.stream.get_length())
	_player.play(from)
	var dip: float = CoreCues.dip_seconds(_player.stream.get_length()) - from
	if dip > 0.0:
		dip_music.call(dip, CoreCues.PEAK_DIP_DB)
	return true


func handle_mission_started() -> void:
	_awakened = false
	_level = 0
	_charge = 0.0
	if _player != null:
		_player.stop()
	_apply(true)


## True while the awakening rings.
func is_peaking() -> bool:
	return _player != null and _player.playing


func is_awakened() -> bool:
	return _awakened


## Core layers sounding now (0..3).
func level() -> int:
	return _level


func charge() -> float:
	return _charge


func _apply(force: bool = false) -> void:
	if _sent.size() != CoreCues.LAYERS.size():
		_sent.resize(CoreCues.LAYERS.size())
		force = true
	for i: int in CoreCues.LAYERS.size():
		var gain: float = CoreCues.layer_gain_db(i, _level)
		if force or not is_equal_approx(_sent[i], gain):
			_sent[i] = gain
			set_music_gain.call(CoreCues.LAYERS[i], gain)
