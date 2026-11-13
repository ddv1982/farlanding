extends GutTest
## Phase 8d, Hollow Meridian: the planet as audio data, its ambience set, its
## score (the same states as the other planets, its own key, metre and
## material, and the three Core layers), the re-voiced hits and stings, the
## Advisor kinds of the last landing with their priorities, the Sentinel's
## sounds resolving by sound set, and the ending screen's own score. Signals are
## emitted by hand: gameplay does not need to exist for any of this.

const HOLLOW: StringName = &"hollow_meridian"
const SCORE: String = "res://data/sounds/music/hollow_meridian.tres"
const KESSEL_SCORE: String = "res://data/sounds/music/kessel_reach.tres"
const SHIP_SCORE: String = "res://data/sounds/music/meridian.tres"
const OTHER_SCORES: Array[String] = [
	"res://data/sounds/music/kessel_reach.tres",
	"res://data/sounds/music/thalassa_low.tres",
	"res://data/sounds/music/emberfall.tres",
	"res://data/sounds/music/verdance.tres",
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
const ADVISOR_KINDS: Array[StringName] = [
	&"engine_online", &"engine_lost", &"custodians_awake", &"core_charging", &"core_contested"
]
## The Sentinel's sound set (`def.sound_set` of custodian_sentinel) and a weapon
## data name starting with it.
const SENTINEL: StringName = &"sentinel"
const SENTINEL_WEAPON: StringName = &"sentinel_stone_bolt"
## The campaign's ending screen (`Events.campaign_screen_changed`).
const ENDING: StringName = &"ending"


class FakeUnit:
	extends Node3D
	var def: UnitDef
	var speed: float = 0.0
	var is_dormant: bool = true
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


func _hollow_set() -> AmbienceSet:
	return PlanetAudio.find(HOLLOW).ambience


func _players_playing(node: Node) -> int:
	var playing: int = 0
	for child: Node in node.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.playing:
			playing += 1
	return playing


# --- Planet and ambience ---------------------------------------------------------


func test_hollow_names_its_score_and_ambience() -> void:
	var planet: PlanetAudio = PlanetAudio.find(HOLLOW)
	assert_not_null(planet)
	assert_eq(planet.score.id, HOLLOW, "the score id is the planet id")
	assert_eq(planet.ambience.id, HOLLOW)
	for bed: AmbienceBed in planet.ambience.beds:
		assert_true(Audio.has_event(bed.event), "%s exists" % bed.event)
	for detail: AmbienceDetail in planet.ambience.details:
		assert_true(Audio.has_event(detail.event), "%s exists" % detail.event)


func test_play_planet_switches_to_hollow_meridian() -> void:
	Audio.play_planet(HOLLOW)
	assert_eq(Audio.music().target_score().id, HOLLOW)
	assert_eq(Audio.ambience().ambience_set().id, HOLLOW)
	Audio.play_score(load(KESSEL_SCORE) as MusicScore)  # back to Kessel at once


func test_beds_loop_at_different_lengths() -> void:
	_director.start(PlanetAudio.find(&"verdance").ambience)
	for i: int in 20:
		_director.advance(0.1)
	_director.start(_hollow_set())
	for i: int in 50:
		_director.advance(0.1)
	assert_eq(_director.bed_volume_db(&"amb_verdance_leaves"), AudioMix.SILENT_DB, "no leaves")
	assert_gt(_director.bed_volume_db(&"amb_hollow_hum"), -12.0, "the structure hums")
	assert_gt(_director.bed_volume_db(&"amb_hollow_air"), -12.0, "the air moves")
	assert_eq(_players_playing(_director), 3, "hum, air and machinery: no doubles, no hush")
	var lengths: Array[float] = []
	for bed: StringName in [&"amb_hollow_hum", &"amb_hollow_air", &"amb_hollow_machinery"]:
		var length: float = Audio.get_event(bed).longest_seconds()
		assert_gte(length, 30.0, "%s is a long loop" % bed)
		assert_false(lengths.has(snappedf(length, 0.1)), "%s has its own length" % bed)
		lengths.append(snappedf(length, 0.1))


func test_details_groan_click_fall_and_tick() -> void:
	_director._rng.seed = 11
	_director.start(_hollow_set())
	_director.settle()
	for i: int in 200:
		_director.play_detail(fmod(i * 0.377, 1.0))
	for id: StringName in [
		&"amb_metal_groan", &"amb_relay_click", &"amb_pebble_fall", &"amb_seam_tick"
	]:
		assert_gt(_details.count(id), 0, "%s is heard" % id)
	assert_false(_details.has(&"amb_canopy_call"), "nothing alive on the deck")
	assert_false(_details.has(&"amb_combine_industry"), "no base seen, no industry")
	assert_eq(Audio.get_event(&"amb_metal_groan").max_instances, 1, "one groan at a time")


# --- The score -------------------------------------------------------------------


func test_score_has_every_state_its_own_grid_and_the_core_layers() -> void:
	var score: MusicScore = load(SCORE)
	var kessel: MusicScore = load(KESSEL_SCORE)
	assert_eq(score.id, HOLLOW)
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
	for layer: StringName in CoreCues.LAYERS:
		assert_ne(Array(clip.layer_names).find(String(layer)), -1, "a %s layer" % layer)


func test_core_layers_are_silent_until_the_core_charges() -> void:
	var director: MusicDirector = MusicDirector.new()
	add_child_autofree(director)
	var core: CoreSound = CoreSound.new()
	core.set_music_gain = director.set_layer_gain
	add_child_autofree(core)
	director.play_score(load(SCORE) as MusicScore)
	var names: Array = Array(director.score.clips[0].layer_names)
	for layer: StringName in CoreCues.LAYERS:
		var index: int = names.find(String(layer))
		assert_eq(director.layer_targets_db(&"explore")[index], AudioMix.SILENT_DB, String(layer))
	core.handle_charge_changed(0.6)
	var targets: PackedFloat32Array = director.layer_targets_db(&"explore")
	assert_gt(targets[names.find("core_1")], -6.0, "a quarter: the heartbeat")
	assert_gt(targets[names.find("core_2")], -6.0, "a half: the motif climbing")
	assert_eq(targets[names.find("core_3")], AudioMix.SILENT_DB, "not yet three quarters")
	assert_eq(
		director.layer_targets_db(&"defeat")[names.find("core_1")],
		AudioMix.SILENT_DB,
		"a lost mission silences the Core"
	)
	director.stop()


func test_hits_and_stings_are_revoiced_for_hollow_meridian() -> void:
	for id: StringName in [
		&"mus_hit_combat",
		&"mus_hit_aftermath",
		&"mus_sting_victory",
		&"mus_sting_defeat",
	]:
		var ids: Array[StringName] = ScoreTransitions.voiced([id], HOLLOW)
		assert_eq(ids[0], StringName("%s_%s" % [id, HOLLOW]))
		assert_true(Audio.has_event(ids[0]), "%s re-voiced" % id)


# --- The ending screen -------------------------------------------------------------


func test_the_ending_screen_has_its_own_score() -> void:
	var music: ScreenMusic = ScreenMusic.find(ENDING)
	assert_not_null(music, "res://data/sounds/screens/ names the ending")
	assert_eq(music.score.id, &"ending")
	assert_not_null(music.score.find_state(music.state))
	var clip: MusicClip = music.score.clips[0]
	assert_between(clip.layers[0].get_length(), 50.0, 75.0, "about a minute")
	assert_null(ScreenMusic.find(&"star_map"), "other screens keep the ship theme")
	assert_null(ScreenMusic.find(&""))


func test_the_ending_screen_switches_the_score_and_back() -> void:
	var ship: MusicScore = load(SHIP_SCORE)
	Events.campaign_screen_changed.emit(ENDING)
	assert_eq(Audio.music().target_score().id, &"ending")
	assert_true(Audio.ambience().is_ship(), "aboard: the ship's ambience under it")
	Events.campaign_screen_changed.emit(&"star_map")
	assert_eq(Audio.music().target_score(), ship, "back to the ship theme")
	Events.campaign_screen_changed.emit(&"")
	Audio.music().stop_bed()
	Audio.play_score(load(KESSEL_SCORE) as MusicScore)


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
	var now: float = 3000.0
	for kind: StringName in ADVISOR_KINDS:
		assert_true(router.offer_advisor_alert(kind, now), "%s accepted" % kind)
		now += 2.0
		router.pump_advisor(now)
	for kind: StringName in ADVISOR_KINDS:
		assert_true(played.has(StringName("advisor_%s" % kind)), "%s has its own phrase" % kind)


func test_advisor_priorities_and_throttles() -> void:
	var order: Array[StringName] = [
		&"under_attack",
		&"core_contested",
		&"custodians_awake",
		&"engine_lost",
		&"core_charging",
		&"engine_online",
	]
	for i: int in range(1, order.size()):
		assert_gt(
			AdvisorQueue.priority_of(order[i - 1]),
			AdvisorQueue.priority_of(order[i]),
			"%s before %s" % [order[i - 1], order[i]]
		)
	var queue: AdvisorQueue = AdvisorQueue.new()
	assert_true(queue.push(&"core_charging", 0.0))
	assert_eq(queue.pop_ready(0.0), &"core_charging")
	queue.started(0.0, 1.6)
	assert_false(queue.push(&"core_charging", 20.0), "the Core charging does not nag")
	assert_true(queue.push(&"core_charging", 31.0))


func test_an_engine_flapping_unheard_says_nothing() -> void:
	var queue: AdvisorQueue = AdvisorQueue.new()
	assert_true(queue.push(&"under_attack", 0.0))
	assert_eq(queue.pop_ready(0.0), &"under_attack")
	queue.started(0.0, 1.5)
	queue.push(&"engine_online", 0.5)
	queue.push(&"engine_lost", 0.8)
	assert_eq(queue.pop_ready(2.0), &"", "online then lost while the Advisor spoke: both moot")


# --- The Sentinel ------------------------------------------------------------------


func _sentinel() -> FakeUnit:
	var unit: FakeUnit = FakeUnit.new()
	unit.def = UnitDef.new()
	unit.def.sound_set = SENTINEL
	add_child_autofree(unit)
	return unit


func test_sentinel_sounds_resolve_by_sound_set() -> void:
	var unit: FakeUnit = _sentinel()
	assert_eq(BaseLoops.hum_for(unit, false, Audio.has_event), &"loop_hum_sentinel", "dormant hum")
	for id: StringName in [&"move_sentinel", &"unit_sentinel_wake", &"death_sentinel"]:
		assert_true(Audio.has_event(id), String(id))
	assert_eq(CombatCues.death_events(unit)[0], &"death_sentinel")
	for data_name: StringName in [SENTINEL, SENTINEL_WEAPON]:
		var weapon: FakeWeapon = FakeWeapon.new()
		weapon.sound_set = data_name
		var found: StringName = &""
		for id: StringName in CombatCues.fire_events(weapon):
			if found == &"" and Audio.has_event(id):
				found = id
		assert_eq(found, &"weapon_sentinel_fire", "%s fires the charged bolt" % data_name)
	assert_eq(Audio.get_event(&"weapon_sentinel_fire").streams.size(), 3)


func test_sentinel_is_a_larger_warden() -> void:
	var warden: SoundEvent = Audio.get_event(&"move_warden")
	var sentinel: SoundEvent = Audio.get_event(&"move_sentinel")
	assert_gt(sentinel.max_distance, warden.max_distance, "heard further")
	assert_gt(
		Audio.get_event(&"death_sentinel").longest_seconds(),
		Audio.get_event(&"death_warden").longest_seconds(),
		"falls longer"
	)
	assert_gt(
		Audio.get_event(&"weapon_sentinel_fire").priority,
		Audio.get_event(&"weapon_warden_fire").priority,
		"a heavy weapon"
	)


func test_a_waking_sentinel_is_heard_once() -> void:
	var played: Array[StringName] = []
	var loops: BaseLoops = BaseLoops.new()
	loops.resolve_event = Audio.get_event
	loops.play_at = func(id: StringName, _at: Vector3) -> bool:
		played.append(id)
		return true
	add_child_autofree(loops)
	loops.set_process(false)
	var unit: FakeUnit = _sentinel()
	unit.add_to_group(BaseLoops.UNITS_GROUP)
	unit.global_position = Vector3(6, 0, 0)
	loops.rescan()
	assert_eq(played.size(), 0, "dormant: only its hum")
	unit.is_dormant = false
	loops.rescan()
	loops.rescan()
	assert_eq(played, [&"unit_sentinel_wake"] as Array[StringName])
