extends GutTest
## Phase 8b, Emberfall's eruptions: EruptionCues (the build-up as a clock, the
## blast, the pressure layer) and the EruptionSound node driven with stubs.
## Signals are emitted or handlers called by hand (gameplay need not exist);
## time is advanced by hand; the RNG is seeded.

const EVENTS_DIR: String = "res://data/sounds"


class FakeVent:
	extends Node3D
	var is_visible_to_player: bool = true


class FakeBuilding:
	extends Node3D
	var faction: int = 0


var _sound: EruptionSound
var _ducks: Array[float] = []
var _music_gains: Array[float] = []


func before_each() -> void:
	_ducks.clear()
	_music_gains.clear()
	_sound = EruptionSound.new()
	_sound.resolve_event = func(id: StringName) -> SoundEvent:
		var path: String = "%s/weather/%s.tres" % [EVENTS_DIR, id]
		return load(path) as SoundEvent if ResourceLoader.exists(path) else null
	_sound.duck = func(hold: float) -> void: _ducks.append(hold)
	_sound.set_music_gain = func(db: float) -> void: _music_gains.append(db)
	_sound.auto_scan = false
	add_child_autofree(_sound)
	_sound.set_process(false)
	_sound.seed_rng(11)
	_sound.focus = Vector3.ZERO


func after_each() -> void:
	_sound.handle_mission_started()
	# The emitted signals reached the real service too: leave it quiet.
	(Audio.get_node(^"Eruption") as EruptionSound).handle_mission_started()


func _vent(at: Vector3, seen: bool = true) -> FakeVent:
	var vent: FakeVent = FakeVent.new()
	vent.position = at
	vent.is_visible_to_player = seen
	add_child_autofree(vent)
	return vent


func _run(seconds: float, step: float = 0.1) -> void:
	for i: int in roundi(seconds / step):
		_sound.advance(step)


# --- Pure rules -------------------------------------------------------------------


func test_the_build_up_is_a_clock() -> void:
	var last_pitch: float = 0.0
	var last_gap: float = INF
	var last_db: float = -INF
	for s: int in range(40, -1, -1):
		var left: float = float(s)
		var pitch: float = EruptionCues.pitch(left)
		var gap: float = EruptionCues.knock_gap(left)
		var db: float = EruptionCues.level_db(left)
		assert_true(pitch >= last_pitch, "pitch only rises as the eruption nears")
		assert_true(gap <= last_gap, "knocks only come faster")
		assert_true(db >= last_db, "and it only grows louder")
		last_pitch = pitch
		last_gap = gap
		last_db = db
	assert_almost_eq(EruptionCues.pitch(EruptionCues.BUILD_SPAN), EruptionCues.PITCH.x, 0.0001)
	assert_almost_eq(EruptionCues.pitch(0.0), EruptionCues.PITCH.y, 0.0001)
	assert_almost_eq(EruptionCues.level_db(0.0), 0.0, 0.0001)
	assert_almost_eq(
		EruptionCues.knock_gap(10.0), 1.5, 0.0001, "one knock every 1.5 s: ten seconds"
	)


func test_the_growl_turns_into_the_hiss() -> void:
	var far_low: float = EruptionCues.layer_db(EruptionCues.BUILD_LOW, 30.0, 1.0, true)
	var far_high: float = EruptionCues.layer_db(EruptionCues.BUILD_HIGH, 30.0, 1.0, true)
	var near_low: float = EruptionCues.layer_db(EruptionCues.BUILD_LOW, 0.0, 1.0, true)
	var near_high: float = EruptionCues.layer_db(EruptionCues.BUILD_HIGH, 0.0, 1.0, true)
	assert_gt(far_low, far_high, "early: the deep growl")
	assert_gt(near_high, near_low, "late: the pressurised hiss")
	var unseen: float = EruptionCues.layer_db(EruptionCues.BUILD_LOW, 20.0, 1.0, false)
	var seen: float = EruptionCues.layer_db(EruptionCues.BUILD_LOW, 20.0, 1.0, true)
	assert_almost_eq(unseen, seen + EruptionCues.UNSEEN_DB, 0.001, "unseen is quieter")
	assert_gt(unseen, AudioMix.SILENT_DB, "but never silent")


func test_weight_prefers_near_and_large() -> void:
	assert_gt(EruptionCues.weight(10.0, 20.0), EruptionCues.weight(10.0, 60.0), "nearer wins")
	assert_gt(EruptionCues.weight(20.0, 40.0), EruptionCues.weight(10.0, 40.0), "larger wins")
	var order: PackedInt32Array = EruptionCues.strongest(PackedFloat32Array([0.2, 0.9, 0.5]), 2)
	assert_eq(Array(order), [1, 2])


func test_the_pressure_layer_comes_in_as_a_vent_fills() -> void:
	assert_eq(EruptionCues.music_gain_db(0.0), AudioMix.SILENT_DB)
	var last: float = AudioMix.SILENT_DB
	for step: int in range(1, 11):
		var db: float = EruptionCues.music_gain_db(step / 10.0)
		assert_true(db >= last)
		last = db
	assert_almost_eq(EruptionCues.music_gain_db(1.0), EruptionCues.MUSIC_TOP_DB, 0.01)


# --- The node ---------------------------------------------------------------------


func test_a_warning_builds_at_the_vent_and_rises() -> void:
	var vent: FakeVent = _vent(Vector3(20, 0, 0))
	Events.eruption_warning.emit(vent, 25.0, 12.0)
	_sound.advance(0.05)
	assert_eq(_sound.building_vents(), [vent] as Array[Node3D], "its build-up sounds")
	var start: Array[float] = _sound.build_state(vent)
	assert_almost_eq(start[0], EruptionCues.pitch(25.0 - 0.05), 0.001, "pitch from the time left")
	_run(3.0)
	var arrived: Array[float] = _sound.build_state(vent)
	assert_gt(arrived[1], start[1], "it fades in")
	_run(18.0)
	var late: Array[float] = _sound.build_state(vent)
	assert_gt(late[0], arrived[0], "and rises in pitch as the eruption nears")
	assert_gt(late[2], arrived[2], "the hiss comes up")


func test_knocks_come_faster_as_it_nears() -> void:
	var vent: FakeVent = _vent(Vector3(15, 0, 0))
	_sound.handle_eruption_warning(vent, 30.0, 10.0)
	_run(2.0)  # arrive
	var before: int = _sound.knocks
	_run(6.0)  # 28 -> 22 s left
	var early: int = _sound.knocks - before
	_run(16.0)  # to 6 s left
	before = _sound.knocks
	_run(6.0)  # 6 -> 0 s left
	var late: int = _sound.knocks - before
	assert_gt(
		late, early * 3, "a rattle at the end (%d) against a few knocks early (%d)" % [late, early]
	)


func test_the_eruption_stops_the_build_and_blasts_once_ducking() -> void:
	var vent: FakeVent = _vent(Vector3(20, 0, 0))
	_sound.handle_eruption_warning(vent, 5.0, 12.0)
	_run(2.0)
	assert_true(_sound.handle_eruption(vent, 12.0), "the blast plays")
	assert_eq(_sound.building_vents().size(), 0, "the build-up stops")
	assert_eq(_sound.blasts_playing(), 1)
	assert_eq(_ducks.size(), 1, "a seen blast ducks the mix")
	var other: FakeVent = _vent(Vector3(-20, 0, 0))
	_sound.handle_eruption(other, 12.0)
	assert_eq(_ducks.size(), 1, "not twice in a row")


func test_many_vents_never_stack() -> void:
	var vents: Array[FakeVent] = []
	for d: float in [10.0, 30.0, 60.0, 100.0]:
		var vent: FakeVent = _vent(Vector3(d, 0, 0))
		vents.append(vent)
		_sound.handle_eruption_warning(vent, 20.0, 12.0)
	_run(1.0)
	var heard: Array[Node3D] = _sound.building_vents()
	assert_eq(heard.size(), EruptionCues.MAX_BUILDS, "at most two build-ups")
	assert_true(heard.has(vents[0]) and heard.has(vents[1]), "the nearest two")
	assert_eq(_sound.warning_count(), 4, "the others are still followed")
	_sound.handle_eruption(vents[0], 12.0)
	_run(0.2)
	heard = _sound.building_vents()
	assert_true(heard.has(vents[2]), "a freed slot goes to the next in line")
	# A large vent far away outweighs a small one nearby.
	var big: FakeVent = _vent(Vector3(50, 0, 0))
	_sound.handle_eruption_warning(big, 20.0, 60.0)
	_run(0.2)
	assert_true(_sound.building_vents().has(big), "the largest wins too")
	var players: int = 0
	for child: Node in _sound.get_children():
		if child is AudioStreamPlayer3D:
			players += 1
	assert_eq(
		players, EruptionCues.MAX_BUILDS * 3 + EruptionCues.MAX_BLASTS, "a fixed set of players"
	)


func test_many_blasts_at_once_keep_the_heaviest_two() -> void:
	var near: FakeVent = _vent(Vector3(10, 0, 0))
	var mid: FakeVent = _vent(Vector3(25, 0, 0))
	var far: FakeVent = _vent(Vector3(120, 0, 0))
	var farther: FakeVent = _vent(Vector3(200, 0, 0))
	for vent: FakeVent in [far, farther, near, mid]:
		_sound.handle_eruption(vent, 12.0)
	assert_eq(_sound.blasts_playing(), EruptionCues.MAX_BLASTS)
	var at: Array[Vector3] = _sound.blast_positions()
	assert_true(at.has(near.global_position) and at.has(mid.global_position), "nearest win")


func test_an_unseen_vent_is_quieter_and_duller_not_silent() -> void:
	var seen: FakeVent = _vent(Vector3(20, 0, 0))
	var hidden: FakeVent = _vent(Vector3(-20, 0, 0), false)
	_sound.handle_eruption_warning(seen, 15.0, 12.0)
	_sound.handle_eruption_warning(hidden, 15.0, 12.0)
	_run(2.0)
	var a: Array[float] = _sound.build_state(seen)
	var b: Array[float] = _sound.build_state(hidden)
	assert_almost_eq(b[1], a[1] + EruptionCues.UNSEEN_DB, 0.01, "quieter")
	assert_gt(b[1], AudioMix.SILENT_DB, "not silent")
	assert_lt(b[3], a[3], "duller")
	hidden.is_visible_to_player = true
	_run(0.1)
	assert_almost_eq(_sound.build_state(hidden)[3], EruptionCues.SEEN_CUTOFF_HZ, 0.1, "seen now")


func test_a_restored_warning_picks_up_without_a_jump() -> void:
	var vent: FakeVent = _vent(Vector3(20, 0, 0))
	_sound.handle_eruption_warning(vent, 30.0, 12.0)
	_run(20.0)  # 10 s left
	var pitch: float = _sound.build_state(vent)[0]
	Events.mission_started.emit()  # a loaded save starts a mission ...
	assert_eq(_sound.building_vents().size(), 0, "mission_started stops it")
	Events.eruption_warning.emit(vent, 10.0, 12.0)  # ... and re-emits what is left
	_sound.advance(0.0)
	var resumed: Array[float] = _sound.build_state(vent)
	assert_almost_eq(resumed[0], pitch, 0.001, "the same pitch: same time left, same sound")
	var last: float = _build_power_db(vent)
	for i: int in 20:
		_sound.advance(0.1)
		var now: float = _build_power_db(vent)
		assert_true(now >= last - 0.001, "it fades in, never jumps down")
		if last > -40.0:
			assert_lt(now - last, 7.0, "and only fades up")
		last = now


## The two build loops of `vent` summed by power (dB).
func _build_power_db(vent: Node3D) -> float:
	var state: Array[float] = _sound.build_state(vent)
	var power: float = db_to_linear(state[1]) ** 2 + db_to_linear(state[2]) ** 2
	return AudioMix.linear_to_db_safe(sqrt(power))


func test_a_repeated_warning_moves_the_deadline_without_restarting() -> void:
	var vent: FakeVent = _vent(Vector3(20, 0, 0))
	_sound.handle_eruption_warning(vent, 20.0, 12.0)
	_run(3.0)
	var before: Array[float] = _sound.build_state(vent)
	_sound.handle_eruption_warning(vent, 17.0, 12.0)
	_sound.advance(0.0)
	var after: Array[float] = _sound.build_state(vent)
	assert_almost_eq(after[1], before[1], 0.01, "no fade restart")
	assert_eq(_sound.warning_count(), 1)


func test_calling_off_stops_the_build_up() -> void:
	var vent: FakeVent = _vent(Vector3(20, 0, 0))
	_sound.handle_eruption_warning(vent, 20.0, 12.0)
	_run(1.0)
	_sound.handle_eruption_warning(vent, -1.0, 12.0)
	assert_eq(_sound.warning_count(), 0, "a negative time calls it off")
	var other: FakeVent = _vent(Vector3(30, 0, 0))
	_sound.handle_eruption_warning(other, 20.0, 12.0)
	_sound.focus = Vector3(28, 0, 0)
	Events.ui_feedback.emit(&"vent_release")  # the player vented the one in view
	assert_eq(_sound.warning_count(), 0, "a controlled vent calls off the one nearest the camera")


func test_an_overdue_warning_is_dropped() -> void:
	var vent: FakeVent = _vent(Vector3(20, 0, 0))
	_sound.handle_eruption_warning(vent, 2.0, 12.0)
	_run(2.0 + EruptionCues.OVERDUE + 0.5)
	assert_eq(_sound.warning_count(), 0, "no eruption came: the build-up does not hang")


func test_pressure_layer_follows_vents_near_the_base() -> void:
	var building: FakeBuilding = FakeBuilding.new()
	building.position = Vector3(100, 0, 0)
	building.add_to_group(EruptionSound.BUILDINGS_GROUP)
	add_child_autofree(building)
	var enemy: FakeBuilding = FakeBuilding.new()
	enemy.faction = 1
	enemy.position = Vector3(-100, 0, 0)
	enemy.add_to_group(EruptionSound.BUILDINGS_GROUP)
	add_child_autofree(enemy)
	_sound.rescan_base()
	var by_enemy: FakeVent = _vent(Vector3(-110, 0, 0))
	_sound.handle_eruption_warning(by_enemy, 5.0, 12.0)
	_run(1.0)
	assert_eq(_sound.pressure(), 0.0, "a vent by the enemy base is not ours to fear")
	var by_base: FakeVent = _vent(Vector3(115, 0, 0))
	_sound.handle_eruption_warning(by_base, 25.0, 12.0)
	_run(1.0)
	var early: float = _music_gains[-1]
	_run(20.0)
	assert_gt(_sound.pressure(), 0.7)
	assert_gt(_music_gains[-1], early, "the pressure layer rises as it fills")
	_sound.handle_eruption(by_base, 12.0)
	assert_eq(_music_gains[-1], AudioMix.SILENT_DB, "and goes when it blows")


func test_the_build_up_keeps_sim_time() -> void:
	var vent: FakeVent = _vent(Vector3(20, 0, 0))
	_sound.handle_sim_ticked(100)
	_sound.handle_eruption_warning(vent, 10.0, 12.0)
	_run(1.0)
	var at_start: float = _sound.build_state(vent)[0]
	_run(5.0)  # paused: no ticks arrive
	var paused: float = _sound.build_state(vent)[0]
	assert_almost_eq(paused, at_start, 0.02, "a paused game holds the build-up")
	for k: int in 50:  # five sim seconds pass at once (a fast game speed)
		_sound.handle_sim_ticked(101 + k)
	_sound.advance(0.0)
	assert_almost_eq(
		_sound.build_state(vent)[0], EruptionCues.pitch(5.0), 0.02, "and follows the sim"
	)


func test_mission_started_resets_everything() -> void:
	var vent: FakeVent = _vent(Vector3(20, 0, 0))
	_sound.handle_eruption_warning(vent, 3.0, 12.0)
	_run(1.0)
	_sound.handle_eruption(_vent(Vector3(5, 0, 0)), 12.0)
	_sound.handle_mission_started()
	assert_eq(_sound.warning_count(), 0)
	assert_eq(_sound.blasts_playing(), 0)
	assert_eq(_sound.building_vents().size(), 0)
