extends GutTest
## Phase 8c, Verdance: the planet as audio data, its ambience set, its score
## (same states as the other planets, its own key, metre and material), the
## re-voiced hits and stings, the Advisor kinds of the air war with their
## priorities, and the first air units (replies, engines that never stop,
## weapons, deaths) resolving through the real `Audio` autoload. Signals are
## emitted by hand: gameplay does not need to exist for any of this.

const VERDANCE: StringName = &"verdance"
const SCORE: String = "res://data/sounds/music/verdance.tres"
const KESSEL_SCORE: String = "res://data/sounds/music/kessel_reach.tres"
const OTHER_SCORES: Array[String] = [
	"res://data/sounds/music/kessel_reach.tres",
	"res://data/sounds/music/thalassa_low.tres",
	"res://data/sounds/music/emberfall.tres",
]
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
const ADVISOR_KINDS: Array[StringName] = [&"canopy_contact", &"air_contact", &"air_lost"]
## Sound sets of the air units (`def.sound_set` of concord_talon, combine_hornet).
const AIR_SETS: Array[StringName] = [&"talon", &"hornet"]


class FakeUnit:
	extends Node3D
	var def: UnitDef
	var speed: float = 0.0
	var is_visible_to_player: bool = true


class FakeWeapon:
	extends Resource
	var sound_set: StringName = &""
	var impact_size: float = 0.0


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


func _verdance_set() -> AmbienceSet:
	return PlanetAudio.find(VERDANCE).ambience


func _players_playing(node: Node) -> int:
	var playing: int = 0
	for child: Node in node.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.playing:
			playing += 1
	return playing


# --- Planet and ambience ---------------------------------------------------------


func test_verdance_names_its_score_and_ambience() -> void:
	var planet: PlanetAudio = PlanetAudio.find(VERDANCE)
	assert_not_null(planet)
	assert_eq(planet.score.id, VERDANCE, "the score id is the planet id")
	assert_eq(planet.ambience.id, VERDANCE)
	for bed: AmbienceBed in planet.ambience.beds:
		assert_true(Audio.has_event(bed.event), "%s exists" % bed.event)
	for detail: AmbienceDetail in planet.ambience.details:
		assert_true(Audio.has_event(detail.event), "%s exists" % detail.event)


func test_play_planet_switches_to_verdance() -> void:
	Audio.play_planet(VERDANCE)
	assert_eq(Audio.music().target_score().id, VERDANCE)
	assert_eq(Audio.ambience().ambience_set().id, VERDANCE)
	Audio.play_score(load(KESSEL_SCORE) as MusicScore)  # back to Kessel at once


func test_verdance_beds_loop_at_different_lengths_without_doubling() -> void:
	_director.start(PlanetAudio.find(&"emberfall").ambience)
	for i: int in 20:
		_director.advance(0.1)
	_director.start(_verdance_set())
	for i: int in 50:
		_director.advance(0.1)
	assert_eq(
		_director.bed_volume_db(&"amb_emberfall_rumble"), AudioMix.SILENT_DB, "Emberfall gone"
	)
	assert_gt(_director.bed_volume_db(&"amb_verdance_leaves"), -12.0, "the leaves move")
	assert_gt(_director.bed_volume_db(&"amb_verdance_chorus"), -20.0, "something is alive")
	assert_eq(_players_playing(_director), 3, "leaves, chorus and stream: no doubles, no hush")
	var lengths: Array[float] = []
	for bed: StringName in [&"amb_verdance_leaves", &"amb_verdance_chorus", &"amb_verdance_stream"]:
		var length: float = Audio.get_event(bed).longest_seconds()
		assert_gte(length, 25.0, "%s is a long loop" % bed)
		assert_false(lengths.has(snappedf(length, 0.1)), "%s has its own length" % bed)
		lengths.append(snappedf(length, 0.1))


func test_details_creak_call_drip_and_take_off() -> void:
	var amb: AmbienceSet = _verdance_set()
	_director._rng.seed = 7
	_director.start(amb)
	_director.settle()
	for i: int in 200:
		_director.play_detail(fmod(i * 0.377, 1.0))
	for id: StringName in [
		&"amb_branch_creak", &"amb_canopy_call", &"amb_leaf_drip", &"amb_wing_flurry"
	]:
		assert_gt(_details.count(id), 0, "%s is heard" % id)
	assert_false(_details.has(&"amb_rock_crack"), "no Emberfall rock on Verdance")
	assert_false(_details.has(&"amb_water_lap"), "no Thalassa sea")
	assert_false(_details.has(&"amb_combine_industry"), "no base seen, no industry")
	assert_eq(Audio.get_event(&"amb_canopy_call").max_instances, 1, "one call at a time")


# --- The score -------------------------------------------------------------------


func test_verdance_score_has_every_state_and_its_own_grid() -> void:
	var score: MusicScore = load(SCORE)
	var kessel: MusicScore = load(KESSEL_SCORE)
	assert_eq(score.id, VERDANCE)
	for path: String in OTHER_SCORES:
		assert_ne(score.bpm, (load(path) as MusicScore).bpm, "its own tempo (%s)" % path)
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
	for layer_name: String in ["urgency", "trail", "hush", "watch", "heavy", "melody_b", "drums_b"]:
		assert_ne(Array(clip.layer_names).find(layer_name), -1, "a %s layer" % layer_name)


func test_the_urgency_layer_is_silent_until_driven() -> void:
	var director: MusicDirector = MusicDirector.new()
	add_child_autofree(director)
	director.set_layer_gain(&"urgency", AudioMix.SILENT_DB)
	director.play_score(load(SCORE) as MusicScore)
	var urgency: int = Array(director.score.clips[0].layer_names).find("urgency")
	assert_eq(director.layer_targets_db(&"combat")[urgency], AudioMix.SILENT_DB)
	director.set_layer_gain(&"urgency", 0.0)
	assert_gt(director.layer_targets_db(&"combat")[urgency], -6.0, "the base is hit")
	director.stop()


func test_hits_and_stings_are_revoiced_for_verdance() -> void:
	for id: StringName in [
		&"mus_hit_combat",
		&"mus_hit_aftermath",
		&"mus_sting_victory",
		&"mus_sting_defeat",
	]:
		var ids: Array[StringName] = ScoreTransitions.voiced([id], VERDANCE)
		assert_eq(ids[0], StringName("%s_%s" % [id, VERDANCE]))
		assert_true(Audio.has_event(ids[0]), "%s re-voiced" % id)


# --- Advisor ---------------------------------------------------------------------


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
	var now: float = 2000.0
	for kind: StringName in ADVISOR_KINDS:
		assert_true(router.offer_advisor_alert(kind, now), "%s accepted" % kind)
		now += 2.0
		router.pump_advisor(now)
	for kind: StringName in ADVISOR_KINDS:
		assert_true(played.has(StringName("advisor_%s" % kind)), "%s has its own phrase" % kind)


func test_advisor_priorities_and_throttles() -> void:
	var order: Array[StringName] = [
		&"under_attack", &"air_contact", &"canopy_contact", &"wave_incoming", &"air_lost"
	]
	for i: int in range(1, order.size()):
		assert_gt(
			AdvisorQueue.priority_of(order[i - 1]),
			AdvisorQueue.priority_of(order[i]),
			"%s before %s" % [order[i - 1], order[i]]
		)
	var queue: AdvisorQueue = AdvisorQueue.new()
	assert_true(queue.push(&"air_contact", 0.0))
	assert_eq(queue.pop_ready(0.0), &"air_contact")
	queue.started(0.0, 1.6)
	assert_false(queue.push(&"air_contact", 10.0), "a wing of gunships does not nag")
	assert_true(queue.push(&"air_contact", 26.0), "heard again after its throttle")
	assert_true(queue.push(&"air_lost", 26.1), "a loss is still news")
	assert_true(queue.push(&"canopy_contact", 26.2))
	assert_eq(queue.pop_ready(28.0), &"air_contact", "the threat first")


# --- Air units -------------------------------------------------------------------


func test_air_unit_replies_resolve_by_sound_set() -> void:
	var selector: AudioCueSelector = AudioCueSelector.new()
	var now: float = 10.0
	for sound_set: StringName in AIR_SETS:
		for kind: StringName in [&"select", &"move", &"attack"]:
			var id: StringName = AudioCueSelector.unit_event(sound_set, kind)
			var event: SoundEvent = Audio.get_event(id)
			assert_not_null(event, String(id))
			if event != null:
				assert_eq(event.bus, &"Barks")
				assert_eq(event.streams.size(), 3, "three variations of %s" % id)
		now += 1.0
		var picked: Array[StringName] = selector.on_selection([sound_set], now)
		assert_eq(picked[0], AudioCueSelector.unit_event(sound_set, &"select"))


func test_air_unit_weapons_and_deaths_resolve() -> void:
	for sound_set: StringName in AIR_SETS:
		# The weapon data's own name (talon_autocannon, hornet_dartgun) falls back to the family.
		var data: StringName = &"talon_autocannon" if sound_set == &"talon" else &"hornet_dartgun"
		for data_name: StringName in [sound_set, data]:
			var weapon: FakeWeapon = FakeWeapon.new()
			weapon.sound_set = data_name
			var found: bool = false
			for id: StringName in CombatCues.fire_events(weapon):
				found = found or Audio.has_event(id)
			assert_true(found, "%s fires a sound" % data_name)
		var unit: FakeUnit = FakeUnit.new()
		unit.def = UnitDef.new()
		unit.def.sound_set = sound_set
		add_child_autofree(unit)
		var death: StringName = CombatCues.death_events(unit)[0]
		assert_eq(death, StringName("death_%s" % sound_set), "falls and hits")
		assert_true(Audio.has_event(death))
		assert_gte(Audio.get_event(death).longest_seconds(), 2.0, "a fall, then the ground")


func test_air_engines_keep_running_while_they_hover() -> void:
	var loops: MovementLoops = MovementLoops.new()
	loops.resolve_event = Audio.get_event
	add_child_autofree(loops)
	loops.set_process(false)
	var ground: FakeUnit = FakeUnit.new()
	ground.def = UnitDef.new()
	ground.def.sound_set = &"ranger"
	ground.add_to_group(MovementLoops.UNITS_GROUP)
	add_child_autofree(ground)
	var last: FakeUnit = null
	for sound_set: StringName in AIR_SETS:
		var event: SoundEvent = Audio.get_event(StringName("move_%s" % sound_set))
		assert_not_null(event)
		assert_true(event.loops_at_rest, "move_%s loops at rest" % sound_set)
		var air: FakeUnit = FakeUnit.new()
		air.def = UnitDef.new()
		air.def.sound_set = sound_set
		air.position = Vector3(4, 13, 0)
		air.add_to_group(MovementLoops.UNITS_GROUP)
		add_child_autofree(air)
		last = air
	loops._rescan()
	loops._process(0.5)
	assert_eq(loops.active_count(), 2, "both aircraft hover audibly, the idle Ranger is silent")
	last.is_visible_to_player = false
	loops._rescan()
	loops._process(1.0)
	assert_eq(loops.active_count(), 1, "an aircraft in the fog is not heard")
	assert_false(Audio.get_event(&"move_ranger").loops_at_rest, "ground chassis stop at rest")


# --- Canopy ----------------------------------------------------------------------


func test_canopy_rustles_are_positional_and_short() -> void:
	for id: StringName in [CanopyCues.RUSTLE_IN, CanopyCues.RUSTLE_OUT]:
		var event: SoundEvent = Audio.get_event(id)
		assert_not_null(event, String(id))
		if event != null:
			assert_true(event.positional)
			assert_eq(event.bus, &"Units")
			assert_lte(event.longest_seconds(), 1.0, "a gesture, not a bed")
	assert_lt(
		Audio.get_event(CanopyCues.RUSTLE_OUT).longest_seconds(),
		Audio.get_event(CanopyCues.RUSTLE_IN).longest_seconds(),
		"coming out is lighter than going in"
	)
