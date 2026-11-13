extends GutTest
## Phase 6 routing through the real `Audio` autoload and bus layout: the storm
## muffle and its restoration, the pause and menu overlays, the new events and
## their buses, prop deaths, the enemy Intel cue and the new Advisor kinds.

const EVENTS_DIR: String = "res://data/sounds"


func after_each() -> void:
	Audio.storm().handle_mission_started()
	Events.ui_feedback.emit(&"pause_close")
	Events.ui_feedback.emit(&"menu_close")


func _bus_db(bus: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func _muffle_filter(bus: StringName) -> Array:
	var index: int = AudioServer.get_bus_index(bus)
	for i: int in AudioServer.get_bus_effect_count(index):
		var effect: AudioEffect = AudioServer.get_bus_effect(index, i)
		if effect.resource_name == AudioMix.MUFFLE_EFFECT:
			return [effect, AudioServer.is_bus_effect_enabled(index, i)]
	return []


func test_weather_bus_exists_and_follows_the_effects_volume() -> void:
	assert_ne(AudioServer.get_bus_index(&"Weather"), -1)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Weather")), &"Master")
	assert_eq(AudioMix.SETTING_FOR_BUS[&"Weather"], &"sfx_volume")


func test_full_storm_muffles_the_world_but_not_the_voices() -> void:
	var clear: Dictionary[StringName, float] = {}
	for bus: StringName in [&"SFX", &"Ambience", &"Barks", &"Advisor", &"UI", &"Voice", &"Weather"]:
		clear[bus] = _bus_db(bus)
	Audio.storm().handle_storm_changed(1.0)
	for i: int in 40:
		Audio.storm().advance(0.1)
	assert_almost_eq(Audio.muffle(), 1.0, 0.001)
	for bus: StringName in AudioMix.MUFFLED_BUSES:
		var filter: Array = _muffle_filter(bus)
		assert_eq(filter.size(), 2, "%s has the StormMuffle low-pass" % bus)
		var lowpass: AudioEffectLowPassFilter = filter[0]
		var enabled: bool = filter[1]
		assert_true(enabled, "%s muffle enabled" % bus)
		assert_almost_eq(lowpass.cutoff_hz, StormCues.MUFFLE_CLOSED_HZ, 1.0)
	assert_almost_eq(_bus_db(&"SFX"), clear[&"SFX"] + StormCues.MUFFLE_DB[&"SFX"], 0.01)
	assert_almost_eq(
		_bus_db(&"Ambience"), clear[&"Ambience"] + StormCues.MUFFLE_DB[&"Ambience"], 0.01
	)
	for bus: StringName in [&"Barks", &"Advisor", &"UI", &"Voice", &"Weather"]:
		assert_almost_eq(_bus_db(bus), clear[bus], 0.01, "%s stays clear" % bus)
	# The storm lifts: everything comes back exactly.
	Audio.storm().handle_storm_changed(0.0)
	for i: int in 40:
		Audio.storm().advance(0.1)
	assert_eq(Audio.muffle(), 0.0)
	for bus: StringName in clear:
		assert_almost_eq(_bus_db(bus), clear[bus], 0.01, "%s restored" % bus)
	for bus: StringName in AudioMix.MUFFLED_BUSES:
		var enabled: bool = _muffle_filter(bus)[1]
		assert_false(enabled, "%s filter off when clear" % bus)


func test_mission_start_lifts_a_final_storm_at_once() -> void:
	Audio.storm().handle_storm_changed(1.0)
	for i: int in 40:
		Audio.storm().advance(0.1)
	Audio.storm().handle_mission_ended(false)
	Audio.storm().handle_mission_started()
	assert_eq(Audio.muffle(), 0.0)


func test_pause_and_menu_overlays() -> void:
	var music: float = _bus_db(&"Music")
	var sfx: float = _bus_db(&"SFX")
	var ui: float = _bus_db(&"UI")
	Events.ui_feedback.emit(&"pause_open")
	assert_almost_eq(_bus_db(&"Music"), music + AudioMix.PAUSE_DB[&"Music"], 0.01)
	assert_almost_eq(_bus_db(&"SFX"), sfx + AudioMix.PAUSE_DB[&"SFX"], 0.01)
	assert_almost_eq(_bus_db(&"UI"), ui, 0.01, "the pause menu's own clicks stay")
	Events.ui_feedback.emit(&"pause_close")
	assert_almost_eq(_bus_db(&"Music"), music, 0.01)
	assert_almost_eq(_bus_db(&"SFX"), sfx, 0.01)
	assert_eq(AudioMix.overlay_db(&"Ambience", false, true, 0.0), AudioMix.MENU_DB[&"Ambience"])
	assert_eq(AudioMix.overlay_db(&"Barks", true, true, 1.0), 0.0)


func test_new_events_exist_on_their_buses() -> void:
	var expected: Dictionary[String, StringName] = {
		"ui/ui_pause_open": &"UI",
		"ui/ui_pause_close": &"UI",
		"ui/ui_slider_tick": &"UI",
		"ui/ui_toggle": &"UI",
		"ui/ui_hint_show": &"UI",
		"ui/ui_hint_dismiss": &"UI",
		"weather/amb_storm_wind": &"Weather",
		"weather/amb_storm_grit": &"Weather",
		"weather/amb_storm_throb": &"Weather",
		"weather/storm_front_rumble": &"Weather",
		"weather/storm_gust": &"Weather",
		"weather/storm_debris": &"Weather",
		"weather/storm_passed": &"Weather",
		"ambience/amb_kessel_air": &"Ambience",
		"ambience/amb_kessel_hush": &"Ambience",
		"ambdetail/amb_rock_settle": &"Ambience",
		"ambdetail/amb_flux_vent": &"Ambience",
		"ambdetail/amb_dust_devil": &"Ambience",
		"ambdetail/amb_combine_industry": &"Ambience",
		"explosion/death_prop_crates": &"Explosions",
		"explosion/death_prop_tank": &"Explosions",
		"explosion/death_prop_barrier": &"Explosions",
		"explosion/death_prop_boulder": &"Explosions",
		"discovery/discovery_enemy_intel": &"Discovery",
		"advisor/advisor_storm_passed": &"Advisor",
		"advisor/advisor_enemy_intel": &"Advisor",
		"sting/mus_hit_combat": &"Music",
		"sting/mus_hit_aftermath": &"Music",
		"sting/mus_sting_storm_final": &"Music",
		"sting/mus_sting_outsurveyed": &"Music",
		"bed/mus_menu_theme": &"Music",
	}
	for path: String in expected:
		var event: SoundEvent = load("%s/%s.tres" % [EVENTS_DIR, path]) as SoundEvent
		assert_not_null(event, path)
		if event != null:
			assert_eq(event.bus, expected[path], "%s bus" % path)
			assert_false(event.streams.is_empty(), "%s has streams" % path)
	for path: String in [
		"weather/storm_debris", "ambdetail/amb_rock_settle", "explosion/death_prop_tank"
	]:
		var event: SoundEvent = load("%s/%s.tres" % [EVENTS_DIR, path]) as SoundEvent
		assert_true(event.positional, "%s is positional" % path)
	var gusts: SoundEvent = load("%s/weather/storm_gust.tres" % EVENTS_DIR)
	assert_false(gusts.positional, "gusts are flat, panned in the file")
	assert_gt(gusts.streams.size(), 2, "gust variations")


func test_ui_feedback_kinds_name_their_sounds() -> void:
	for kind: StringName in [
		&"pause_open", &"pause_close", &"slider_tick", &"toggle", &"hint_show", &"hint_dismiss"
	]:
		var ids: Array[StringName] = AudioCueSelector.feedback_event(kind)
		assert_true(Audio.has_event(ids[0]), "%s -> %s" % [kind, ids[0]])


func test_prop_deaths_have_their_own_sound() -> void:
	for kind: StringName in [&"prop_crates", &"prop_tank", &"prop_barrier", &"prop_boulder"]:
		var prop: FakeProp = FakeProp.new()
		prop.def = FakeDef.new()
		prop.def.sound_set = kind
		prop.add_to_group(&"props")
		var events: Array[StringName] = CombatCues.death_events(prop)
		assert_eq(events[0], StringName("death_%s" % kind))
		assert_true(Audio.has_event(events[0]), String(events[0]))
		prop.free()


func test_props_do_not_heat_the_score_or_raise_alarms() -> void:
	var router: CombatSoundRouter = CombatSoundRouter.new()
	var alerts: Array[StringName] = []
	router.offer_alert = func(kind: StringName, _at: Vector3) -> void: alerts.append(kind)
	add_child_autofree(router)
	router.set_process(false)
	var prop: FakeProp = FakeProp.new()
	prop.def = FakeDef.new()
	prop.def.sound_set = &"prop_tank"
	prop.faction = 0
	prop.add_to_group(&"props")
	add_child_autofree(prop)
	for i: int in 20:
		router.handle_entity_damaged(prop, 50.0, null, i * 0.1)
		router.handle_entity_died(prop, i * 0.1)
	assert_true(alerts.is_empty(), "a burning prop is not an attack on the base")
	assert_eq(router.update_mood(2.0), MusicMood.EXPLORE)


func test_enemy_intel_gain_is_heard_and_remembered() -> void:
	var router: DiscoverySoundRouter = DiscoverySoundRouter.new()
	var played: Array[StringName] = []
	router.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		played.append(ids[0])
		return ids[0]
	add_child_autofree(router)
	router.handle_intel_changed(1, 0, 10.0)
	assert_true(played.is_empty(), "the first report is the baseline")
	assert_false(router.enemy_gained_within(45.0, 10.0))
	router.handle_intel_changed(1, 40, 20.0)
	assert_eq(played, [DiscoveryCues.ENEMY_INTEL] as Array[StringName])
	assert_true(router.enemy_gained_within(45.0, 50.0))
	assert_false(router.enemy_gained_within(45.0, 80.0))
	router.handle_intel_changed(1, 30, 30.0)
	assert_eq(played.size(), 1, "spending is not banking")
	router.handle_intel_changed(0, 5, 31.0)
	router.handle_intel_changed(0, 25, 32.0)
	assert_eq(played.count(DiscoveryCues.ENEMY_INTEL), 1, "the player's own gain is the tick")


func test_new_advisor_kinds_are_ranked_and_throttled() -> void:
	for kind: StringName in [&"storm_warning", &"storm_passed", &"enemy_intel"]:
		assert_true(Audio.has_event(StringName("advisor_%s" % kind)), String(kind))
		assert_ne(AdvisorQueue.priority_of(kind), AdvisorQueue.DEFAULT_PRIORITY, String(kind))
	assert_gt(AdvisorQueue.throttle_of(&"enemy_intel"), 15.0, "the race warning does not nag")


class FakeDef:
	extends Resource
	var sound_set: StringName = &""
	var armour_type: StringName = &"light"


class FakeProp:
	extends Node3D
	var def: FakeDef
	var faction: int = -1
	var is_visible_to_player: bool = true
