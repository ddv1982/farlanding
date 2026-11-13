extends GutTest
## DiscoverySoundRouter wired to the real Events bus, with playback captured;
## the BusDucker envelope; the trail music layer.


class FakeSite:
	extends Node3D
	var is_resolved: bool = false
	var discovery_type: StringName = &""


class FakeDiscovery:
	extends Resource
	var discovery_type: StringName = &"geological"


class FakeOption:
	extends Resource
	var id: StringName = &""


var _router: DiscoverySoundRouter
var _played: Array[StringName] = []
var _ducks: Array[float] = []
var _trail: Array[float] = []


func before_each() -> void:
	_played.clear()
	_ducks.clear()
	_trail.clear()
	_router = DiscoverySoundRouter.new()
	_router.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		for id: StringName in ids:
			if ResourceLoader.exists(_path_of(id)):
				_played.append(id)
				return id
		return &""
	_router.event_seconds = func(_id: StringName) -> float: return 3.4
	_router.duck = func(hold: float) -> void: _ducks.append(hold)
	_router.set_trail_gain = func(db: float) -> void: _trail.append(db)
	add_child_autofree(_router)


## Finds an event's .tres wherever its group put it.
func _path_of(id: StringName) -> String:
	for group: String in ["discovery", "sting", "ui", "field"]:
		var path: String = "res://data/sounds/%s/%s.tres" % [group, id]
		if ResourceLoader.exists(path):
			return path
	return "res://data/sounds/none/%s.tres" % id


func _discovery(kind: StringName) -> FakeDiscovery:
	var discovery: FakeDiscovery = FakeDiscovery.new()
	discovery.discovery_type = kind
	return discovery


func _site() -> FakeSite:
	var site: FakeSite = FakeSite.new()
	site.add_to_group(DiscoveryCues.SITES_GROUP)
	add_child_autofree(site)
	return site


## First, before any discovery_made in this file ducks the real Audio autoload.
func test_audio_service_ducks_the_music_bus() -> void:
	var music: int = AudioServer.get_bus_index(&"Music")
	var discovery: int = AudioServer.get_bus_index(&"Discovery")
	assert_ne(discovery, -1, "Discovery bus exists")
	# Other tests emit discovery_made, which the real Audio autoload hears too.
	await wait_until(func() -> bool: return Audio.duck_offset_db(&"Music") == 0.0, 10.0)
	var before: float = AudioServer.get_bus_volume_db(music)
	var phrase_before: float = AudioServer.get_bus_volume_db(discovery)
	Audio.duck_for(1.0)
	await wait_seconds(0.2)
	assert_lt(AudioServer.get_bus_volume_db(music), before - 4.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(discovery), phrase_before, 0.01)
	await wait_seconds(1.0 + BusDucker.RELEASE + 0.2)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), before, 0.01, "recovered")


func test_each_discovery_type_has_its_resolve_phrase() -> void:
	for kind: StringName in [&"geological", &"biological", &"antecedent", &"enemy"]:
		_played.clear()
		Events.discovery_made.emit(_site(), _discovery(kind), 0)
		assert_eq(_played[0], StringName("discovery_resolve_%s" % kind), String(kind))


func test_unknown_type_falls_back_and_site_type_is_used_when_needed() -> void:
	Events.discovery_made.emit(_site(), _discovery(&"strange"), 0)
	assert_eq(_played, [&"discovery_resolve_geological"] as Array[StringName])
	_played.clear()
	var site: FakeSite = _site()
	site.discovery_type = &"biological"
	Events.discovery_made.emit(site, Resource.new(), 0)
	assert_eq(_played, [&"discovery_resolve_biological"] as Array[StringName])


func test_resolve_ducks_for_the_phrase_and_antecedent_adds_the_swell() -> void:
	Events.discovery_made.emit(_site(), _discovery(&"antecedent"), 0)
	assert_eq(
		_played,
		[&"discovery_resolve_antecedent", DiscoveryCues.ANTECEDENT_SWELL] as Array[StringName]
	)
	assert_eq(_ducks.size(), 1)
	assert_almost_eq(_ducks[0], 3.4 - DiscoverySoundRouter.DUCK_TAIL_SECONDS, 0.001)


func test_other_factions_discoveries_are_silent_but_move_the_trail() -> void:
	var a: FakeSite = _site()
	_site()
	_trail.clear()
	a.is_resolved = true
	Events.discovery_made.emit(a, _discovery(&"enemy"), 1)
	assert_eq(_played.size(), 0)
	assert_eq(_ducks.size(), 0)
	assert_eq(_trail.size(), 1)
	assert_almost_eq(_trail[0], DiscoveryCues.trail_gain_db(1, 2), 0.001)


func test_trail_gain_rises_with_resolved_sites() -> void:
	assert_eq(DiscoveryCues.trail_gain_db(0, 4), AudioMix.SILENT_DB, "silent before the first")
	assert_almost_eq(DiscoveryCues.trail_gain_db(1, 4), -6.75, 0.001)
	assert_almost_eq(DiscoveryCues.trail_gain_db(4, 4), 0.0, 0.001)
	assert_eq(DiscoveryCues.trail_gain_db(0, 0), AudioMix.SILENT_DB)
	var site: FakeSite = _site()
	_site()
	_trail.clear()
	Events.discovery_made.emit(site, _discovery(&"geological"), 0)
	assert_almost_eq(_trail[0], DiscoveryCues.trail_gain_db(1, 2), 0.001, "flag not set yet")


func test_intel_ticks_only_when_the_players_intel_rises() -> void:
	Events.intel_changed.emit(0, 10)
	assert_eq(_played.size(), 0, "first report is the baseline")
	Events.intel_changed.emit(0, 15)
	Events.intel_changed.emit(0, 5)
	Events.intel_changed.emit(1, 50)
	assert_eq(_played, [DiscoveryCues.INTEL_TICK] as Array[StringName])


func test_field_options_play_their_effect() -> void:
	var expected: Dictionary[StringName, StringName] = {
		&"orbital_scan": &"field_orbital_scan",
		&"supply_drop": &"field_supply_drop",
		&"antecedent_power": &"field_antecedent_power",
		&"antecedent_lens": &"field_antecedent_power",
	}
	for id: StringName in expected:
		_played.clear()
		var option: FakeOption = FakeOption.new()
		option.id = id
		Events.field_option_used.emit(option, 0, Vector3.ZERO)
		assert_eq(_played, [expected[id]] as Array[StringName], String(id))
	_played.clear()
	var enemy: FakeOption = FakeOption.new()
	enemy.id = &"orbital_scan"
	Events.field_option_used.emit(enemy, 1, Vector3.ZERO)
	assert_eq(_played.size(), 0, "enemy options are not announced")


func test_codex_entry_and_codex_interface_sounds() -> void:
	Events.codex_entry_added.emit(Resource.new())
	assert_eq(_played, [DiscoveryCues.CODEX_ENTRY] as Array[StringName])
	for kind: StringName in [&"codex_open", &"codex_close", &"option_button"]:
		var ids: Array[StringName] = AudioCueSelector.feedback_event(kind)
		assert_true(ResourceLoader.exists(_path_of(ids[0])), "ui_feedback %s" % kind)


func test_ducker_envelope() -> void:
	var ducker: BusDucker = BusDucker.new()
	assert_eq(ducker.offset_db(&"Music", 0.0), 0.0)
	ducker.duck(10.0, 2.0)
	assert_eq(ducker.offset_db(&"Music", 10.0), 0.0, "attack starts at 0")
	assert_almost_eq(ducker.offset_db(&"Music", 10.5), BusDucker.DEPTH_DB[&"Music"], 0.001)
	assert_eq(ducker.offset_db(&"Discovery", 10.5), 0.0, "the phrase's own bus is untouched")
	assert_eq(ducker.offset_db(&"Advisor", 10.5), 0.0)
	var halfway: float = ducker.offset_db(&"SFX", 12.0 + BusDucker.RELEASE * 0.5)
	assert_almost_eq(halfway, BusDucker.DEPTH_DB[&"SFX"] * 0.5, 0.001, "release")
	assert_false(ducker.is_active(12.0 + BusDucker.RELEASE + 0.01))
	ducker.duck(20.0, 1.0)
	ducker.duck(20.5, 3.0)
	assert_true(ducker.is_active(23.2), "a second duck extends the first")
