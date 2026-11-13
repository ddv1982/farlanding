extends GutTest
## Phase 8a, Thalassa Low: the planet as audio data (PlanetAudio), the ambience
## sets (Kessel unchanged, Thalassa's own beds and details), the Thalassa score,
## the new Advisor, interface and transition sounds, the artefact hum, and the
## tide layer through the real `Audio` autoload. Signals are emitted by hand:
## gameplay does not need to exist for any of this.

const EVENTS_DIR: String = "res://data/sounds"
const KESSEL: StringName = &"kessel_reach"
const THALASSA: StringName = &"thalassa_low"
const TIDE_LAYER: StringName = &"tide"
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
	&"tide_rising", &"tide_falling", &"units_in_water", &"artefact_taken", &"artefact_secured"
]


class FakeMission:
	extends Resource
	var planet: Resource


class FakePlanet:
	extends Resource
	var id: StringName = &""


class FakeMap:
	extends Node
	var mission: Resource


class Artefact:
	extends Node3D


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


func _thalassa_set() -> AmbienceSet:
	return PlanetAudio.find(THALASSA).ambience


# --- Planets as data --------------------------------------------------------------


func test_each_planet_names_its_score_and_ambience() -> void:
	var kessel: PlanetAudio = PlanetAudio.find(KESSEL)
	var thalassa: PlanetAudio = PlanetAudio.find(THALASSA)
	assert_not_null(kessel)
	assert_not_null(thalassa)
	assert_eq(kessel.score.id, KESSEL)
	assert_eq(thalassa.score.id, THALASSA, "the score id is the planet id")
	assert_eq(kessel.ambience.id, KESSEL)
	assert_eq(thalassa.ambience.id, THALASSA)
	assert_null(PlanetAudio.find(&"emberfall"), "a planet without a file has none")
	assert_eq(PlanetAudio.find_or_default(&"emberfall"), kessel, "and falls back to Kessel")
	assert_eq(kessel.ambience, AmbienceCues.kessel(), "one Kessel set")


func test_the_planet_is_read_from_the_running_map() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	assert_eq(PlanetAudio.planet_id_in(root), &"", "no map, no planet")
	var map: FakeMap = FakeMap.new()
	root.add_child(map)
	assert_eq(PlanetAudio.planet_id_in(root), &"", "a map without a mission")
	var mission: FakeMission = FakeMission.new()
	var planet: FakePlanet = FakePlanet.new()
	planet.id = THALASSA
	mission.planet = planet
	map.mission = mission
	assert_eq(PlanetAudio.planet_id_in(root), THALASSA)


func test_play_planet_switches_the_score_and_the_ambience() -> void:
	Audio.play_planet(THALASSA)
	assert_eq(Audio.music().target_score().id, THALASSA)
	assert_eq(Audio.ambience().ambience_set().id, THALASSA)
	Audio.play_planet(&"emberfall")
	assert_eq(Audio.music().target_score().id, THALASSA, "an unknown planet changes nothing")
	Audio.play_planet(KESSEL)
	assert_eq(Audio.music().target_score().id, KESSEL)
	assert_eq(Audio.ambience().ambience_set().id, KESSEL)
	Audio.play_score(load(KESSEL_SCORE) as MusicScore)  # leave Kessel playing, cut (no fade pending)


# --- Ambience sets ---------------------------------------------------------------


func test_kessel_weights_are_unchanged() -> void:
	# The Phase 6 formula, written out: data must reproduce it exactly.
	for context: Dictionary in [
		{},
		{AmbienceCues.VENT_NEAR: 0.7, AmbienceCues.STORM: 0.3},
		{AmbienceCues.BASE_NEAR: 1.0, AmbienceCues.SITE_NEAR: 0.5},
	]:
		var vent: float = context.get(AmbienceCues.VENT_NEAR, 0.0)
		var base: float = context.get(AmbienceCues.BASE_NEAR, 0.0)
		var storm: float = context.get(AmbienceCues.STORM, 0.0)
		var site: float = context.get(AmbienceCues.SITE_NEAR, 0.0)
		var calm: float = 1.0 - 0.75 * site
		var weights: Dictionary[StringName, float] = AmbienceCues.detail_weights(context)
		assert_eq(
			weights.keys(),
			[AmbienceCues.ROCK, AmbienceCues.VENT, AmbienceCues.DEVIL, AmbienceCues.INDUSTRY],
			"the old pick order"
		)
		assert_almost_eq(weights[AmbienceCues.ROCK], calm, 0.00001)
		assert_almost_eq(weights[AmbienceCues.VENT], (0.08 + 2.2 * vent) * calm, 0.00001)
		assert_almost_eq(weights[AmbienceCues.DEVIL], 0.45 * (1.0 - storm) * calm, 0.00001)
		assert_almost_eq(weights[AmbienceCues.INDUSTRY], 2.6 * base * calm, 0.00001)
	assert_eq(AmbienceCues.bed_db(AmbienceCues.BED_WIND, -2.0, {}), -2.0, "no tide on Kessel")


func test_the_tide_moves_thalassa_details_and_beds() -> void:
	var amb: AmbienceSet = _thalassa_set()
	var low: Dictionary[StringName, float] = AmbienceCues.detail_weights(
		{AmbienceCues.TIDE: 0.0}, amb
	)
	var high: Dictionary[StringName, float] = AmbienceCues.detail_weights(
		{AmbienceCues.TIDE: 1.0}, amb
	)
	assert_gt(high[&"amb_water_lap"], low[&"amb_water_lap"], "water laps at high water")
	assert_gt(low[&"amb_shell_click"], high[&"amb_shell_click"], "shells click at low water")
	assert_lt(low[&"amb_shore_call"], low[&"amb_water_lap"] + low[&"amb_shell_click"], "sparse")
	assert_gt(
		AmbienceCues.bed_db(&"amb_thalassa_surf", 0.0, {AmbienceCues.TIDE: 1.0}, amb),
		AmbienceCues.bed_db(&"amb_thalassa_surf", 0.0, {AmbienceCues.TIDE: 0.0}, amb),
		"the surf comes closer at high water"
	)
	for detail: AmbienceDetail in amb.details:
		assert_true(Audio.has_event(detail.event), "%s exists" % detail.event)
	for bed: AmbienceBed in amb.beds:
		assert_true(Audio.has_event(bed.event), "%s exists" % bed.event)


func test_thalassa_beds_replace_kessel_beds() -> void:
	_director.start(null)
	for i: int in 30:
		_director.advance(0.1)
	assert_gt(_director.bed_volume_db(AmbienceCues.BED_WIND), AudioMix.SILENT_DB)
	_director.start(_thalassa_set())
	for i: int in 50:
		_director.advance(0.1)
	assert_eq(_director.bed_volume_db(AmbienceCues.BED_WIND), AudioMix.SILENT_DB, "Kessel gone")
	assert_gt(_director.bed_volume_db(&"amb_thalassa_wind"), -12.0, "the wind over water")
	assert_gt(_director.bed_volume_db(&"amb_thalassa_drone"), -20.0, "the tidal drone")
	var playing: int = 0
	for child: Node in _director.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.playing:
			playing += 1
	assert_eq(playing, 3, "wind, surf and drone: no double beds, no hush")
	_director.start(_thalassa_set())  # the same planet again
	for i: int in 5:
		_director.advance(0.1)
	playing = 0
	for child: Node in _director.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.playing:
			playing += 1
	assert_eq(playing, 3, "starting it again starts nothing twice")


func test_thalassa_details_follow_the_water() -> void:
	_director._rng.seed = 7  # bounds below are for one known run
	_director.start(_thalassa_set())
	_director.set_tide(1.0)
	_director.settle()
	for i: int in 200:
		_director.play_detail(fmod(i * 0.377, 1.0))
	var laps: int = _details.count(&"amb_water_lap")
	var clicks: int = _details.count(&"amb_shell_click")
	assert_gt(laps, clicks, "high water: lapping")
	assert_false(_details.has(&"amb_combine_industry"), "no base seen, no industry")
	assert_false(_details.has(AmbienceCues.ROCK), "no Kessel rock on Thalassa")
	_details.clear()
	_director.set_tide(0.0)
	_director.settle()
	for i: int in 200:
		_director.play_detail(fmod(i * 0.377, 1.0))
	assert_gt(_details.count(&"amb_shell_click"), _details.count(&"amb_water_lap"), "low water")


# --- The score and its sounds --------------------------------------------------


func test_thalassa_score_has_every_state_and_a_tide_layer() -> void:
	var score: MusicScore = load(THALASSA_SCORE)
	var kessel: MusicScore = load(KESSEL_SCORE)
	assert_eq(score.id, THALASSA)
	assert_ne(score.bpm, kessel.bpm, "its own tempo")
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
	assert_ne(Array(clip.layer_names).find("tide"), -1, "a tide layer")
	for layer_name: String in ["urgency", "trail", "hush", "watch", "heavy"]:
		assert_ne(Array(clip.layer_names).find(layer_name), -1, "%s as on Kessel" % layer_name)


func test_the_tide_layer_follows_the_water_through_audio() -> void:
	var director: MusicDirector = MusicDirector.new()
	add_child_autofree(director)
	director.set_layer_gain(TIDE_LAYER, AudioMix.SILENT_DB)
	director.play_score(load(THALASSA_SCORE) as MusicScore)
	var tide: int = Array(director.score.clips[0].layer_names).find("tide")
	assert_eq(director.layer_targets_db(&"explore")[tide], AudioMix.SILENT_DB, "dry at first")
	director.set_layer_gain(TIDE_LAYER, TideCues.music_gain_db(0.9))
	assert_almost_eq(director.layer_targets_db(&"explore")[tide], TideCues.MUSIC_TOP_DB, 0.01)
	director.stop()
	# The real service: a reported tide reaches the score's layer gain.
	var sound: TideSound = Audio.get_node(^"Tide") as TideSound
	Events.mission_started.emit()
	Events.tide_changed.emit(0.85)
	sound.advance(0.1)
	assert_gt(Audio.music().layer_gain_db(TIDE_LAYER), AudioMix.SILENT_DB)
	Events.mission_started.emit()
	assert_eq(Audio.music().layer_gain_db(TIDE_LAYER), AudioMix.SILENT_DB)


func test_hits_and_stings_are_revoiced_for_thalassa() -> void:
	var hits: Array[StringName] = ScoreTransitions.voiced([&"mus_hit_combat"], THALASSA)
	assert_eq(hits, [&"mus_hit_combat_thalassa_low", &"mus_hit_combat"] as Array[StringName])
	var generic: Array[StringName] = [&"mus_hit_combat"]
	assert_eq(ScoreTransitions.voiced(generic, &""), generic, "no score, no variant")
	for id: StringName in [
		&"mus_hit_combat",
		&"mus_hit_aftermath",
		&"mus_sting_victory",
		&"mus_sting_defeat",
	]:
		assert_true(Audio.has_event(StringName("%s_%s" % [id, THALASSA])), "%s re-voiced" % id)
		assert_false(Audio.has_event(StringName("%s_%s" % [id, KESSEL])), "Kessel uses its own")


# --- Advisor, interface, artefact -----------------------------------------------


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


func test_advisor_priorities_and_throttles() -> void:
	var queue: AdvisorQueue = AdvisorQueue.new()
	assert_gt(AdvisorQueue.priority_of(&"artefact_taken"), AdvisorQueue.priority_of(&"tide_rising"))
	assert_gt(AdvisorQueue.priority_of(&"tide_rising"), AdvisorQueue.priority_of(&"tide_falling"))
	assert_lt(AdvisorQueue.priority_of(&"tide_rising"), AdvisorQueue.priority_of(&"under_attack"))
	assert_true(queue.push(&"tide_rising", 0.0))
	assert_eq(queue.pop_ready(0.0), &"tide_rising")
	queue.started(0.0, 1.5)
	assert_false(queue.push(&"tide_rising", 10.0), "throttled")
	assert_true(queue.push(&"tide_rising", 21.0), "heard again after its throttle")
	assert_false(queue.push(&"tide_falling", 21.1), "an unheard turn cancels its opposite")
	assert_eq(queue.queued().size(), 0)
	assert_true(queue.push(&"units_in_water", 30.0))
	assert_false(queue.push(&"units_in_water", 40.0), "units in water does not nag")
	assert_true(queue.push(&"artefact_taken", 50.0))
	assert_true(queue.push(&"artefact_secured", 50.1), "taken then secured: both heard")
	assert_eq(queue.pop_ready(51.0), &"artefact_taken", "the loss first")


func test_interface_kinds_have_their_sounds() -> void:
	for kind: StringName in [&"artefact_pickup", &"artefact_drop"]:
		var ids: Array[StringName] = AudioCueSelector.feedback_event(kind)
		assert_eq(ids[0], StringName("ui_%s" % kind))
		assert_true(Audio.has_event(ids[0]), "%s exists" % ids[0])
	for id: StringName in [TideCues.TURN_RISING, TideCues.TURN_FALLING]:
		var event: SoundEvent = Audio.get_event(id)
		assert_not_null(event)
		assert_eq(event.bus, &"Weather")
		assert_false(event.positional, "the warning is heard wherever the camera is")


func test_a_carried_artefact_hums() -> void:
	var artefact: Artefact = Artefact.new()
	assert_eq(BaseLoops.artefact_hum(artefact), &"loop_hum_artefact")
	artefact.free()
	var event: SoundEvent = Audio.get_event(&"loop_hum_artefact")
	assert_not_null(event)
	assert_true(event.positional)
	var loops: BaseLoops = BaseLoops.new()
	loops.resolve_event = Audio.get_event
	add_child_autofree(loops)
	loops.set_process(false)
	var carried: Artefact = Artefact.new()
	carried.position = Vector3(5.0, 0.0, 0.0)
	carried.add_to_group(BaseLoops.ARTEFACTS_GROUP)
	add_child_autofree(carried)
	loops.focus = Vector3.ZERO
	loops.rescan()
	var hums: Array = loops.chosen().filter(func(pair: Array) -> bool: return pair[0] == carried)
	assert_eq(hums.size(), 1, "the artefact carries one loop")
	var pair: Array = hums[0]
	var hum: StringName = pair[1]
	assert_eq(hum, &"loop_hum_artefact")
