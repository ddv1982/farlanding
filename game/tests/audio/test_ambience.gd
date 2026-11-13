extends GutTest
## Phase 6 ambience: AmbienceCues (variation, weights, beds) and the
## AmbienceDirector driven with stubs.

const EVENTS_DIR: String = "res://data/sounds"

var _director: AmbienceDirector
var _details: Array[StringName] = []
var _positions: Array[Vector3] = []


func before_each() -> void:
	_details.clear()
	_positions.clear()
	_director = AmbienceDirector.new()
	_director.resolve_event = func(id: StringName) -> SoundEvent:
		var path: String = "%s/ambience/%s.tres" % [EVENTS_DIR, id]
		return load(path) as SoundEvent if ResourceLoader.exists(path) else null
	_director.play_at = func(id: StringName, at: Vector3, _db: float) -> bool:
		_details.append(id)
		_positions.append(at)
		return true
	add_child_autofree(_director)
	_director.set_process(false)
	_director.auto_scan = false


func after_each() -> void:
	_director.stop()


# --- Pure rules -------------------------------------------------------------------


func test_nearness() -> void:
	assert_eq(AmbienceCues.nearness(INF, AmbienceCues.NEAR_SITE), 0.0)
	assert_eq(AmbienceCues.nearness(0.0, AmbienceCues.NEAR_SITE), 1.0)
	assert_eq(AmbienceCues.nearness(500.0, AmbienceCues.NEAR_SITE), 0.0)
	var mid: float = AmbienceCues.nearness(40.0, AmbienceCues.NEAR_SITE)
	assert_between(mid, 0.01, 0.99)


func test_weights_follow_the_place() -> void:
	var open: Dictionary[StringName, float] = AmbienceCues.detail_weights({})
	assert_eq(open[AmbienceCues.INDUSTRY], 0.0, "no Combine industry without a seen base")
	assert_gt(open[AmbienceCues.ROCK], 0.0)
	assert_gt(open[AmbienceCues.DEVIL], 0.0)
	var base: Dictionary[StringName, float] = AmbienceCues.detail_weights(
		{AmbienceCues.BASE_NEAR: 1.0}
	)
	assert_gt(
		base[AmbienceCues.INDUSTRY], base[AmbienceCues.ROCK], "near their base, their industry"
	)
	var vent: Dictionary[StringName, float] = AmbienceCues.detail_weights(
		{AmbienceCues.VENT_NEAR: 1.0}
	)
	assert_gt(vent[AmbienceCues.VENT], vent[AmbienceCues.ROCK])
	var storm: Dictionary[StringName, float] = AmbienceCues.detail_weights(
		{AmbienceCues.STORM: 1.0}
	)
	assert_eq(storm[AmbienceCues.DEVIL], 0.0, "no dust devils inside a storm")
	var site: Dictionary[StringName, float] = AmbienceCues.detail_weights(
		{AmbienceCues.SITE_NEAR: 1.0}
	)
	assert_lt(site[AmbienceCues.ROCK], open[AmbienceCues.ROCK], "the hush quiets the details")


func test_pick_never_repeats_when_another_kind_is_possible() -> void:
	var weights: Dictionary[StringName, float] = AmbienceCues.detail_weights(
		{AmbienceCues.BASE_NEAR: 1.0, AmbienceCues.VENT_NEAR: 0.5}
	)
	var last: StringName = &""
	var seen: Dictionary[StringName, int] = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	for i: int in 400:
		var kind: StringName = AmbienceCues.pick(weights, rng.randf(), last)
		assert_ne(kind, last)
		seen[kind] = seen.get(kind, 0) + 1
		last = kind
	assert_eq(seen.size(), 4, "every kind turns up")
	var only_rock: Dictionary[StringName, float] = {AmbienceCues.ROCK: 1.0}
	assert_eq(AmbienceCues.pick(only_rock, 0.5, AmbienceCues.ROCK), AmbienceCues.ROCK, "or repeats")
	assert_eq(AmbienceCues.pick({}, 0.5, &""), &"")


func test_gaps_and_wander_ranges() -> void:
	var calm: float = AmbienceCues.detail_gap({}, 0.5)
	assert_between(calm, AmbienceCues.DETAIL_GAP.x, AmbienceCues.DETAIL_GAP.y)
	assert_gt(
		AmbienceCues.detail_gap({AmbienceCues.SITE_NEAR: 1.0}, 0.5), calm, "the hush is sparser"
	)
	assert_gt(AmbienceCues.detail_gap({AmbienceCues.STORM: 1.0}, 0.5), calm * 3.0)
	for roll: float in [0.0, 0.3, 0.99]:
		var db: float = AmbienceCues.wander_target_db(AmbienceCues.BED_WIND, roll)
		assert_between(db, -5.0, 0.0)
	assert_eq(AmbienceCues.bed_db(AmbienceCues.BED_HUSH, 0.0, {}), AudioMix.SILENT_DB)
	assert_gt(AmbienceCues.bed_db(AmbienceCues.BED_HUSH, 0.0, {AmbienceCues.SITE_NEAR: 1.0}), -1.0)
	var near_site: float = AmbienceCues.bed_db(
		AmbienceCues.BED_WIND, 0.0, {AmbienceCues.SITE_NEAR: 1.0}
	)
	assert_lt(near_site, -5.0, "the wind steps back at a site")
	var in_storm: float = AmbienceCues.bed_db(AmbienceCues.BED_WIND, 0.0, {AmbienceCues.STORM: 1.0})
	assert_lt(in_storm, -12.0, "the storm covers the planet's air")


# --- The director -----------------------------------------------------------------


func test_two_minutes_never_sound_the_same() -> void:
	_director._rng.seed = 20261113  # the counts below are bounds on one known run
	_director.start(null)
	_director.set_nearness(0.4, 0.6, 0.0)
	_director.settle()
	var wind_levels: Array[float] = []
	for i: int in 1200:  # two minutes in 0.1 s steps
		_director.advance(0.1)
		if i % 50 == 0:
			wind_levels.append(_director.bed_volume_db(AmbienceCues.BED_AIR))
	assert_gt(_details.size(), 7, "a detail every few seconds")
	assert_lt(_details.size(), 25, "but never busy")
	var kinds: Dictionary[StringName, bool] = {}
	for i: int in _details.size():
		kinds[_details[i]] = true
		if i > 0:
			assert_ne(_details[i], _details[i - 1], "no kind twice in a row")
	assert_gt(kinds.size(), 2)
	var lowest: float = wind_levels.min()
	var highest: float = wind_levels.max()
	assert_gt(highest - lowest, 1.0, "the beds wander")


func test_industry_plays_at_the_seen_base_only() -> void:
	_director.set_nearness(0.0, 0.0, 0.0)
	_director.settle()
	for i: int in 200:
		_director.play_detail(fmod(i * 0.37, 1.0))
	assert_false(_details.has(AmbienceCues.INDUSTRY))


func test_hush_rises_near_an_antecedent_site() -> void:
	_director.start(null)
	_director.set_nearness(0.0, 0.0, 1.0)
	_director.settle()
	for i: int in 60:
		_director.advance(0.1)
	assert_gt(_director.bed_volume_db(AmbienceCues.BED_HUSH), -3.0)
	_director.set_nearness(0.0, 0.0, 0.0)
	_director.settle()
	_director.advance(0.1)
	assert_eq(_director.bed_volume_db(AmbienceCues.BED_HUSH), AudioMix.SILENT_DB)


func test_storm_cover_lowers_the_beds() -> void:
	_director.start(null)
	for i: int in 60:
		_director.advance(0.1)
	var clear: float = _director.bed_volume_db(AmbienceCues.BED_AIR)
	_director.set_storm_cover(1.0)
	_director.settle()
	_director.advance(0.1)
	assert_lt(_director.bed_volume_db(AmbienceCues.BED_AIR), clear - 10.0)


func test_scan_reads_the_scene() -> void:
	var vent: FakeVent = FakeVent.new()
	add_child_autofree(vent)
	vent.add_to_group(&"resource_nodes")
	vent.position = Vector3(5.0, 0.0, 0.0)
	var base: FakeBuilding = FakeBuilding.new()
	add_child_autofree(base)
	base.add_to_group(&"buildings")
	base.position = Vector3(30.0, 0.0, 0.0)
	_director.focus = Vector3.ZERO
	base.is_visible_to_player = false
	_director.scan()
	_director.settle()
	var context: Dictionary = _director.context()
	var vent_near: float = context[AmbienceCues.VENT_NEAR]
	var base_near: float = context[AmbienceCues.BASE_NEAR]
	assert_almost_eq(vent_near, 1.0, 0.001)
	assert_eq(base_near, 0.0, "an unseen base gives nothing away")
	base.is_visible_to_player = true
	_director.scan()
	base.is_visible_to_player = false
	_director.scan()
	_director.settle()
	context = _director.context()
	base_near = context[AmbienceCues.BASE_NEAR]
	assert_almost_eq(base_near, 1.0, 0.001, "once seen, remembered")
	_director.handle_mission_started()
	_director.scan()
	_director.settle()
	context = _director.context()
	base_near = context[AmbienceCues.BASE_NEAR]
	assert_eq(base_near, 0.0, "a new mission forgets")


class FakeVent:
	extends Node3D

	func resource() -> StringName:
		return &"flux"


class FakeBuilding:
	extends Node3D
	var faction: int = 1
	var is_visible_to_player: bool = true
