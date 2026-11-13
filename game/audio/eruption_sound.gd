class_name EruptionSound
extends Node
## Emberfall's eruptions (Phase 8b, the planet rule) -> sound. Listens to
## `Events.eruption_warning`, `eruption` and `mission_started`; the rules live
## in EruptionCues. Everything plays on this node's own positional players on
## the Weather bus (the planet speaking, like the storm and the tide), so it
## controls their pitch, level and dullness while they sound.
##
## - eruption_warning(vent, seconds, radius): a build-up at the vent. Two loops
##   (a deep growl, a pressurised hiss) crossfade and rise in pitch, and knocks
##   come faster, all from the seconds left (EruptionCues), so the player can
##   tell by ear how long remains. A new warning fades in over
##   EruptionCues.ARRIVE; a repeated one for the same vent only moves its
##   deadline (no restart, no jump). A restored mission that re-emits the
##   warning with the seconds still left picks up at the same pitch.
## - A warning with negative or infinite `seconds` calls the eruption off (the
##   build-up stops); the sim sends that for the vent a Tap vented on purpose.
## - eruption(vent, radius): the vent's build-up stops and a blast plays there
##   (a crack, a boom, a long low tail), louder for a larger radius; a blast the
##   player can see ducks the mix briefly (`duck`).
## - Voices: at most EruptionCues.MAX_BUILDS build-ups and MAX_BLASTS blasts at
##   once; the nearest and largest win (EruptionCues.weight). Warnings that lose
##   their slot are still followed and come back (at their current pitch) when
##   a slot frees.
## - A vent whose `is_visible_to_player` is false (read every frame, missing =
##   visible) is quieter and duller, never silent.
## - The score's pressure layer (`set_music_gain`) follows the most pressing
##   warned vent within its radius plus EruptionCues.BASE_MARGIN of one of the
##   player's buildings (group `buildings`, faction `player_faction`), re-read
##   every BASE_SCAN seconds.
## - Time is the simulation's: once `Events.sim_ticked` arrives, the clock may
##   run at most one tick past the last tick heard, so a paused game holds the
##   build-up where it is and a faster game speeds it up. Without ticks (tests)
##   it runs on `advance`'s delta alone.
## - mission_started (and going aboard the ship): everything stops and resets.
## Advisor phrases (eruption_warning, eruption_damage, ...) arrive as
## `advisor_alert` kinds from gameplay and go through the AdvisorQueue.

const WEATHER_BUS: StringName = &"Weather"
const BUILDINGS_GROUP: StringName = &"buildings"
const BASE_SCAN: float = 1.0
const MAX_DISTANCE: float = 320.0

## Looks up a SoundEvent: `func(id: StringName) -> SoundEvent`.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## Ducks the mix for `hold` seconds: `func(hold: float) -> void`.
var duck: Callable = func(_hold: float) -> void: pass
## Sets the score's pressure layer gain: `func(gain_db: float) -> void`.
var set_music_gain: Callable = func(_db: float) -> void: pass
## Listener focus on the ground; set by the AudioService.
var focus: Vector3 = Vector3.ZERO
## Whose buildings are "the player's base".
var player_faction: int = 0
## Re-read the player's buildings every BASE_SCAN (tests may turn it off).
var auto_scan: bool = true
## Knocks played so far (tests count them).
var knocks: int = 0

## Vent instance id -> its warning.
var _warnings: Dictionary[int, Warning] = {}
## Per build slot: [low, high, knock] players, and the vent id holding it (0 = free).
var _slots: Array[Array] = []
var _slot_owner: Array[int] = []
var _blasts: Array[AudioStreamPlayer3D] = []
var _blast_weight: PackedFloat32Array = []
var _base: Array[Vector3] = []
var _clock: float = 0.0
## Sim-tick sync: whether ticks arrive, and the clock time of the last one.
var _ticking: bool = false
var _tick_offset: float = 0.0
var _tick_time: float = 0.0
var _next_scan: float = 0.0
var _last_duck: float = -INF
var _music_db: float = INF
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	for i: int in EruptionCues.MAX_BUILDS:
		var trio: Array[AudioStreamPlayer3D] = []
		for part: String in ["low", "high", "knock"]:
			trio.append(_make_player("Build%d_%s" % [i, part]))
		_slots.append(trio)
		_slot_owner.append(0)
	for i: int in EruptionCues.MAX_BLASTS:
		_blasts.append(_make_player("Blast%d" % i))
		_blast_weight.append(0.0)
	Events.eruption_warning.connect(handle_eruption_warning)
	Events.eruption.connect(handle_eruption)
	Events.sim_ticked.connect(handle_sim_ticked)
	Events.mission_started.connect(handle_mission_started)
	_apply_music()


func _process(delta: float) -> void:
	advance(delta)


## Advances by `delta` seconds (tests call this directly).
func advance(delta: float) -> void:
	_clock += maxf(delta, 0.0)
	if _ticking:
		_clock = minf(_clock, _tick_time + 1.0 / SimClock.TICK_RATE)
	if auto_scan and _clock >= _next_scan:
		_next_scan = _clock + BASE_SCAN
		rescan_base()
	for id: int in _warnings.keys():
		var warning: Warning = _warnings[id]
		if _clock > warning.deadline + EruptionCues.OVERDUE:
			_forget(id)
			continue
		_read_vent(warning)
		warning.presence = move_toward(warning.presence, 1.0, delta / EruptionCues.ARRIVE)
	_assign_slots()
	for slot: int in _slots.size():
		_apply_slot(slot)
	_apply_music()


## A vent is about to erupt in `seconds` over `radius` metres.
func handle_eruption_warning(vent: Node3D, seconds: float, radius: float) -> void:
	if vent == null or not is_instance_valid(vent):
		return
	var id: int = vent.get_instance_id()
	if seconds < 0.0 or is_inf(seconds):
		_forget(id)
		_apply_music()
		return
	var warning: Warning = _warnings.get(id, null)
	if warning == null:
		warning = Warning.new()
		warning.vent = vent
		_warnings[id] = warning
		warning.next_knock = _clock + EruptionCues.knock_gap(seconds)
	warning.deadline = _clock + maxf(seconds, 0.0)
	warning.radius = radius
	_read_vent(warning)
	_assign_slots()
	_apply_music()


## The vent erupts now. Returns true if a blast was heard.
func handle_eruption(vent: Node3D, radius: float) -> bool:
	var at: Vector3 = Vector3.INF
	var seen: bool = true
	if vent != null and is_instance_valid(vent):
		var id: int = vent.get_instance_id()
		if _warnings.has(id):
			_read_vent(_warnings[id])
		_forget(id)
		at = vent.global_position if vent.is_inside_tree() else vent.position
		seen = _is_seen(vent)
	if not at.is_finite():
		return false
	_assign_slots()
	_apply_music()
	var weight: float = EruptionCues.weight(radius, _distance(at))
	var index: int = _blast_player_for(weight)
	if index < 0:
		return false
	var event: SoundEvent = resolve_event.call(EruptionCues.BLAST)
	if event == null or event.streams.is_empty():
		return false
	var player: AudioStreamPlayer3D = _blasts[index]
	player.stop()
	player.stream = event.streams[_rng.randi() % event.streams.size()]
	player.volume_db = EruptionCues.blast_db(radius, seen)
	player.attenuation_filter_cutoff_hz = EruptionCues.cutoff_hz(seen)
	player.global_position = at
	player.play()
	_blast_weight[index] = weight
	if seen and _clock - _last_duck >= EruptionCues.MIN_DUCK_GAP:
		_last_duck = _clock
		duck.call(EruptionCues.DUCK_HOLD)
	return true


## The simulation advanced to `tick`: the clock follows it.
func handle_sim_ticked(tick: int) -> void:
	var sim_now: float = float(tick) / SimClock.TICK_RATE
	if not _ticking:
		_ticking = true
		_tick_offset = _clock - sim_now
	_tick_time = sim_now + _tick_offset
	_clock = maxf(_clock, _tick_time)


func handle_mission_started() -> void:
	_ticking = false
	_warnings.clear()
	for slot: int in _slots.size():
		_slot_owner[slot] = 0
		for player: AudioStreamPlayer3D in _slots[slot]:
			player.stop()
			player.volume_db = AudioMix.SILENT_DB
	for i: int in _blasts.size():
		_blasts[i].stop()
		_blast_weight[i] = 0.0
	_last_duck = -INF
	_apply_music()


## Re-reads where the player's buildings are.
func rescan_base() -> void:
	_base.clear()
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(BUILDINGS_GROUP):
		var building: Node3D = node as Node3D
		if building != null and AudioEventRouter.faction_of(building) == player_faction:
			_base.append(building.global_position)


## 0..1: the most pressing warned vent near the player's base (the pressure layer).
func pressure() -> float:
	var most: float = 0.0
	for warning: Warning in _warnings.values():
		if _near_base(warning):
			most = maxf(most, EruptionCues.progress(warning.deadline - _clock))
	return most


func warning_count() -> int:
	return _warnings.size()


## Vents whose build-up is sounding (holding a slot), for tests.
func building_vents() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for slot: int in _slots.size():
		var warning: Warning = _warnings.get(_slot_owner[slot], null)
		if warning != null and _slot_playing(slot):
			out.append(warning.vent)
	return out


## The build players of `vent` as [pitch, low dB, high dB, cutoff Hz], or [] if
## it holds no slot.
func build_state(vent: Node3D) -> Array[float]:
	if vent == null:
		return []
	var slot: int = _slot_owner.find(vent.get_instance_id())
	if slot < 0:
		return []
	var low: AudioStreamPlayer3D = _slots[slot][0]
	var high: AudioStreamPlayer3D = _slots[slot][1]
	return [low.pitch_scale, low.volume_db, high.volume_db, low.attenuation_filter_cutoff_hz]


## Blasts sounding now, for tests.
func blasts_playing() -> int:
	var count: int = 0
	for player: AudioStreamPlayer3D in _blasts:
		if player.playing:
			count += 1
	return count


## Where the sounding blasts are, for tests.
func blast_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for player: AudioStreamPlayer3D in _blasts:
		if player.playing:
			out.append(player.global_position)
	return out


func seed_rng(value: int) -> void:
	_rng.seed = value


# --- Internals ----------------------------------------------------------------


func _make_player(player_name: String) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = player_name
	player.bus = WEATHER_BUS
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 10.0
	player.max_distance = MAX_DISTANCE
	player.volume_db = AudioMix.SILENT_DB
	add_child(player)
	return player


## Gives the heaviest warnings the build slots; a warning keeps its slot while
## it stays among them.
func _assign_slots() -> void:
	var ids: Array[int] = []
	var weights: PackedFloat32Array = []
	for id: int in _warnings:
		var warning: Warning = _warnings[id]
		ids.append(id)
		weights.append(EruptionCues.weight(warning.radius, _distance(warning.position)))
	var wanted: Array[int] = []
	for index: int in EruptionCues.strongest(weights, EruptionCues.MAX_BUILDS):
		wanted.append(ids[index])
	for slot: int in _slot_owner.size():
		if _slot_owner[slot] != 0 and not wanted.has(_slot_owner[slot]):
			_release_slot(slot)
	for id: int in wanted:
		if _slot_owner.has(id):
			continue
		var free: int = _slot_owner.find(0)
		if free < 0:
			break
		_slot_owner[free] = id
		var warning: Warning = _warnings[id]
		warning.next_knock = minf(
			warning.next_knock, _clock + EruptionCues.knock_gap(warning.deadline - _clock)
		)


func _release_slot(slot: int) -> void:
	_slot_owner[slot] = 0
	for player: AudioStreamPlayer3D in _slots[slot]:
		player.stop()
		player.volume_db = AudioMix.SILENT_DB


func _slot_playing(slot: int) -> bool:
	var low: AudioStreamPlayer3D = _slots[slot][0]
	var high: AudioStreamPlayer3D = _slots[slot][1]
	return low.playing or high.playing


func _apply_slot(slot: int) -> void:
	var warning: Warning = _warnings.get(_slot_owner[slot], null)
	if warning == null:
		if _slot_owner[slot] != 0:
			_release_slot(slot)
		return
	var left: float = maxf(warning.deadline - _clock, 0.0)
	var pitch: float = EruptionCues.pitch(left)
	var cutoff: float = EruptionCues.cutoff_hz(warning.seen)
	for k: int in EruptionCues.LAYERS.size():
		var player: AudioStreamPlayer3D = _slots[slot][k]
		var db: float = EruptionCues.layer_db(
			EruptionCues.LAYERS[k], left, warning.presence, warning.seen
		)
		player.global_position = warning.position
		player.pitch_scale = pitch
		player.attenuation_filter_cutoff_hz = cutoff
		if db <= AudioMix.SILENT_DB:
			player.volume_db = AudioMix.SILENT_DB
			continue
		if not player.playing:
			var event: SoundEvent = resolve_event.call(EruptionCues.LAYERS[k])
			if event == null or event.streams.is_empty():
				continue
			player.stream = event.streams[0]
			player.volume_db = db
			player.play(_rng.randf() * maxf(player.stream.get_length() - 0.5, 0.0))
		player.volume_db = db
	if _clock >= warning.next_knock:
		warning.next_knock = _clock + EruptionCues.knock_gap(left)
		_knock(slot, warning, left)


func _knock(slot: int, warning: Warning, left: float) -> void:
	var event: SoundEvent = resolve_event.call(EruptionCues.KNOCK)
	if event == null or event.streams.is_empty() or warning.presence <= 0.0:
		return
	var player: AudioStreamPlayer3D = _slots[slot][2]
	player.stop()
	player.stream = event.streams[_rng.randi() % event.streams.size()]
	var level: float = EruptionCues.level_db(left) + AudioMix.linear_to_db_safe(warning.presence)
	player.volume_db = level + (0.0 if warning.seen else EruptionCues.UNSEEN_DB)
	player.pitch_scale = pow(2.0, _rng.randf_range(-0.6, 0.6) / 12.0)
	player.attenuation_filter_cutoff_hz = EruptionCues.cutoff_hz(warning.seen)
	player.global_position = warning.position
	player.play()
	knocks += 1


## Free blast player, or the weakest one if `weight` beats it; -1 if none.
func _blast_player_for(weight: float) -> int:
	var weakest: int = -1
	for i: int in _blasts.size():
		if not _blasts[i].playing:
			return i
		if weakest < 0 or _blast_weight[i] < _blast_weight[weakest]:
			weakest = i
	if weakest >= 0 and weight > _blast_weight[weakest]:
		return weakest
	return -1


func _forget(id: int) -> void:
	_warnings.erase(id)
	var slot: int = _slot_owner.find(id)
	if slot >= 0:
		_release_slot(slot)


func _read_vent(warning: Warning) -> void:
	if warning.vent == null or not is_instance_valid(warning.vent):
		return
	var vent: Node3D = warning.vent
	warning.position = vent.global_position if vent.is_inside_tree() else vent.position
	warning.seen = _is_seen(vent)


static func _is_seen(vent: Node) -> bool:
	var seen: Variant = vent.get(&"is_visible_to_player")
	return not (seen is bool and not seen)


func _near_base(warning: Warning) -> bool:
	var reach: float = warning.radius + EruptionCues.BASE_MARGIN
	for at: Vector3 in _base:
		if Vector2(at.x - warning.position.x, at.z - warning.position.z).length() <= reach:
			return true
	return false


func _distance(at: Vector3) -> float:
	return Vector2(at.x - focus.x, at.z - focus.z).length()


func _apply_music() -> void:
	var db: float = EruptionCues.music_gain_db(pressure())
	if db != _music_db:
		_music_db = db
		set_music_gain.call(db)


## One warned vent.
class Warning:
	extends RefCounted
	var vent: Node3D
	var position: Vector3 = Vector3.ZERO
	var radius: float = 10.0
	var deadline: float = 0.0
	var presence: float = 0.0
	var next_knock: float = 0.0
	var seen: bool = true
