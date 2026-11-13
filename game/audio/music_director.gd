class_name MusicDirector
extends Node
## Plays a MusicScore: builds an AudioStreamInteractive whose clips are
## AudioStreamSynchronized layer stacks, switches clips on the bar, and fades
## layers through a MusicBlender. Also plays the score's ambience bed.
##
## Layer gains (by layer name, e.g. &"trail") are added to every state's level
## for that layer, so game progress can shape a layer without new states: the
## trail layer surfaces as the player resolves discovery sites. A state that
## silences a layer keeps it silent whatever its gain.
##
## On the beat: with a score `bpm` and `quantize_beats`, new layer targets wait
## for the next boundary of that many beats (counted from when the score
## started), and a state's own `fade_seconds` sets how fast they move, so a
## layer that joins (the stealth pulse, the alarm's drums) arrives in time.
##
## Beds: `play_bed` loops a separate stream (the briefing or debrief bed) on
## the Music bus and dips the score under it; `stop_bed` fades it out and
## brings the score back.
##
## Variants (Phase 6): layers that share a `layer_groups` name take turns, one
## per loop (`loop_beats`), picked at random without repeating the last; the
## others in the group are silent. The change lands on the loop boundary.
## `at_next_beat` runs an action on the next beat of the grid (transition
## hits); `dip_for` lowers the score briefly under a sting.
##
## Switching scores (Phase 7): `switch_score` fades the playing score out on
## the one player, then starts the new one and fades it in, so the ship theme
## and a planet score never sound together. State requests that arrive during
## the fade are for the incoming score. Switching back to the playing score
## before the fade ends cancels the switch. A hold dip keeps the score lowered
## (no bed) until a bed or `stop_bed` changes it: the landing hand-over.

const MUSIC_BUS: StringName = &"Music"
const AMBIENCE_BUS: StringName = &"Ambience"
const AMBIENCE_FADE_IN: float = 4.0
const BED_FADE_IN: float = 2.0
const BED_FADE_OUT: float = 1.5
## How fast the score dips under a bed and comes back (dB per second).
const DIP_DB_PER_SECOND: float = 10.0
## Score switch: the old score fades out over SWAP_FADE_OUT, the new one fades
## in over SWAP_FADE_IN. A score that has played less than SWAP_CUT_BELOW is
## replaced at once (nothing worth fading yet, e.g. at boot).
const SWAP_FADE_OUT: float = 1.5
const SWAP_FADE_IN: float = 2.0
const SWAP_CUT_BELOW: float = 1.0

var score: MusicScore
## A score younger than this is cut rather than faded (tests set 0).
var swap_cut_below: float = SWAP_CUT_BELOW

var _blender: MusicBlender = MusicBlender.new()
var _player: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _bed: AudioStreamPlayer
var _interactive: AudioStreamInteractive
var _clips: Array[AudioStreamSynchronized] = []
var _clip: int = -1
var _layer_gains: Dictionary[StringName, float] = {}
var _started_at: float = 0.0
var _pending_targets: PackedFloat32Array = []
var _pending_fade: float = 0.0
var _apply_at: float = INF
## Bed level (linear 0..1) and the score's dip under it (dB), each with a target.
var _bed_level: float = 0.0
var _bed_target: float = 0.0
var _score_dip_db: float = 0.0
var _score_dip_target_db: float = 0.0
## Variant group -> layer index (in the playing clip) that sounds this loop.
var _variant: Dictionary[StringName, int] = {}
var _next_variant_change: float = INF
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Actions waiting for a beat: [[time, Callable], ...].
var _on_beat: Array = []
var _sting_dip_db: float = 0.0
var _sting_dip_until: float = -INF
## Score switch: the score (and its state) waiting for the fade-out, and the
## playing score's switch level (linear 0..1).
var _next_score: MusicScore = null
var _next_state: StringName = &""
var _swap_level: float = 1.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = &"Music"
	_player.bus = MUSIC_BUS
	add_child(_player)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = &"Ambience"
	_ambience.bus = AMBIENCE_BUS
	add_child(_ambience)
	_bed = AudioStreamPlayer.new()
	_bed.name = &"Bed"
	_bed.bus = MUSIC_BUS
	_bed.volume_db = AudioMix.SILENT_DB
	add_child(_bed)


func _process(delta: float) -> void:
	_step_swap(delta)
	_step_bed(delta)
	if _clip < 0:
		return
	var now: float = _now()
	_run_beat_actions(now)
	if now >= _next_variant_change:
		rotate_variants()
	var due: StringName = _blender.poll(now)
	if due != &"":
		_apply(due)
	if now >= _apply_at:
		_apply_at = INF
		_blender.fade_seconds = _pending_fade
		_blender.set_targets(_pending_targets)
	var volumes: PackedFloat32Array = _blender.step(delta)
	var layers: AudioStreamSynchronized = _clips[_clip]
	for i: int in mini(volumes.size(), layers.stream_count):
		layers.set_sync_stream_volume(i, volumes[i])


## Starts `new_score` in its default state, or `start_state` if given (and
## its ambience bed, if given). Cuts whatever played; see `switch_score`.
func play_score(
	new_score: MusicScore, ambience: AudioStream = null, start_state: StringName = &""
) -> void:
	score = new_score
	_next_score = null
	_next_state = &""
	_blender = MusicBlender.new()
	_blender.min_hold = score.min_hold
	_blender.fade_seconds = score.layer_fade
	_build_stream()
	_player.stream = _interactive
	var first: StringName = score.default_state
	if start_state != &"" and score.find_state(start_state) != null:
		first = start_state
	var start: MusicState = score.find_state(first)
	if start != null:
		_interactive.initial_clip = maxi(score.clip_index(start.clip), 0)
	_clip = _interactive.initial_clip
	_started_at = _now()
	_pick_variants(true)
	_blender.request(first, 0 if start == null else start.intensity, _now())
	_apply(first, true)
	_blender.snap()
	_process(0.0)
	_player.play()
	_schedule_variant_change()
	if ambience != null:
		_ambience.stream = ambience
		_ambience.volume_db = AudioMix.SILENT_DB
		_ambience.play()
		create_tween().tween_property(_ambience, ^"volume_db", 0.0, AMBIENCE_FADE_IN)


## Fades the playing score out and `new_score` in (in `state`, or its
## default). Nothing plays: it starts at once. The same score: only the state.
## A negative `hold_dip_db` keeps the score lowered that far without a bed
## until a bed starts or `stop_bed` lets it back (the landing hand-over).
func switch_score(new_score: MusicScore, state: StringName = &"", hold_dip_db: float = 0.0) -> void:
	if new_score == null:
		return
	if hold_dip_db < 0.0:
		_score_dip_target_db = hold_dip_db
	if new_score == score and _clip >= 0:
		_next_score = null  # cancels a switch away that has not happened yet
		_next_state = &""
		if state != &"":
			set_state(state)
		return
	if _clip < 0 or not _player.playing or _now() - _started_at < swap_cut_below:
		if _clip < 0 or not _player.playing:
			_swap_level = 1.0
		play_score(new_score, null, state)
		return
	_next_score = new_score
	_next_state = state


## The score playing now, or the one a switch is fading to (a switch is
## under way while this differs from `score`).
func target_score() -> MusicScore:
	return _next_score if _next_score != null else score


## Requests a state by name; unknown states are ignored. During a score switch
## the request is for the incoming score.
func set_state(state_name: StringName) -> void:
	if _next_score != null:
		if _next_score.find_state(state_name) != null:
			_next_state = state_name
		return
	if score == null:
		return
	var state: MusicState = score.find_state(state_name)
	if state == null:
		return
	if _blender.request(state_name, state.intensity, _now()):
		_apply(state_name)


## Switches to `state_name` at once, without waiting for the hold time or the beat.
func force_state(state_name: StringName) -> void:
	if _next_score != null:
		set_state(state_name)
		return
	if score == null:
		return
	var state: MusicState = score.find_state(state_name)
	if state == null:
		return
	_blender.force(state_name, state.intensity, _now())
	_apply(state_name, true)


func current_state() -> StringName:
	return _blender.current_state


## Adds `gain_db` to layer `layer_name` in every state (AudioMix.SILENT_DB
## silences it). Fades like a state change.
func set_layer_gain(layer_name: StringName, gain_db: float) -> void:
	var current: float = _layer_gains.get(layer_name, 0.0)
	if _layer_gains.has(layer_name) and is_equal_approx(current, gain_db):
		return
	_layer_gains[layer_name] = gain_db
	if score != null and _clip >= 0 and _blender.current_state != &"":
		_apply(_blender.current_state)


func layer_gain_db(layer_name: StringName) -> float:
	return _layer_gains.get(layer_name, 0.0)


## Picks the next variant of every group (at a loop boundary) and applies it.
func rotate_variants() -> void:
	_pick_variants(false)
	_schedule_variant_change()
	if score != null and _clip >= 0 and _blender.current_state != &"":
		_apply(_blender.current_state, true)


## Layer index sounding in variant group `group` (-1 if none), for tests.
func variant_of(group: StringName) -> int:
	return _variant.get(group, -1)


## Runs `action` on the next beat of the score's grid (at once without a grid).
func at_next_beat(action: Callable) -> void:
	var now: float = _now()
	var when: float = now
	if score != null and score.bpm > 0.0:
		when = next_boundary(now, _started_at, score.bpm, 1.0)
	_on_beat.append([when, action])
	_run_beat_actions(now)


## Lowers the score by `dip_db` for `seconds` (a sting over it), then lets it back.
func dip_for(seconds: float, dip_db: float) -> void:
	_sting_dip_until = maxf(_sting_dip_until, _now() + seconds)
	_sting_dip_db = minf(dip_db, 0.0)


## Picks a variant index among `count` layers, never `last` twice in a row. Pure.
static func pick_variant(count: int, last: int, roll: float) -> int:
	return SoundEvent.pick_index(count, last, roll, true)


## Target volumes (dB) of the playing clip's layers, for tests and debugging.
func layer_targets_db(state_name: StringName) -> PackedFloat32Array:
	var state: MusicState = score.find_state(state_name) if score != null else null
	if state == null:
		return PackedFloat32Array()
	return _state_volumes(state, score.clips[maxi(score.clip_index(state.clip), 0)])


## Seconds until the pending layer change lands (INF if none waits).
func seconds_to_pending_change() -> float:
	return _apply_at - _now() if _apply_at != INF else INF


func stop() -> void:
	_next_score = null
	_player.stop()
	_ambience.stop()
	_bed.stop()
	_bed_level = 0.0
	_bed_target = 0.0
	_clip = -1


## Loops `stream` on the Music bus, fading in, and dips the score by `duck_db`.
## The same stream already playing is left alone.
func play_bed(stream: AudioStream, duck_db: float) -> void:
	if stream == null:
		return
	if _bed.stream != stream or not _bed.playing:
		_bed.stream = stream
		_bed_level = 0.0
		_bed.volume_db = AudioMix.SILENT_DB
		_bed.play()
	_bed_target = 1.0
	_score_dip_target_db = minf(duck_db, 0.0)


## Fades the bed out and brings the score back.
func stop_bed() -> void:
	_bed_target = 0.0
	_score_dip_target_db = 0.0


func bed_stream() -> AudioStream:
	return _bed.stream if _bed.playing else null


func bed_level() -> float:
	return _bed_level


func score_dip_db() -> float:
	return _score_dip_db


## The next time at or after `now` that falls on a boundary of `beats` beats
## of a grid that started at `started` with tempo `bpm`. Pure.
static func next_boundary(now: float, started: float, bpm: float, beats: float) -> float:
	if bpm <= 0.0 or beats <= 0.0:
		return now
	var span: float = beats * 60.0 / bpm
	var elapsed: float = maxf(now - started, 0.0)
	var count: float = ceilf(elapsed / span - 0.0001)
	return started + count * span


func _apply(state_name: StringName, immediate: bool = false) -> void:
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
	var fade: float = state.fade_seconds if state.fade_seconds > 0.0 else score.layer_fade
	var targets: PackedFloat32Array = _state_volumes(state, score.clips[index])
	if immediate or score.bpm <= 0.0 or score.quantize_beats <= 0.0:
		_apply_at = INF
		_blender.fade_seconds = fade
		_blender.set_targets(targets)
		return
	_pending_targets = targets
	_pending_fade = fade
	_apply_at = next_boundary(_now(), _started_at, score.bpm, score.quantize_beats)


func _state_volumes(state: MusicState, clip: MusicClip) -> PackedFloat32Array:
	var volumes: PackedFloat32Array = []
	volumes.resize(clip.layers.size())
	for i: int in volumes.size():
		var level: float = state.layer_volumes_db[i] if i < state.layer_volumes_db.size() else 0.0
		if i < clip.layer_names.size() and level > AudioMix.SILENT_DB:
			var gain: float = _layer_gains.get(StringName(clip.layer_names[i]), 0.0)
			level = AudioMix.SILENT_DB if gain <= AudioMix.SILENT_DB else level + gain
		var group: StringName = _group_of(clip, i)
		if group != &"" and _variant.get(group, i) != i:
			level = AudioMix.SILENT_DB
		volumes[i] = level
	return volumes


static func _group_of(clip: MusicClip, index: int) -> StringName:
	if index < clip.layer_groups.size():
		return StringName(clip.layer_groups[index])
	return &""


func _pick_variants(first: bool) -> void:
	if score == null or _clip < 0:
		return
	var clip: MusicClip = score.clips[_clip]
	var members: Dictionary[StringName, Array] = {}
	for i: int in clip.layers.size():
		var group: StringName = _group_of(clip, i)
		if group != &"":
			if not members.has(group):
				members[group] = []
			members[group].append(i)
	for group: StringName in members:
		var layers: Array = members[group]
		var last: int = layers.find(_variant.get(group, -1))
		# The first loop of a score plays the original (first) layer of each group.
		var pick: int = 0 if first else pick_variant(layers.size(), last, _rng.randf())
		_variant[group] = layers[pick]


func _schedule_variant_change() -> void:
	_next_variant_change = INF
	if score == null or _clip < 0 or score.bpm <= 0.0:
		return
	var beats: int = score.clips[_clip].loop_beats
	if beats <= 0:
		return
	var now: float = _now()
	var span: float = beats * 60.0 / score.bpm
	_next_variant_change = next_boundary(now + 0.01, _started_at, score.bpm, float(beats))
	if _next_variant_change - now < 0.01:
		_next_variant_change += span


func _run_beat_actions(now: float) -> void:
	var waiting: Array = []
	for entry: Array in _on_beat:
		var when: float = entry[0]
		if now >= when:
			var action: Callable = entry[1]
			action.call()
		else:
			waiting.append(entry)
	_on_beat = waiting


func _step_swap(delta: float) -> void:
	if _next_score != null:
		_swap_level = move_toward(_swap_level, 0.0, delta / SWAP_FADE_OUT)
		if _swap_level <= 0.0:
			var incoming: MusicScore = _next_score
			var state: StringName = _next_state
			play_score(incoming, null, state)
	else:
		_swap_level = move_toward(_swap_level, 1.0, delta / SWAP_FADE_IN)


func _step_bed(delta: float) -> void:
	var rate: float = BED_FADE_IN if _bed_target > _bed_level else BED_FADE_OUT
	_bed_level = move_toward(_bed_level, _bed_target, delta / rate)
	var target: float = _score_dip_target_db
	if _now() < _sting_dip_until:
		target = minf(target, _sting_dip_db)
	_score_dip_db = move_toward(_score_dip_db, target, DIP_DB_PER_SECOND * delta)
	if _bed.playing:
		_bed.volume_db = AudioMix.linear_to_db_safe(_bed_level)
		if _bed_level <= 0.0 and _bed_target <= 0.0:
			_bed.stop()
	_player.volume_db = _score_dip_db + AudioMix.linear_to_db_safe(_swap_level)


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
