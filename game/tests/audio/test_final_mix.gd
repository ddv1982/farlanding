extends GutTest
## The final mix (Phase 6), measured through the real `Audio` autoload and bus
## layout: headless Godot mixes in real time, and a capture on the Master bus
## hears what a player would. Scenes:
##
## - explore: the explore score and the planet ambience, nothing else.
## - worst case: heavy combat score with the urgency and storm layers, a full
##   dust storm (beds, gusts, debris, the muffle), six weapon starts and six
##   impacts a frame near the listener plus blasts, an Advisor or stealth alarm
##   every 1.5 s and interface clicks: everything at once.
## - ship (Phase 7): aboard the Meridian on the star map: the ship theme, the
##   ship ambience, map hovers and clicks, a tech purchase and a campaign
##   Advisor phrase every 1.5 s.
## - Thalassa calm (Phase 8a): the Thalassa score in calm, its ambience (wind
##   over water, surf, the tidal drone, details) and the tide's beds at low
##   water, slack.
## - Thalassa fight (Phase 8a): heavy combat score with the urgency layer and
##   the tide layer at high water, the tide still rising (water bed and rush),
##   the worst-case battle, Advisor alarms and a tide warning, clicks.
##
## Asserted: the Master output never clips (the limiter's ceiling holds), the mix
## itself has headroom before the limiter, and loudness stays in its window.
## The numbers are printed; docs/AUDIO_STYLE.md quotes them.

## Master limiter ceiling is -1 dBFS; allow a hair for inter-sample rounding.
const CEILING_DBFS: float = -0.9
## The mix may touch the limiter, but not drive it hard.
const PRE_LIMITER_MAX_DBFS: float = 0.0
const WORST_LUFS: Vector2 = Vector2(-24.0, -13.0)
const EXPLORE_LUFS: Vector2 = Vector2(-36.0, -22.0)
const SHIP_LUFS: Vector2 = Vector2(-36.0, -22.0)
const SHIP_SCORE: String = "res://data/sounds/music/meridian.tres"
const KESSEL_SCORE: String = "res://data/sounds/music/kessel_reach.tres"
const THALASSA: StringName = &"thalassa_low"
const SHIP_ALERTS: Array[StringName] = [
	&"advisor_campaign_return_won",
	&"advisor_campaign_intel_banked",
	&"advisor_campaign_route_open",
	&"advisor_campaign_tech_available",
]
const SHIP_CATEGORIES: Array[StringName] = [&"Music", &"Ambience", &"Advisor", &"UI"]
const SETTLE_SECONDS: float = 2.5
const RECORD_SECONDS: float = 6.0
const FRAME: float = 0.05
## Buses measured per category (before their faders) in the worst case.
const CATEGORIES: Array[StringName] = [
	&"Music", &"Ambience", &"Weather", &"Weapons", &"Explosions", &"Advisor", &"Stealth", &"UI"
]
## The Advisor must sit at least this far above the (ducked) music.
const ADVISOR_OVER_MUSIC_LU: float = 3.0

var _mix: MixScene
## Bus -> what its capture recorded in the last scene.
var _frames: Dictionary[StringName, PackedVector2Array] = {}


func before_each() -> void:
	_mix = MixScene.new()
	# Positional players only mix with a camera in the viewport (the game always
	# has one; the test runner does not).
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()
	Audio.set_listener_focus(Vector3.ZERO, 0.5)


func after_each() -> void:
	_mix.detach()
	Events.campaign_screen_changed.emit(&"")
	Audio.music().stop_bed()
	Audio.storm().handle_mission_started()
	Audio.music().set_layer_gain(&"urgency", AudioMix.SILENT_DB)
	Audio.music().force_state(&"explore")
	_tide().handle_mission_started()
	if Audio.music().target_score().id != (load(KESSEL_SCORE) as MusicScore).id:
		Audio.play_score(load(KESSEL_SCORE) as MusicScore)  # back to Kessel at once for the next test


func _tide() -> TideSound:
	return Audio.get_node(^"Tide") as TideSound


## Lands on Thalassa (score and ambience) with the sea at `level`, rising at
## `rate` per second, and lets the tide's arrival fade finish.
func _land_on_thalassa(level: float, rate: float) -> void:
	Audio.play_planet(THALASSA)
	var arrived: Callable = func() -> bool:
		return Audio.music().score != null and Audio.music().score.id == THALASSA
	await wait_until(arrived, 5.0)
	var tide: TideSound = _tide()
	tide.handle_mission_started()
	for k: int in 40:  # four seconds of reports (the arrival fade is three)
		tide.handle_tide_changed(minf(level + rate * (k - 40) * 0.1, 1.0))
		tide.advance(0.1)
	tide.handle_tide_changed(level)


func _record(scene: StringName) -> Array[float]:
	var fight: bool = scene == &"thalassa_fight"
	var worst: bool = scene == &"worst" or fight
	var ship: bool = scene == &"ship"
	Audio.stop_all_voices()  # nothing left over from earlier tests
	await wait_seconds(SETTLE_SECONDS)
	_mix.attach()
	if worst or ship:
		for bus: StringName in CATEGORIES if worst else SHIP_CATEGORIES:
			_mix.attach_bus(bus)
	_mix.clear()
	var t: float = 0.0
	var i: int = 0
	var most_voices: int = 0
	while t < RECORD_SECONDS:
		if worst:
			_mix.battle_frame(6)
			if i % 30 == 0:
				_mix.alert(i / 30)
			if i % 8 == 0:
				Audio.play(&"ui_click")
		if ship:
			_ship_frame(i)
		if fight:  # the sea still coming in, reported a few times a second
			Events.tide_changed.emit(minf(0.9 + i * 0.0008, 1.0))
			if i % 30 == 15:
				Audio.play(&"advisor_tide_rising")
			if i == 40:
				Events.tide_turning.emit(20.0, false)
		_mix.note_bus_peaks()
		most_voices = maxi(most_voices, Audio.active_voices())
		await wait_seconds(FRAME)
		t += FRAME
		i += 1
	var rate: float = AudioServer.get_mix_rate()
	var pre: PackedVector2Array = MixScene.frames_of(_mix.pre)
	var post: PackedVector2Array = MixScene.frames_of(_mix.post)
	var result: Array[float] = [
		MixScene.peak_dbfs(pre),
		MixScene.peak_dbfs(post),
		MixScene.lufs(post, rate),
		float(post.size()) / rate,
		float(most_voices),
	]
	var peaks: String = ""
	for bus: StringName in _mix.bus_peaks:
		peaks += "%s %.1f, " % [bus, _mix.bus_peaks[bus]]
	(
		gut
		. p(
			(
				"%s: pre-limiter peak %.2f dBFS, master peak %.2f dBFS, %.1f LUFS over %.1f s, %d voices"
				% [String(scene), result[0], result[1], result[2], result[3], most_voices]
			)
		)
	)
	gut.p("  bus peaks (dBFS): " + peaks)
	var categories: String = ""
	for bus: StringName in _mix.bus_captures:
		_frames[bus] = MixScene.frames_of(_mix.bus_captures[bus])
		var loudness: float = MixScene.lufs(_frames[bus], rate)
		result.append(loudness)
		categories += "%s %.1f, " % [bus, loudness]
	if not categories.is_empty():
		gut.p("  category loudness before faders (LUFS): " + categories)
	return result


## One frame aboard: hovers sweep, a click now and then, a purchase, and a
## campaign Advisor phrase every 1.5 s (the strongest things the ship does).
func _ship_frame(i: int) -> void:
	Events.ui_feedback.emit(&"map_node_hover")
	if i % 10 == 0:
		Events.ui_feedback.emit(&"map_node_select")
	if i % 40 == 5:
		Events.ui_feedback.emit(&"tech_buy")
	if i % 30 == 0:
		Audio.play(SHIP_ALERTS[(i / 30) % SHIP_ALERTS.size()])


func test_explore_sits_quietly() -> void:
	Audio.music().force_state(&"explore")
	var result: Array[float] = await _record(&"explore")
	assert_gt(result[3], RECORD_SECONDS * 0.8, "the mixer ran (captured %.1f s)" % result[3])
	assert_lt(result[1], CEILING_DBFS)
	assert_between(result[2], EXPLORE_LUFS.x, EXPLORE_LUFS.y, "explore loudness")


func test_worst_case_never_clips_and_stays_in_its_window() -> void:
	Audio.storm().handle_storm_changed(1.0)
	for k: int in 40:
		Audio.storm().advance(0.1)
	Audio.music().set_layer_gain(&"urgency", 0.0)
	Audio.music().force_state(&"combat_heavy")
	var result: Array[float] = await _record(&"worst")
	assert_gt(result[3], RECORD_SECONDS * 0.8, "the mixer ran (captured %.1f s)" % result[3])
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_lt(result[0], PRE_LIMITER_MAX_DBFS, "the mix has headroom before the limiter")
	assert_between(result[2], WORST_LUFS.x, WORST_LUFS.y, "worst-case loudness")
	assert_lte(int(result[4]), 48, "the voice budget holds")
	var speaking: Array[float] = MixScene.loudness_while(
		_frames[&"Advisor"], _frames[&"Music"], AudioServer.get_mix_rate()
	)
	gut.p("  while the Advisor speaks: Advisor %.1f LUFS, Music %.1f LUFS" % speaking)
	assert_gt(
		speaking[0],
		speaking[1] + ADVISOR_OVER_MUSIC_LU,
		"the Advisor is heard over the battle score"
	)


func test_ship_sits_quietly_and_the_advisor_is_clear() -> void:
	var ship: MusicScore = load(SHIP_SCORE)
	Events.campaign_screen_changed.emit(&"star_map")
	await wait_until(func() -> bool: return Audio.music().score == ship, 5.0)
	var result: Array[float] = await _record(&"ship")
	assert_gt(result[3], RECORD_SECONDS * 0.8, "the mixer ran (captured %.1f s)" % result[3])
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_lt(result[0], PRE_LIMITER_MAX_DBFS, "the mix has headroom before the limiter")
	assert_between(result[2], SHIP_LUFS.x, SHIP_LUFS.y, "ship loudness")
	var speaking: Array[float] = MixScene.loudness_while(
		_frames[&"Advisor"], _frames[&"Music"], AudioServer.get_mix_rate()
	)
	gut.p("  while the Advisor speaks aboard: Advisor %.1f LUFS, Music %.1f LUFS" % speaking)
	assert_gt(
		speaking[0], speaking[1] + ADVISOR_OVER_MUSIC_LU, "the Advisor is heard over the ship theme"
	)
	var ui: float = MixScene.lufs(_frames[&"UI"], AudioServer.get_mix_rate())
	assert_lt(ui, speaking[0], "the interface stays under the Advisor")


func test_thalassa_calm_low_tide_sits_quietly() -> void:
	await _land_on_thalassa(0.0, 0.0)
	Audio.music().force_state(&"calm")
	var result: Array[float] = await _record(&"thalassa_calm")
	assert_gt(result[3], RECORD_SECONDS * 0.8, "the mixer ran (captured %.1f s)" % result[3])
	assert_true(_tide().layer_playing(TideCues.LOW), "low water is heard")
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_between(result[2], EXPLORE_LUFS.x, EXPLORE_LUFS.y, "Thalassa calm loudness")


func test_thalassa_fight_at_high_tide_never_clips() -> void:
	await _land_on_thalassa(0.9, 0.015)
	Audio.music().set_layer_gain(&"urgency", 0.0)
	Audio.music().force_state(&"combat_heavy")
	var result: Array[float] = await _record(&"thalassa_fight")
	assert_gt(result[3], RECORD_SECONDS * 0.8, "the mixer ran (captured %.1f s)" % result[3])
	assert_true(_tide().layer_playing(TideCues.HIGH), "high water is heard")
	assert_gt(Audio.music().layer_gain_db(&"tide"), -6.0, "the tide layer is up")
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_lt(result[0], PRE_LIMITER_MAX_DBFS, "the mix has headroom before the limiter")
	assert_between(result[2], WORST_LUFS.x, WORST_LUFS.y, "Thalassa fight loudness")
	assert_lte(int(result[4]), 48, "the voice budget holds")
	var speaking: Array[float] = MixScene.loudness_while(
		_frames[&"Advisor"], _frames[&"Music"], AudioServer.get_mix_rate()
	)
	gut.p("  while the Advisor speaks at high tide: Advisor %.1f LUFS, Music %.1f LUFS" % speaking)
	assert_gt(
		speaking[0],
		speaking[1] + ADVISOR_OVER_MUSIC_LU,
		"the Advisor is heard over the Thalassa battle score"
	)
