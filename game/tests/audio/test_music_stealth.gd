extends GutTest
## Stealth and storm music: the arbiter between combat and stealth moods, the
## Kessel score's stealth states, beat quantisation in the director, the beds,
## and the Audio autoload resetting the storm layer on mission start.

const SCORE: String = "res://data/sounds/music/kessel_reach.tres"


func test_arbiter_without_stealth_is_the_combat_mood() -> void:
	assert_eq(MusicArbiter.pick(&"explore", &""), &"explore")
	assert_eq(MusicArbiter.pick(&"combat", &""), &"combat")


func test_arbiter_stealth_over_calm_fighting_over_unaware() -> void:
	assert_eq(MusicArbiter.pick(&"explore", &"stealth_unaware"), &"stealth_unaware")
	assert_eq(MusicArbiter.pick(&"tension", &"stealth_unaware"), &"tension")
	assert_eq(MusicArbiter.pick(&"aftermath", &"stealth_unaware"), &"aftermath")
	assert_eq(MusicArbiter.pick(&"tension", &"stealth_alerted"), &"stealth_alerted")
	assert_eq(MusicArbiter.pick(&"combat", &"stealth_alerted"), &"combat")


func test_level_to_state_mapping() -> void:
	assert_eq(StealthCues.music_state_for(&"unaware"), &"stealth_unaware")
	assert_eq(StealthCues.music_state_for(&"suspicious"), &"stealth_suspicious")
	assert_eq(StealthCues.music_state_for(&"alerted"), &"stealth_alerted")


func test_score_has_the_stealth_states_and_layers() -> void:
	var score: MusicScore = load(SCORE)
	var clip: MusicClip = score.clips[0]
	for layer: String in ["hush", "watch", "storm"]:
		assert_true(clip.layer_names.has(layer), layer)
	var hush: int = clip.layer_names.find("hush")
	var watch: int = clip.layer_names.find("watch")
	var drums: int = clip.layer_names.find("drums")
	var unaware: MusicState = score.find_state(&"stealth_unaware")
	var suspicious: MusicState = score.find_state(&"stealth_suspicious")
	var alerted: MusicState = score.find_state(&"stealth_alerted")
	for state: MusicState in [unaware, suspicious, alerted]:
		assert_not_null(state)
		assert_eq(state.layer_volumes_db.size(), clip.layers.size(), String(state.name))
	assert_gt(unaware.layer_volumes_db[hush], AudioMix.SILENT_DB, "sparse while unaware")
	assert_eq(unaware.layer_volumes_db[watch], AudioMix.SILENT_DB)
	assert_gt(suspicious.layer_volumes_db[watch], AudioMix.SILENT_DB, "the pulse joins")
	assert_eq(suspicious.layer_volumes_db[drums], AudioMix.SILENT_DB)
	assert_gt(alerted.layer_volumes_db[drums], AudioMix.SILENT_DB, "full drive")
	assert_lt(unaware.intensity, suspicious.intensity)
	assert_lt(suspicious.intensity, alerted.intensity)
	assert_lt(alerted.fade_seconds, unaware.fade_seconds, "the alarm lands quickly")
	assert_gt(score.bpm, 0.0)
	assert_gt(score.quantize_beats, 0.0)


func test_next_boundary_lands_on_the_beat() -> void:
	var beat: float = 60.0 / 80.0
	assert_almost_eq(MusicDirector.next_boundary(10.0, 10.0, 80.0, 1.0), 10.0, 0.0001)
	assert_almost_eq(MusicDirector.next_boundary(10.1, 10.0, 80.0, 1.0), 10.0 + beat, 0.0001)
	assert_almost_eq(MusicDirector.next_boundary(10.0 + beat, 10.0, 80.0, 1.0), 10.0 + beat, 0.0001)
	assert_almost_eq(MusicDirector.next_boundary(11.0, 10.0, 80.0, 4.0), 10.0 + 4 * beat, 0.0001)
	assert_almost_eq(MusicDirector.next_boundary(7.3, 10.0, 0.0, 1.0), 7.3, 0.0001, "no tempo")


func test_director_waits_for_the_beat_and_uses_the_state_fade() -> void:
	var director: MusicDirector = MusicDirector.new()
	add_child_autofree(director)
	director.play_score(load(SCORE) as MusicScore)
	director.set_state(&"stealth_alerted")
	var wait: float = director.seconds_to_pending_change()
	assert_true(wait >= 0.0 and wait <= 60.0 / 80.0 + 0.01, "waits at most a beat (%.3f)" % wait)
	var targets: PackedFloat32Array = director.layer_targets_db(&"stealth_alerted")
	assert_eq(targets.size(), (load(SCORE) as MusicScore).clips[0].layers.size())
	director.force_state(&"victory")
	assert_eq(director.seconds_to_pending_change(), INF, "forced states do not wait")
	director.stop()


func test_storm_layer_follows_its_gain() -> void:
	var director: MusicDirector = MusicDirector.new()
	add_child_autofree(director)
	director.play_score(load(SCORE) as MusicScore)
	var storm: int = (load(SCORE) as MusicScore).clips[0].layer_names.find("storm")
	director.set_layer_gain(&"storm", AudioMix.SILENT_DB)
	assert_eq(director.layer_targets_db(&"explore")[storm], AudioMix.SILENT_DB)
	director.set_layer_gain(&"storm", 0.0)
	assert_gt(director.layer_targets_db(&"explore")[storm], AudioMix.SILENT_DB)
	assert_eq(director.layer_targets_db(&"victory")[storm], AudioMix.SILENT_DB)
	director.stop()


func test_bed_dips_the_score_and_comes_back() -> void:
	var director: MusicDirector = MusicDirector.new()
	add_child_autofree(director)
	director.set_process(false)
	var bed: AudioStream = load("res://assets/audio/music/beds/mus_briefing_bed.ogg")
	director.play_bed(bed, -14.0)
	for i: int in 40:
		director._process(0.1)
	assert_eq(director.bed_stream(), bed)
	assert_almost_eq(director.bed_level(), 1.0, 0.001)
	assert_almost_eq(director.score_dip_db(), -14.0, 0.001)
	director.stop_bed()
	for i: int in 40:
		director._process(0.1)
	assert_almost_eq(director.score_dip_db(), 0.0, 0.001)
	assert_null(director.bed_stream(), "the bed stopped once silent")


func test_audio_service_starts_with_the_storm_silent() -> void:
	Events.mission_started.emit()
	var music: MusicDirector = Audio.get_node(^"MusicDirector") as MusicDirector
	assert_eq(music.layer_gain_db(&"storm"), AudioMix.SILENT_DB)
