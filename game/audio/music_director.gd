class_name MusicDirector
extends Node
## Plays a MusicScore: builds an AudioStreamInteractive whose clips are
## AudioStreamSynchronized layer stacks, switches clips on the bar, and fades
## layers through a MusicBlender. Also plays the score's ambience bed.

const MUSIC_BUS: StringName = &"Music"
const AMBIENCE_BUS: StringName = &"Ambience"
const AMBIENCE_FADE_IN: float = 4.0

var score: MusicScore

var _blender: MusicBlender = MusicBlender.new()
var _player: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _interactive: AudioStreamInteractive
var _clips: Array[AudioStreamSynchronized] = []
var _clip: int = -1


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = &"Music"
	_player.bus = MUSIC_BUS
	add_child(_player)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = &"Ambience"
	_ambience.bus = AMBIENCE_BUS
	add_child(_ambience)


func _process(delta: float) -> void:
	if _clip < 0:
		return
	var due: StringName = _blender.poll(_now())
	if due != &"":
		_apply(due)
	var volumes: PackedFloat32Array = _blender.step(delta)
	var layers: AudioStreamSynchronized = _clips[_clip]
	for i: int in mini(volumes.size(), layers.stream_count):
		layers.set_sync_stream_volume(i, volumes[i])


## Starts `new_score` in its default state (and its ambience bed, if given).
func play_score(new_score: MusicScore, ambience: AudioStream = null) -> void:
	score = new_score
	_blender = MusicBlender.new()
	_blender.min_hold = score.min_hold
	_blender.fade_seconds = score.layer_fade
	_build_stream()
	_player.stream = _interactive
	var start: MusicState = score.find_state(score.default_state)
	if start != null:
		_interactive.initial_clip = maxi(score.clip_index(start.clip), 0)
	_clip = _interactive.initial_clip
	_blender.request(score.default_state, 0 if start == null else start.intensity, _now())
	_apply(score.default_state)
	_blender.snap()
	_process(0.0)
	_player.play()
	if ambience != null:
		_ambience.stream = ambience
		_ambience.volume_db = AudioMix.SILENT_DB
		_ambience.play()
		create_tween().tween_property(_ambience, ^"volume_db", 0.0, AMBIENCE_FADE_IN)


## Requests a state by name; unknown states are ignored.
func set_state(state_name: StringName) -> void:
	if score == null:
		return
	var state: MusicState = score.find_state(state_name)
	if state == null:
		return
	if _blender.request(state_name, state.intensity, _now()):
		_apply(state_name)


## Switches to `state_name` at once, without waiting for the hold time.
func force_state(state_name: StringName) -> void:
	if score == null:
		return
	var state: MusicState = score.find_state(state_name)
	if state == null:
		return
	_blender.force(state_name, state.intensity, _now())
	_apply(state_name)


func current_state() -> StringName:
	return _blender.current_state


func stop() -> void:
	_player.stop()
	_ambience.stop()
	_clip = -1


func _apply(state_name: StringName) -> void:
	var state: MusicState = score.find_state(state_name)
	if state == null:
		return
	var index: int = score.clip_index(state.clip)
	if index < 0:
		return
	if index != _clip and _player.playing:
		var playback: AudioStreamPlaybackInteractive = (
			_player.get_stream_playback() as AudioStreamPlaybackInteractive
		)
		if playback != null:
			playback.switch_to_clip(index)
	_clip = index
	var volumes: PackedFloat32Array = []
	volumes.resize(_clips[index].stream_count)
	for i: int in volumes.size():
		volumes[i] = state.layer_volumes_db[i] if i < state.layer_volumes_db.size() else 0.0
	_blender.set_targets(volumes)


func _build_stream() -> void:
	_interactive = AudioStreamInteractive.new()
	_clips.clear()
	_interactive.clip_count = score.clips.size()
	for i: int in score.clips.size():
		var clip: MusicClip = score.clips[i]
		var layers: AudioStreamSynchronized = AudioStreamSynchronized.new()
		layers.stream_count = clip.layers.size()
		for j: int in clip.layers.size():
			layers.set_sync_stream(j, clip.layers[j])
			layers.set_sync_stream_volume(j, AudioMix.SILENT_DB)
		_clips.append(layers)
		_interactive.set_clip_name(i, clip.name)
		_interactive.set_clip_stream(i, layers)
		_interactive.set_clip_auto_advance(i, AudioStreamInteractive.AUTO_ADVANCE_DISABLED)
	(
		_interactive
		. add_transition(
			AudioStreamInteractive.CLIP_ANY,
			AudioStreamInteractive.CLIP_ANY,
			AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR,
			AudioStreamInteractive.TRANSITION_TO_TIME_START,
			AudioStreamInteractive.FADE_CROSS,
			score.transition_beats,
		)
	)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
