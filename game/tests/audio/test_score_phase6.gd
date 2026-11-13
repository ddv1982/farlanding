extends GutTest
## Phase 6 score: every state and transition, heavy combat, per-loop variants,
## the urgency and storm layers, beat-quantised hits and sting dips.

const SCORE: String = "res://data/sounds/music/kessel_reach.tres"
const STATES: Array[StringName] = [
	&"explore",
	&"calm",
	&"tension",
	&"combat",
	&"combat_heavy",
	&"aftermath",
	&"victory",
	&"defeat",
	&"stealth_unaware",
	&"stealth_suspicious",
	&"stealth_alerted",
]

var _director: MusicDirector


func before_each() -> void:
	_director = MusicDirector.new()
	add_child_autofree(_director)


func after_each() -> void:
	_director.stop()


func _layer(name: String) -> int:
	var score: MusicScore = load(SCORE)
	return Array(score.clips[0].layer_names).find(name)


func test_every_state_exists_and_covers_every_layer() -> void:
	var score: MusicScore = load(SCORE)
	var clip: MusicClip = score.clips[0]
	assert_eq(clip.layer_groups.size(), clip.layers.size())
	assert_eq(clip.loop_beats, 64)
	for state_name: StringName in STATES:
		var state: MusicState = score.find_state(state_name)
		assert_not_null(state, String(state_name))
		if state != null:
			assert_eq(state.layer_volumes_db.size(), clip.layers.size(), String(state_name))
	for layer: AudioStream in clip.layers:
		assert_almost_eq(layer.get_length(), clip.layers[0].get_length(), 0.01, "one grid")


func test_transition_hits_for_every_pair() -> void:
	for from: StringName in STATES:
		for to: StringName in STATES:
			var hit: StringName = ScoreTransitions.hit_for(from, to)
			var fight: Array[StringName] = [&"combat", &"combat_heavy"]
			var expected: StringName = &""
			if (
				from != to
				and not from in [&"victory", &"defeat"]
				and not to in [&"victory", &"defeat"]
			):
				if to in fight and not from in ScoreTransitions.FIGHTING:
					expected = ScoreTransitions.HIT_COMBAT
				elif to == &"aftermath" and from in fight:
					expected = ScoreTransitions.HIT_AFTERMATH
			assert_eq(hit, expected, "%s -> %s" % [from, to])
	for id: StringName in [ScoreTransitions.HIT_COMBAT, ScoreTransitions.HIT_AFTERMATH]:
		assert_true(ResourceLoader.exists("res://data/sounds/sting/%s.tres" % id), String(id))


func test_a_big_fight_is_heavy_and_settles_back() -> void:
	var mood: MusicMood = MusicMood.new()
	var t: float = 0.0
	while t < 8.0:
		for i: int in 6:
			mood.note_fire(10.0, t)
			mood.note_damage(true, false, 10.0, t)
		mood.update(t)
		t += 0.25
	assert_eq(mood.update(t), MusicMood.COMBAT_HEAVY)
	var seen: Array[StringName] = []
	while t < 120.0:
		var state: StringName = mood.update(t)
		if seen.is_empty() or seen[-1] != state:
			seen.append(state)
		t += 0.5
	assert_eq(
		seen,
		(
			[MusicMood.COMBAT_HEAVY, MusicMood.COMBAT, MusicMood.AFTERMATH, MusicMood.EXPLORE]
			as Array[StringName]
		)
	)
	assert_eq(MusicArbiter.pick(MusicMood.COMBAT_HEAVY, &"stealth_alerted"), MusicMood.COMBAT_HEAVY)


func test_one_variant_per_group_and_it_rotates_per_loop() -> void:
	var score: MusicScore = load(SCORE)
	_director.play_score(score)
	var melodies: Array[int] = [_layer("melody"), _layer("melody_b"), _layer("melody_c")]
	var first: PackedFloat32Array = _director.layer_targets_db(&"explore")
	var sounding: int = 0
	for i: int in melodies:
		if first[i] > AudioMix.SILENT_DB:
			sounding += 1
	assert_eq(sounding, 1, "one melody at a time")
	assert_eq(
		_director.variant_of(&"melody"), _layer("melody"), "the first loop plays the original"
	)
	var last: int = _director.variant_of(&"melody")
	var picked: Dictionary[int, bool] = {}
	for loop: int in 30:
		_director.rotate_variants()
		var now: int = _director.variant_of(&"melody")
		assert_ne(now, last, "never the same variant twice running")
		picked[now] = true
		last = now
	assert_eq(picked.size(), 3, "all three melodies come round")
	var drums: PackedFloat32Array = _director.layer_targets_db(&"combat")
	var drum_count: int = 0
	for name: String in ["drums", "drums_b"]:
		if drums[_layer(name)] > AudioMix.SILENT_DB:
			drum_count += 1
	assert_eq(drum_count, 1, "one drum pattern at a time")


func test_variant_pick_is_uniform_without_repeats() -> void:
	for last: int in 3:
		for roll: float in [0.0, 0.4, 0.99]:
			var pick: int = MusicDirector.pick_variant(3, last, roll)
			assert_ne(pick, last)
			assert_between(pick, 0, 2)


func test_urgency_and_storm_layers_are_gain_driven() -> void:
	var score: MusicScore = load(SCORE)
	_director.set_layer_gain(&"urgency", AudioMix.SILENT_DB)
	_director.set_layer_gain(&"storm", AudioMix.SILENT_DB)
	_director.play_score(score)
	var urgency: int = _layer("urgency")
	var storm: int = _layer("storm")
	for state: StringName in STATES:
		assert_eq(
			_director.layer_targets_db(state)[urgency], AudioMix.SILENT_DB, "%s urgency off" % state
		)
	_director.set_layer_gain(&"urgency", 0.0)
	_director.set_layer_gain(&"storm", 0.0)
	for state: StringName in [&"explore", &"tension", &"combat", &"combat_heavy"]:
		assert_gt(_director.layer_targets_db(state)[urgency], -10.0, "%s urges" % state)
		assert_gt(_director.layer_targets_db(state)[storm], -10.0, "%s carries the storm" % state)
	assert_gt(
		_director.layer_targets_db(&"defeat")[storm], -10.0, "the final storm outlasts the defeat"
	)
	assert_eq(_director.layer_targets_db(&"victory")[urgency], AudioMix.SILENT_DB)


func test_beat_actions_and_sting_dip() -> void:
	var score: MusicScore = load(SCORE)
	_director.play_score(score)
	var fired: Array[int] = []
	_director.at_next_beat(func() -> void: fired.append(1))
	await wait_until(func() -> bool: return not fired.is_empty(), 3.0)
	assert_eq(fired.size(), 1, "the action runs once, on the next beat")
	_director.dip_for(1.0, -6.0)
	await wait_seconds(0.8)
	assert_lt(_director.score_dip_db(), -4.0, "the score dips under a sting")
	await wait_seconds(1.2)
	assert_gt(_director.score_dip_db(), -1.0, "and comes back")
