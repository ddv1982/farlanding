extends GutTest
## MusicMood: combat heat -> explore / tension / combat / aftermath, with
## hysteresis so the score does not flap.

const NEAR: float = 10.0
const FAR: float = 200.0

var _mood: MusicMood


func before_each() -> void:
	_mood = MusicMood.new()


## Steady fighting: `per_second` shots and hits at `distance` from t0 to t1.
func _fight(t0: float, t1: float, per_second: float, distance: float) -> void:
	var step: float = 1.0 / per_second
	var t: float = t0
	while t < t1:
		_mood.note_fire(distance, t)
		_mood.note_damage(true, false, distance, t)
		_mood.update(t)
		t += step


func test_starts_in_explore_and_ignores_silence() -> void:
	for t: float in [0.0, 10.0, 100.0]:
		assert_eq(_mood.update(t), MusicMood.EXPLORE)


func test_a_distant_skirmish_raises_tension_only() -> void:
	_fight(0.0, 6.0, 1.0, FAR)
	assert_eq(_mood.update(6.0), MusicMood.TENSION)


func test_a_fight_near_the_camera_is_combat() -> void:
	_fight(0.0, 4.0, 4.0, NEAR)
	assert_eq(_mood.update(4.0), MusicMood.COMBAT)


func test_a_single_scratch_is_not_tension() -> void:
	_mood.note_damage(true, false, FAR, 0.0)
	assert_eq(_mood.update(0.1), MusicMood.EXPLORE)


func test_enemy_on_enemy_damage_is_ignored() -> void:
	for i: int in 50:
		_mood.note_damage(false, false, NEAR, i * 0.1)
	assert_eq(_mood.update(5.0), MusicMood.EXPLORE)


func test_combat_does_not_flap_during_a_lull() -> void:
	_fight(0.0, 6.0, 4.0, NEAR)
	assert_eq(_mood.update(6.0), MusicMood.COMBAT)
	# A short lull, then shots resume: combat holds throughout.
	for t: float in [8.0, 10.0, 12.0]:
		assert_eq(_mood.update(t), MusicMood.COMBAT, "lull at %.0f s" % t)
	_fight(12.0, 16.0, 4.0, NEAR)
	assert_eq(_mood.update(16.0), MusicMood.COMBAT)


func test_combat_resolves_through_aftermath_back_to_explore() -> void:
	_fight(0.0, 6.0, 4.0, NEAR)
	var t: float = 6.0
	var seen: Array[StringName] = []
	while t < 120.0:
		var state: StringName = _mood.update(t)
		if seen.is_empty() or seen[-1] != state:
			seen.append(state)
		t += 0.25
	assert_eq(seen, [MusicMood.COMBAT, MusicMood.AFTERMATH, MusicMood.EXPLORE] as Array[StringName])


func test_aftermath_lasts_its_time() -> void:
	_fight(0.0, 6.0, 4.0, NEAR)
	var t: float = 6.0
	while _mood.update(t) != MusicMood.AFTERMATH:
		t += 0.25
	var entered: float = t
	while _mood.update(t) == MusicMood.AFTERMATH:
		t += 0.25
	assert_almost_eq(t - entered, MusicMood.AFTERMATH_SECONDS, 0.3)


func test_tension_falls_back_to_explore_without_aftermath() -> void:
	_fight(0.0, 6.0, 1.0, FAR)
	var t: float = 6.0
	var seen: Array[StringName] = []
	while t < 80.0:
		var state: StringName = _mood.update(t)
		if seen.is_empty() or seen[-1] != state:
			seen.append(state)
		t += 0.25
	assert_eq(seen, [MusicMood.TENSION, MusicMood.EXPLORE] as Array[StringName])


func test_fighting_again_in_aftermath_returns_to_combat() -> void:
	_fight(0.0, 6.0, 4.0, NEAR)
	var t: float = 6.0
	while _mood.update(t) != MusicMood.AFTERMATH:
		t += 0.25
	_fight(t, t + 4.0, 4.0, NEAR)
	assert_eq(_mood.update(t + 4.0), MusicMood.COMBAT)


func test_heat_halves_every_half_life() -> void:
	_mood.note_death(true, NEAR, 0.0)
	var start: float = _mood.heat(0.0)
	assert_almost_eq(_mood.heat(MusicMood.HALF_LIFE), start * 0.5, 0.001)


func test_mission_end_fixes_the_state() -> void:
	_fight(0.0, 6.0, 4.0, NEAR)
	_mood.end_mission(true)
	assert_eq(_mood.update(7.0), MusicMood.VICTORY)
	_fight(7.0, 9.0, 4.0, NEAR)
	assert_eq(_mood.update(100.0), MusicMood.VICTORY)
	var lost: MusicMood = MusicMood.new()
	lost.end_mission(false)
	assert_eq(lost.update(0.0), MusicMood.DEFEAT)
