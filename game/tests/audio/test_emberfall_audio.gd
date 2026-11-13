extends GutTest
## Phase 8b, Emberfall: the planet as audio data, its ambience set, its score
## (same states as Kessel and Thalassa, its own key, tempo and material, a
## gain-driven pressure layer and a holdout layer), the re-voiced hits and
## stings, the Advisor kinds with their priorities, the interface kinds, and
## the eruption sounds through the real `Audio` autoload. Signals are emitted
## by hand: gameplay does not need to exist for any of this.

const EMBERFALL: StringName = &"emberfall"
const KESSEL: StringName = &"kessel_reach"
const THALASSA: StringName = &"thalassa_low"
const SCORE: String = "res://data/sounds/music/emberfall.tres"
const KESSEL_SCORE: String = "res://data/sounds/music/kessel_reach.tres"
const THALASSA_SCORE: String = "res://data/sounds/music/thalassa_low.tres"
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
const ADVISOR_KINDS: Array[StringName] = [
	&"eruption_warning",
	&"eruption_damage",
	&"surge_incoming",
	&"wave_incoming",
	&"extraction_inbound",
	&"extraction_arrived",
]


class FakeVent:
	extends Node3D
	var is_visible_to_player: bool = true


class FakeBuilding:
	extends Node3D
	var faction: int = 0


var _director: AmbienceDirector
var _details: Array[StringName] = []


func before_each() -> void:
	_details.clear()
	_director = AmbienceDirector.new()
	_director.resolve_event = Audio.get_event
	_director.play_at = func(id: StringName, _at: Vector3, _db: float) -> bool:
		_details.append(id)
		return true
	add_child_autofree(_director)
	_director.set_process(false)
	_director.auto_scan = false


func after_each() -> void:
	_director.stop()
	(Audio.get_node(^"Eruption") as EruptionSound).handle_mission_started()


func _ember_set() -> AmbienceSet:
	return PlanetAudio.find(EMBERFALL).ambience


func _players_playing(node: Node) -> int:
	var playing: int = 0
	for child: Node in node.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.playing:
			playing += 1
	return playing


# --- Planet and ambience ---------------------------------------------------------


func test_emberfall_names_its_score_and_ambience() -> void:
	var planet: PlanetAudio = PlanetAudio.find(EMBERFALL)
	assert_not_null(planet)
	assert_eq(planet.score.id, EMBERFALL, "the score id is the planet id")
	assert_eq(planet.ambience.id, EMBERFALL)
	for bed: AmbienceBed in planet.ambience.beds:
		assert_true(Audio.has_event(bed.event), "%s exists" % bed.event)
	for detail: AmbienceDetail in planet.ambience.details:
		assert_true(Audio.has_event(detail.event), "%s exists" % detail.event)


func test_play_planet_switches_to_emberfall() -> void:
	Audio.play_planet(EMBERFALL)
	assert_eq(Audio.music().target_score().id, EMBERFALL)
	assert_eq(Audio.ambience().ambience_set().id, EMBERFALL)
	Audio.play_score(load(KESSEL_SCORE) as MusicScore)  # back to Kessel at once


func test_emberfall_beds_replace_the_others_without_doubling() -> void:
	_director.start(PlanetAudio.find(THALASSA).ambience)
	for i: int in 20:
		_director.advance(0.1)
	_director.start(_ember_set())
	for i: int in 50:
		_director.advance(0.1)
	assert_eq(_director.bed_volume_db(&"amb_thalassa_wind"), AudioMix.SILENT_DB, "Thalassa gone")
	assert_gt(_director.bed_volume_db(&"amb_emberfall_rumble"), -12.0, "the ground rumbles")
	assert_gt(_director.bed_volume_db(&"amb_emberfall_lava"), -20.0, "lava moves")
	assert_eq(_players_playing(_director), 3, "rumble, lava and wind: no double beds, no hush")
	_director.start(_ember_set())
	for i: int in 5:
		_director.advance(0.1)
	assert_eq(_players_playing(_director), 3, "starting it again starts nothing twice")


func test_details_crack_and_tick_and_hiss_near_vents() -> void:
	var amb: AmbienceSet = _ember_set()
	var away: Dictionary[StringName, float] = AmbienceCues.detail_weights({}, amb)
	var near: Dictionary[StringName, float] = AmbienceCues.detail_weights(
		{AmbienceCues.VENT_NEAR: 1.0}, amb
	)
	assert_gt(near[&"amb_gas_hiss"], away[&"amb_gas_hiss"], "gas hisses near a vent")
	assert_gt(away[&"amb_rock_crack"], away[&"amb_distant_collapse"], "collapses are rare")
	_director._rng.seed = 5
	_director.start(amb)
	_director.settle()
	for i: int in 200:
		_director.play_detail(fmod(i * 0.377, 1.0))
	assert_gt(_details.count(&"amb_rock_crack"), 0, "cooling rock")
	assert_gt(_details.count(&"amb_ember_tick"), 0, "embers")
	assert_false(_details.has(&"amb_water_lap"), "no Thalassa water on Emberfall")
	assert_false(_details.has(AmbienceCues.ROCK), "no Kessel rock")
	assert_false(_details.has(&"amb_combine_industry"), "no base seen, no industry")


# --- The score -------------------------------------------------------------------


func test_emberfall_score_has_every_state_and_its_own_layers() -> void:
	var score: MusicScore = load(SCORE)
	var kessel: MusicScore = load(KESSEL_SCORE)
	var thalassa: MusicScore = load(THALASSA_SCORE)
	assert_eq(score.id, EMBERFALL)
	assert_ne(score.bpm, kessel.bpm, "its own tempo")
	assert_ne(score.bpm, thalassa.bpm)
	var clip: MusicClip = score.clips[0]
	assert_eq(clip.layers.size(), clip.layer_names.size())
	assert_eq(clip.layers.size(), clip.layer_groups.size())
	var length: float = clip.layers[0].get_length()
	for layer: AudioStream in clip.layers:
		assert_almost_eq(layer.get_length(), length, 0.01, "one grid")
	assert_almost_eq(length, clip.loop_beats * 60.0 / score.bpm, 0.01, "loop_beats matches")
	for state_name: StringName in STATES:
		var state: MusicState = score.find_state(state_name)
		assert_not_null(state, "state %s" % state_name)
		if state != null:
			assert_eq(state.layer_volumes_db.size(), clip.layers.size(), String(state_name))
			assert_eq(state.intensity, kessel.find_state(state_name).intensity, "same arc")
	for layer_name: String in ["pressure", "holdout", "urgency", "trail", "hush", "watch", "heavy"]:
		assert_ne(Array(clip.layer_names).find(layer_name), -1, "a %s layer" % layer_name)


func test_the_pressure_and_holdout_layers_are_silent_until_driven() -> void:
	var director: MusicDirector = MusicDirector.new()
	add_child_autofree(director)
	director.set_layer_gain(&"pressure", AudioMix.SILENT_DB)
	director.set_layer_gain(&"holdout", AudioMix.SILENT_DB)
	director.play_score(load(SCORE) as MusicScore)
	var names: Array = Array(director.score.clips[0].layer_names)
	var pressure: int = names.find("pressure")
	var holdout: int = names.find("holdout")
	assert_eq(director.layer_targets_db(&"explore")[pressure], AudioMix.SILENT_DB)
	assert_eq(director.layer_targets_db(&"combat")[holdout], AudioMix.SILENT_DB)
	director.set_layer_gain(&"pressure", EruptionCues.music_gain_db(1.0))
	director.set_layer_gain(&"holdout", 0.0)
	assert_gt(director.layer_targets_db(&"explore")[pressure], -6.0, "the vent is full")
	assert_gt(director.layer_targets_db(&"combat")[holdout], -6.0, "the last minutes")
	director.stop()


func test_hits_and_stings_are_revoiced_for_emberfall() -> void:
	for id: StringName in [
		&"mus_hit_combat",
		&"mus_hit_aftermath",
		&"mus_sting_victory",
		&"mus_sting_defeat",
	]:
		var ids: Array[StringName] = ScoreTransitions.voiced([id], EMBERFALL)
		assert_eq(ids[0], StringName("%s_%s" % [id, EMBERFALL]))
		assert_true(Audio.has_event(ids[0]), "%s re-voiced" % id)


# --- Advisor and interface --------------------------------------------------------


func test_advisor_kinds_route_to_their_phrases() -> void:
	var played: Array[StringName] = []
	var router: AudioEventRouter = AudioEventRouter.new()
	router.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		for id: StringName in ids:
			if Audio.has_event(id):
				played.append(id)
				return id
		return &""
	router.event_seconds = func(_id: StringName) -> float: return 1.0
	add_child_autofree(router)
	router.set_process(false)
	var now: float = 1000.0
	for kind: StringName in ADVISOR_KINDS:
		assert_true(router.offer_advisor_alert(kind, now), "%s accepted" % kind)
		now += 2.0
		router.pump_advisor(now)
	for kind: StringName in ADVISOR_KINDS:
		assert_true(played.has(StringName("advisor_%s" % kind)), "%s has its own phrase" % kind)


func test_advisor_priorities_throttles_and_replacements() -> void:
	var order: Array[StringName] = [
		&"under_attack",
		&"extraction_arrived",
		&"surge_incoming",
		&"eruption_warning",
		&"eruption_damage",
		&"wave_incoming",
		&"extraction_inbound",
	]
	for i: int in range(1, order.size()):
		assert_gt(
			AdvisorQueue.priority_of(order[i - 1]),
			AdvisorQueue.priority_of(order[i]),
			"%s before %s" % [order[i - 1], order[i]]
		)
	var queue: AdvisorQueue = AdvisorQueue.new()
	assert_true(queue.push(&"eruption_warning", 0.0))
	assert_eq(queue.pop_ready(0.0), &"eruption_warning")
	queue.started(0.0, 1.7)
	assert_false(queue.push(&"eruption_warning", 5.0), "a chain of vents does not nag")
	assert_true(queue.push(&"eruption_warning", 13.0), "heard again after its throttle")
	assert_true(queue.push(&"eruption_damage", 13.1), "damage replaces an unheard warning")
	assert_eq(queue.queued(), [&"eruption_damage"] as Array[StringName])
	var other: AdvisorQueue = AdvisorQueue.new()
	other.started(0.0, 3.0)  # busy: both wait
	assert_true(other.push(&"extraction_inbound", 0.5))
	assert_true(other.push(&"extraction_arrived", 1.0), "arrival is still heard")
	assert_eq(other.queued(), [&"extraction_arrived"] as Array[StringName], "inbound is moot")


func test_interface_and_eruption_events() -> void:
	var release: Array[StringName] = AudioCueSelector.feedback_event(&"vent_release")
	assert_eq(release, [&"ui_vent_release"] as Array[StringName])
	var denied: Array[StringName] = AudioCueSelector.feedback_event(&"vent_denied")
	assert_eq(denied, [&"ui_vent_denied", &"ui_invalid"] as Array[StringName])
	for id: StringName in [&"ui_vent_release", &"ui_vent_denied"]:
		assert_true(Audio.has_event(id), "%s exists" % id)
		assert_lte(Audio.get_event(id).longest_seconds(), 0.45, "short")
	for id: StringName in [
		EruptionCues.BUILD_LOW, EruptionCues.BUILD_HIGH, EruptionCues.KNOCK, EruptionCues.BLAST
	]:
		var event: SoundEvent = Audio.get_event(id)
		assert_not_null(event, String(id))
		assert_eq(event.bus, &"Weather", "the planet speaks on the Weather bus")
		assert_true(event.positional)
	for id: StringName in [HoldoutCues.MINUTE_CUE, HoldoutCues.ENGINE, HoldoutCues.ARRIVED]:
		assert_true(Audio.has_event(id), "%s exists" % id)


# --- Through the real service ------------------------------------------------------


func test_a_warning_near_the_base_raises_the_pressure_layer_through_audio() -> void:
	var eruption: EruptionSound = Audio.get_node(^"Eruption") as EruptionSound
	assert_not_null(eruption)
	Events.mission_started.emit()
	assert_eq(Audio.music().layer_gain_db(&"pressure"), AudioMix.SILENT_DB, "calm at first")
	var building: FakeBuilding = FakeBuilding.new()
	building.position = Vector3(10, 0, 0)
	building.add_to_group(EruptionSound.BUILDINGS_GROUP)
	add_child_autofree(building)
	var vent: FakeVent = FakeVent.new()
	vent.position = Vector3(20, 0, 0)
	add_child_autofree(vent)
	eruption.rescan_base()
	Events.eruption_warning.emit(vent, 4.0, 12.0)
	eruption.advance(0.1)
	assert_gt(Audio.music().layer_gain_db(&"pressure"), AudioMix.SILENT_DB, "the vent fills")
	Events.eruption.emit(vent, 12.0)
	assert_eq(Audio.music().layer_gain_db(&"pressure"), AudioMix.SILENT_DB, "it blew")
	Events.mission_started.emit()
