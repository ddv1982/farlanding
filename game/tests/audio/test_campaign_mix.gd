extends GutTest
## Phase 7 through the real `Audio` autoload: campaign screens, launch, debrief
## and mission start drive the ship score, the ship ambience and the ship mix
## (emitted here: the campaign screens may emit nothing yet). Also the
## MusicDirector's score switch on its own, stepped without wall-clock time.

const SHIP_SCORE: String = "res://data/sounds/music/meridian.tres"
const PLANET_SCORE: String = "res://data/sounds/music/kessel_reach.tres"

# --- Through the real Audio autoload ------------------------------------------------


func _back_to_the_planet() -> void:
	Events.campaign_screen_changed.emit(&"")
	Audio.music().stop_bed()
	var planet: MusicScore = load(PLANET_SCORE)
	await wait_until(func() -> bool: return Audio.music().score == planet, 5.0)
	await wait_until(func() -> bool: return Audio.music().score_dip_db() > -0.5, 5.0)


func _bus_db(bus: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func test_aboard_the_ship_and_back() -> void:
	var ship: MusicScore = load(SHIP_SCORE)
	var planet: MusicScore = load(PLANET_SCORE)
	Events.campaign_screen_changed.emit(&"star_map")
	assert_eq(Audio.music().target_score(), ship)
	assert_true(Audio.ambience().is_ship())
	assert_true(Audio.ambience().ship_bed_playing(CampaignCues.BED_HUM), "the hull hums")
	assert_lt(_bus_db(&"SFX"), -60.0, "nothing of the planet aboard")
	assert_lt(_bus_db(&"Weather"), -60.0)
	await wait_until(func() -> bool: return Audio.music().score == ship, 5.0)
	assert_eq(Audio.music().score, ship, "the ship theme plays")
	assert_eq(Audio.music_state(), &"star_map")
	# Moving between screens moves layers; the piece goes on.
	Events.campaign_screen_changed.emit(&"tech_web")
	assert_eq(Audio.music().target_score(), ship, "no switch, no restart")
	assert_eq(Audio.music_state(), &"tech_web")
	Events.campaign_screen_changed.emit(&"loadout")
	assert_eq(Audio.music_state(), &"loadout")
	# Launch: the planet's score takes over under the launch gesture, lowered
	# for the briefing bed; the ship's ambience waits for the landing screen.
	Events.ui_feedback.emit(&"map_launch")
	assert_eq(Audio.music().target_score(), planet)
	assert_true(Audio.ambience().is_ship())
	Events.campaign_screen_changed.emit(&"")
	assert_false(Audio.ambience().is_ship())
	assert_gt(_bus_db(&"SFX"), -60.0, "the world is back")
	await wait_until(func() -> bool: return Audio.music().score == planet, 5.0)
	assert_eq(Audio.music().score, planet)
	await wait_until(
		func() -> bool:
			return Audio.music().score_dip_db() < MissionSoundRouter.BRIEFING_DUCK_DB + 1.0,
		5.0
	)
	assert_lt(Audio.music().score_dip_db(), -10.0, "the score waits under the briefing")
	await _back_to_the_planet()


func test_debrief_to_the_ship_leaves_one_bed_and_one_score() -> void:
	var ship: MusicScore = load(SHIP_SCORE)
	Events.ui_feedback.emit(&"debrief_open")
	assert_not_null(Audio.music().bed_stream(), "the debrief bed")
	Events.campaign_screen_changed.emit(&"star_map")
	assert_eq(Audio.music().target_score(), ship)
	await wait_until(func() -> bool: return Audio.music().bed_stream() == null, 5.0)
	assert_null(Audio.music().bed_stream(), "the debrief bed is gone")
	await wait_until(func() -> bool: return Audio.music().score == ship, 5.0)
	assert_eq(Audio.music().score, ship)
	assert_almost_eq(Audio.music().score_dip_db(), 0.0, 0.5, "the ship theme is not ducked")
	await _back_to_the_planet()


func test_a_score_switch_fades_and_can_be_called_off() -> void:
	var ship: MusicScore = load(SHIP_SCORE)
	var planet: MusicScore = load(PLANET_SCORE)
	var director: MusicDirector = MusicDirector.new()
	add_child_autofree(director)
	director.set_process(false)
	director.swap_cut_below = 0.0
	director.play_score(planet)
	director.switch_score(ship, &"tech_web", MissionSoundRouter.BRIEFING_DUCK_DB)
	assert_eq(director.score, planet, "the old score fades out first")
	assert_eq(director.target_score(), ship)
	director._process(MusicDirector.SWAP_FADE_OUT * 0.5)
	assert_eq(director.score, planet)
	# Back before the fade ends: the switch is called off, the planet stays.
	director.switch_score(planet)
	assert_eq(director.target_score(), planet)
	director._process(MusicDirector.SWAP_FADE_OUT * 2.0)
	assert_eq(director.score, planet, "never restarted")
	# A state asked for during a switch is the incoming score's.
	director.switch_score(ship)
	director.set_state(&"loadout")
	director.set_state(&"combat")  # not a ship state: ignored
	director._process(MusicDirector.SWAP_FADE_OUT * 0.6)
	director._process(MusicDirector.SWAP_FADE_OUT * 0.6)
	assert_eq(director.score, ship, "the ship theme took over")
	assert_eq(director.current_state(), &"loadout")
	director.stop_bed()
	director._process(3.0)
	assert_almost_eq(director.score_dip_db(), 0.0, 0.01, "the hand-over dip lifted")
	director.stop()


func test_mission_start_always_lands() -> void:
	var planet: MusicScore = load(PLANET_SCORE)
	Events.campaign_screen_changed.emit(&"meridian")
	Events.mission_started.emit()
	assert_false(Audio.ambience().is_ship(), "a mission is a landing")
	assert_eq(Audio.music().target_score(), planet)
	assert_gt(_bus_db(&"SFX"), -60.0)
	await _back_to_the_planet()
