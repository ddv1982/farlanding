class_name HoldoutSound
extends Node
## The Holdout mission's survival timer -> sound (Phase 8b). Rules in
## HoldoutCues; this node gathers the inputs and plays.
##
## Survival timers are learnt from `Events.objective_added` and
## `objective_updated` (HoldoutCues.is_survival). On every
## `Events.sim_ticked(tick)` the soonest one sets the stage: the score's
## holdout layer (`set_music_gain`), the one-minute cue (flat, `play_first`),
## then the approaching engine on this node's own player (Music bus), its
## level and pitch following the seconds left. A restored mission that
## re-announces its objective mid-way enters the right stage at once (from
## the last ten seconds straight to the engine, without the minute cue).
##
## Help arrives on `advisor_alert` &"extraction_arrived" or when the survival
## objective completes, whichever is first: `mus_holdout_arrived` once, the
## engine fades, the layer goes. The objective failing (the site lost) stops
## everything without it. mission_started (and going aboard) resets.
##
## MissionSoundRouter ignores these timers on purpose: its storm cues are for
## deadlines that fail (`countdown_fails` true).

const MUSIC_BUS: StringName = &"Music"

## Plays the first existing event flat: `func(ids: Array[StringName], at: Vector3) -> StringName`.
var play_first: Callable = func(_ids: Array[StringName], _at: Vector3) -> StringName: return &""
## Looks up a SoundEvent: `func(id: StringName) -> SoundEvent`.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## Sets the score's holdout layer gain: `func(gain_db: float) -> void`.
var set_music_gain: Callable = func(_db: float) -> void: pass

## Objective id -> objective, for the survival timers the player knows about.
var _timers: Dictionary[StringName, RefCounted] = {}
var _stage: int = 0
var _arrived: bool = false
var _left: float = INF
var _engine: AudioStreamPlayer
## Engine level (linear 0..1) toward its target; its target dB from the timer.
var _engine_level: float = 0.0
var _engine_target: float = 0.0
var _engine_db: float = AudioMix.SILENT_DB
var _music_db: float = INF


func _ready() -> void:
	_engine = AudioStreamPlayer.new()
	_engine.name = &"Engine"
	_engine.bus = MUSIC_BUS
	_engine.volume_db = AudioMix.SILENT_DB
	add_child(_engine)
	Events.objective_added.connect(handle_objective)
	Events.objective_updated.connect(handle_objective)
	Events.objective_completed.connect(handle_objective_completed)
	Events.objective_failed.connect(handle_objective_failed)
	Events.sim_ticked.connect(handle_sim_ticked)
	Events.advisor_alert.connect(handle_advisor_alert)
	Events.mission_started.connect(handle_mission_started)
	_apply_music()


func _process(delta: float) -> void:
	advance(delta)


## Moves the engine's fades by `delta` seconds (tests call this directly).
func advance(delta: float) -> void:
	var rate: float = HoldoutCues.ENGINE_ATTACK
	if _engine_target < _engine_level:
		rate = HoldoutCues.ENGINE_RELEASE
	_engine_level = move_toward(_engine_level, _engine_target, delta / rate)
	if _engine.playing:
		_engine.volume_db = _engine_db + AudioMix.linear_to_db_safe(_engine_level)
		if _engine_level <= 0.0 and _engine_target <= 0.0:
			_engine.stop()


## An objective was announced or changed: a survival timer is followed.
func handle_objective(objective: RefCounted) -> void:
	var id: StringName = _id_of(objective)
	if id == &"":
		return
	if HoldoutCues.is_survival(objective):
		_timers[id] = objective
	else:
		_timers.erase(id)


func handle_objective_completed(objective: RefCounted) -> void:
	var id: StringName = _id_of(objective)
	if _timers.has(id):
		_timers.erase(id)
		arrive()


func handle_objective_failed(objective: RefCounted) -> void:
	var id: StringName = _id_of(objective)
	if not _timers.has(id):
		return
	_timers.erase(id)
	if _timers.is_empty():
		_stop(false)


func handle_advisor_alert(kind: StringName) -> void:
	if kind == HoldoutCues.ARRIVED_ALERT:
		arrive()


## Checks the soonest survival timer at sim tick `tick`. Returns the cue
## started (or &"").
func handle_sim_ticked(tick: int) -> StringName:
	if _arrived:
		return &""
	_left = seconds_left(tick)
	var stage: int = HoldoutCues.stage_for(_left)
	var cue: StringName = &""
	if stage > _stage:
		if stage == 2:
			cue = _play(HoldoutCues.MINUTE_CUE)
		elif stage == 3:
			cue = HoldoutCues.ENGINE if _start_engine() else &""
		_stage = stage
	if _stage >= 3:
		_engine_db = HoldoutCues.engine_db(_left)
		_engine.pitch_scale = HoldoutCues.engine_pitch(_left)
		advance(0.0)
	_apply_music()
	return cue


## Help is here: the resolution plays once (only if a holdout was under way).
## Returns true if it played.
func arrive() -> bool:
	if _arrived or _stage <= 0:
		return false
	_arrived = true
	_play(HoldoutCues.ARRIVED)
	_stop(true)
	return true


func handle_mission_started() -> void:
	_timers.clear()
	_stage = 0
	_arrived = false
	_left = INF
	_engine_target = 0.0
	_engine_level = 0.0
	_engine.stop()
	_engine.volume_db = AudioMix.SILENT_DB
	_apply_music()


## Seconds to the soonest survival timer at `tick`, or INF if there is none.
func seconds_left(tick: int) -> float:
	var soonest: float = INF
	for id: StringName in _timers.keys():
		var objective: RefCounted = _timers[id]
		if not HoldoutCues.is_survival(objective):
			continue
		var due: Variant = objective.get(&"countdown_tick")
		if due is int:
			var due_tick: int = due
			soonest = minf(soonest, maxf(float(due_tick - tick) / SimClock.TICK_RATE, 0.0))
	return soonest


func stage() -> int:
	return _stage


func has_arrived() -> bool:
	return _arrived


func engine_playing() -> bool:
	return _engine.playing


## The engine's current volume (dB) and pitch, for tests.
func engine_state() -> Array[float]:
	return [_engine.volume_db, _engine.pitch_scale]


# --- Internals ----------------------------------------------------------------


func _start_engine() -> bool:
	var event: SoundEvent = resolve_event.call(HoldoutCues.ENGINE)
	if event == null or event.streams.is_empty():
		return false
	_engine.stream = event.streams[0]
	_engine_level = 0.0
	_engine_target = 1.0
	_engine.volume_db = AudioMix.SILENT_DB
	_engine.play()
	return true


## Ends the holdout's sound: the engine fades (or stops), the layer goes.
func _stop(fade: bool) -> void:
	_engine_target = 0.0
	if not fade:
		_engine_level = 0.0
		_engine.stop()
	if not _arrived:
		_stage = 0
	_apply_music(true)


func _apply_music(silent: bool = false) -> void:
	var db: float = AudioMix.SILENT_DB
	if not silent and not _arrived:
		db = HoldoutCues.layer_gain_db(_stage)
	if db != _music_db:
		_music_db = db
		set_music_gain.call(db)


func _play(event_id: StringName) -> StringName:
	var ids: Array[StringName] = [event_id]
	var started: StringName = play_first.call(ids, Vector3.INF)
	return started


static func _id_of(objective: Object) -> StringName:
	if objective == null or not is_instance_valid(objective):
		return &""
	var value: Variant = objective.get(&"id")
	if value is StringName or value is String:
		return StringName(str(value))
	return &""
