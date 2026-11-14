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
## - Emberfall calm (Phase 8b): the Emberfall score in calm and its ambience
##   (the rumble, lava, hot wind, details): the planet's low end at rest.
## - Emberfall Holdout fight (Phase 8b): heavy combat score with the urgency,
##   pressure and holdout layers at full, the extraction engine approaching, a
##   vent near the listener building up and then erupting (the blast ducks the
##   mix), the worst-case battle, Advisor alarms and eruption warnings, clicks.
## - Verdance calm (Phase 8c): the Verdance score in calm and its ambience (the
##   leaves, the chorus, the stream, details) with the camera under a crown.
## - Verdance air war (Phase 8c): heavy combat score with the urgency layer,
##   four aircraft engines overhead (two Talons, two Hornets), their guns and
##   rockets on top of the worst-case battle, aircraft falling, canopy rustles,
##   Advisor alarms and an air-contact phrase every 1.5 s, clicks.
## - Hollow Meridian calm (Phase 8d): the Hollow score in calm with the Core's
##   first layer (a quarter charged), its ambience (the hum, the air, far
##   machinery, details) and two of the player's engines running nearby.
## - Hollow Meridian finale (Phase 8d): the Core's awakening at its peak (the
##   motif's answer and the Meridian dyad, 19-25 s into the cue) over the Hollow
##   score in heavy combat with the urgency and all three Core layers (dipped
##   under the peak, as in the game), the worst-case battle plus Sentinel bolts
##   and deaths, engines spinning up, Advisor alarms and a contested-Core phrase
##   every 1.5 s, clicks: the campaign's loudest moment.
##
## - Kessel calm (Phase 9): the Kessel score in calm and its ambience, so every
##   planet has a calm scene measured the same way.
##
## Phase 9 compares the planets: each has a calm scene (its score in `calm`, its
## ambience) and a busy one (its worst fight), and the last test asserts the
## calm scenes, and the busy ones, sit within PLANET_SPREAD_LU of each other.
## The finale also asserts the awakening is not ducked under the Advisor.
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
const EMBERFALL: StringName = &"emberfall"
const VERDANCE: StringName = &"verdance"
const HOLLOW: StringName = &"hollow_meridian"
## Seconds into the awakening where the finale scene starts settling: the
## recording then covers its peak (about 19.5-25.5 s).
const PEAK_FROM: float = 17.0
const AIR_SETS: Array[StringName] = [&"talon", &"hornet", &"talon", &"hornet"]
const SHIP_ALERTS: Array[StringName] = [
	&"advisor_campaign_return_won",
	&"advisor_campaign_intel_banked",
	&"advisor_campaign_route_open",
	&"advisor_campaign_tech_available",
]
const SHIP_CATEGORIES: Array[StringName] = [&"Music", &"Ambience", &"Advisor", &"UI"]
## Buses measured in the calm scenes (Phase 9: which part makes a planet loud).
const CALM_CATEGORIES: Array[StringName] = [&"Music", &"Ambience", &"Buildings"]
const SETTLE_SECONDS: float = 2.5
const RECORD_SECONDS: float = 6.0
const FRAME: float = 0.05
## Buses measured per category (before their faders) in the worst case.
const CATEGORIES: Array[StringName] = [
	&"Music", &"Ambience", &"Weather", &"Weapons", &"Explosions", &"Advisor", &"Stealth", &"UI"
]
## The Advisor must sit at least this far above the (ducked) music.
const ADVISOR_OVER_MUSIC_LU: float = 3.0
## Under the awakening the music may sit at most this much lower while the
## Advisor speaks than over the whole recording (it is not ducked).
const AWAKENING_DUCK_MAX_LU: float = 1.5
## Comparable scenes on different planets sit within this of each other:
## about 2 LU, plus the six-second recordings' own spread (the beds wander, so
## one scene moves by up to 1.5 LU from run to run). The busy scenes get a
## little more: Kessel Reach's worst case is a storm fight with nothing of the
## planet's own on top, where the others add their tide, eruption, air war or
## awakening (docs/AUDIO_STYLE.md, "Across the campaign").
## The limits leave room for the measurement's own run-to-run movement (a scene moves
## up to 1.5 LU between runs, more on a loaded CI runner): the designed spreads are
## about 2 LU (calm) and 3 LU (busy).
const PLANET_SPREAD_LU: Dictionary[StringName, float] = {&"calm": 3.5, &"busy": 4.5}
## Scene -> [planet, kind] for the cross-planet comparison.
const PLANET_SCENES: Dictionary[StringName, Array] = {
	&"kessel_calm": [&"kessel_reach", &"calm"],
	&"thalassa_calm": [&"thalassa_low", &"calm"],
	&"emberfall_calm": [&"emberfall", &"calm"],
	&"verdance_calm": [&"verdance", &"calm"],
	&"hollow_calm": [&"hollow_meridian", &"calm"],
	&"worst": [&"kessel_reach", &"busy"],
	&"thalassa_fight": [&"thalassa_low", &"busy"],
	&"emberfall_fight": [&"emberfall", &"busy"],
	&"verdance_fight": [&"verdance", &"busy"],
	&"hollow_finale": [&"hollow_meridian", &"busy"],
}

## Scene -> integrated Master loudness (LUFS), kept across this script's tests.
var measured: Dictionary[StringName, float] = {}

var _mix: MixScene
## Bus -> what its capture recorded in the last scene.
var _frames: Dictionary[StringName, PackedVector2Array] = {}
## The erupting vent of the Emberfall fight.
var _vent: Node3D


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
	_eruption().handle_mission_started()
	_holdout().handle_mission_started()
	_canopy().handle_mission_started()
	_core().handle_mission_started()
	_machines().handle_mission_started()
	Audio.music().set_layer_gain(&"pressure", AudioMix.SILENT_DB)
	Audio.music().set_layer_gain(&"holdout", AudioMix.SILENT_DB)
	if Audio.music().target_score().id != (load(KESSEL_SCORE) as MusicScore).id:
		Audio.play_score(load(KESSEL_SCORE) as MusicScore)  # back to Kessel at once for the next test


func _tide() -> TideSound:
	return Audio.get_node(^"Tide") as TideSound


func _eruption() -> EruptionSound:
	return Audio.get_node(^"Eruption") as EruptionSound


func _holdout() -> HoldoutSound:
	return Audio.get_node(^"Holdout") as HoldoutSound


func _canopy() -> CanopySound:
	return Audio.get_node(^"Canopy") as CanopySound


func _core() -> CoreSound:
	return Audio.get_node(^"Core") as CoreSound


func _machines() -> MachineSound:
	return Audio.get_node(^"Machines") as MachineSound


## Lands on Hollow Meridian (score and ambience).
func _land_on_hollow() -> void:
	Audio.play_planet(HOLLOW)
	var arrived: Callable = func() -> bool:
		return Audio.music().score != null and Audio.music().score.id == HOLLOW
	await wait_until(arrived, 5.0)


## Two of the player's engines running near the camera (their hums wait for
## the spin-up to finish).
func _run_engines() -> void:
	for k: int in 2:
		var engine: Node3D = Node3D.new()
		add_child_autofree(engine)
		engine.global_position = Vector3(-14.0 + 26.0 * k, 0.0, 9.0 - 15.0 * k)
		_machines().handle_reactivated(engine, 0)


## Lands on Verdance (score and ambience).
func _land_on_verdance() -> void:
	Audio.play_planet(VERDANCE)
	var arrived: Callable = func() -> bool:
		return Audio.music().score != null and Audio.music().score.id == VERDANCE
	await wait_until(arrived, 5.0)


## An aircraft overhead (its engine loops through the MovementLoops).
class Aircraft:
	extends Node3D
	var def: UnitDef
	var speed: float = 9.0
	var faction: int = 0


## The camera's ground under a crown.
class CanopyMap:
	extends Node

	func is_under_canopy(_point: Vector3) -> bool:
		return true


## Lands on Emberfall (score and ambience).
func _land_on_emberfall() -> void:
	Audio.play_planet(EMBERFALL)
	var arrived: Callable = func() -> bool:
		return Audio.music().score != null and Audio.music().score.id == EMBERFALL
	await wait_until(arrived, 5.0)


## A survival objective with `seconds` left at tick 0 (the Holdout's timer).
class SurviveTimer:
	extends RefCounted
	var id: StringName = &"hold"
	var kind: StringName = &"primary"
	var state: StringName = &"active"
	var countdown_tick: int = -1
	var countdown_fails: bool = false


## One of the player's buildings, by the vent.
class BaseBuilding:
	extends Node3D
	var faction: int = 0


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
	var ember: bool = scene == &"emberfall_fight"
	var air: bool = scene == &"verdance_fight"
	var finale: bool = scene == &"hollow_finale"
	var worst: bool = scene == &"worst" or fight or ember or air or finale
	var ship: bool = scene == &"ship"
	Audio.stop_all_voices()  # nothing left over from earlier tests
	await wait_seconds(SETTLE_SECONDS)
	_mix.attach()
	var measured_buses: Array[StringName] = CALM_CATEGORIES
	if worst:
		measured_buses = CATEGORIES
	elif ship:
		measured_buses = SHIP_CATEGORIES
	for bus: StringName in measured_buses:
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
		if ember:  # eruption warnings from the Advisor; the vent blows mid-way
			if i % 30 == 15:
				Audio.play(&"advisor_eruption_warning")
			if i == 50:
				Events.eruption.emit(_vent, 16.0)
			_holdout().handle_sim_ticked(int(i * FRAME * SimClock.TICK_RATE))
		if air:  # the air war on top of the ground battle
			_air_frame(i)
		if finale:  # the Custodians fight on while the Core wakes
			_finale_frame(i)
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
	measured[scene] = result[2]
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


## One frame of the Verdance air war: guns and rockets from above, a craft
## coming down now and then, units rustling under the crowns, the Advisor.
func _air_frame(i: int) -> void:
	var angle: float = i * 0.7
	var above: Vector3 = Vector3(cos(angle) * 18.0, 13.0, sin(angle) * 18.0)
	Audio.play_at(&"weapon_talon_fire", above)
	if i % 2 == 0:
		Audio.play_at(&"weapon_hornet_fire", -above)
	if i % 20 == 10:
		Audio.play_at(&"death_talon" if i % 40 == 10 else &"death_hornet", above * 0.6)
	if i % 25 == 5:
		Audio.play_at(&"canopy_rustle_in", Vector3(6, 0, -4))
	if i % 30 == 15:
		Audio.play(&"advisor_air_contact")


## One frame of the finale: Sentinel bolts, an engine spinning up now and then,
## a Sentinel falling, someone else at the Core.
func _finale_frame(i: int) -> void:
	if i % 3 == 0:
		Audio.play_at(
			&"weapon_sentinel_fire", Vector3(cos(i * 0.9) * 20.0, 0.0, sin(i * 0.9) * 20.0)
		)
	if i % 20 == 5:
		Audio.play_at(MachineCues.SPINUP, Vector3(15.0, 0.0, -10.0))
	if i % 40 == 25:
		Audio.play_at(&"death_sentinel", Vector3(-12.0, 0.0, 8.0))
	if i % 30 == 15:
		Audio.play(&"advisor_core_contested")


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
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
	assert_lt(result[1], CEILING_DBFS)
	assert_between(result[2], EXPLORE_LUFS.x, EXPLORE_LUFS.y, "explore loudness")


func test_kessel_calm_sits_quietly() -> void:
	Audio.music().force_state(&"calm")
	var result: Array[float] = await _record(&"kessel_calm")
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_between(result[2], EXPLORE_LUFS.x, EXPLORE_LUFS.y, "Kessel calm loudness")


func test_worst_case_never_clips_and_stays_in_its_window() -> void:
	Audio.storm().handle_storm_changed(1.0)
	for k: int in 40:
		Audio.storm().advance(0.1)
	Audio.music().set_layer_gain(&"urgency", 0.0)
	Audio.music().force_state(&"combat_heavy")
	var result: Array[float] = await _record(&"worst")
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
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
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
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
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
	assert_true(_tide().layer_playing(TideCues.LOW), "low water is heard")
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_between(result[2], EXPLORE_LUFS.x, EXPLORE_LUFS.y, "Thalassa calm loudness")


func test_thalassa_fight_at_high_tide_never_clips() -> void:
	await _land_on_thalassa(0.9, 0.015)
	Audio.music().set_layer_gain(&"urgency", 0.0)
	Audio.music().force_state(&"combat_heavy")
	var result: Array[float] = await _record(&"thalassa_fight")
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
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


func test_verdance_calm_under_the_crowns_sits_quietly() -> void:
	await _land_on_verdance()
	var map: CanopyMap = CanopyMap.new()
	map.add_to_group(CanopySound.CANOPY_GROUP)
	add_child_autofree(map)
	Audio.music().force_state(&"calm")
	var result: Array[float] = await _record(&"verdance_calm")
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
	assert_gt(_canopy().shade(), 0.5, "the camera is under a crown")
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_between(result[2], EXPLORE_LUFS.x, EXPLORE_LUFS.y, "Verdance calm loudness")
	map.remove_from_group(CanopySound.CANOPY_GROUP)


func test_verdance_air_war_never_clips() -> void:
	await _land_on_verdance()
	for k: int in AIR_SETS.size():
		var craft: Aircraft = Aircraft.new()
		craft.def = UnitDef.new()
		craft.def.sound_set = AIR_SETS[k]
		craft.add_to_group(MovementLoops.UNITS_GROUP)
		add_child_autofree(craft)
		craft.global_position = Vector3(-15.0 + 10.0 * k, 13.0, 6.0 - 4.0 * k)
	Audio.music().set_layer_gain(&"urgency", 0.0)
	Audio.music().force_state(&"combat_heavy")
	var result: Array[float] = await _record(&"verdance_fight")
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_lt(result[0], PRE_LIMITER_MAX_DBFS, "the mix has headroom before the limiter")
	assert_between(result[2], WORST_LUFS.x, WORST_LUFS.y, "Verdance air war loudness")
	assert_lte(int(result[4]), 48, "the voice budget holds")
	var speaking: Array[float] = MixScene.loudness_while(
		_frames[&"Advisor"], _frames[&"Music"], AudioServer.get_mix_rate()
	)
	gut.p("  while the Advisor speaks on Verdance: Advisor %.1f LUFS, Music %.1f LUFS" % speaking)
	assert_gt(
		speaking[0],
		speaking[1] + ADVISOR_OVER_MUSIC_LU,
		"the Advisor is heard over the Verdance air war"
	)


func test_emberfall_calm_sits_quietly() -> void:
	await _land_on_emberfall()
	Audio.music().force_state(&"calm")
	var result: Array[float] = await _record(&"emberfall_calm")
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_between(result[2], EXPLORE_LUFS.x, EXPLORE_LUFS.y, "Emberfall calm loudness")


func test_emberfall_holdout_fight_with_an_eruption_never_clips() -> void:
	await _land_on_emberfall()
	_vent = Node3D.new()
	add_child_autofree(_vent)
	_vent.global_position = Vector3(22.0, 0.0, 8.0)
	var base: BaseBuilding = BaseBuilding.new()
	base.add_to_group(EruptionSound.BUILDINGS_GROUP)
	add_child_autofree(base)
	base.global_position = Vector3(26.0, 0.0, 14.0)
	_eruption().rescan_base()
	Events.eruption_warning.emit(_vent, 4.0, 16.0)
	var timer: SurviveTimer = SurviveTimer.new()
	timer.countdown_tick = 6 * SimClock.TICK_RATE  # the last seconds of the Holdout
	_holdout().handle_objective(timer)
	_holdout().handle_sim_ticked(0)
	Audio.music().set_layer_gain(&"urgency", 0.0)
	Audio.music().force_state(&"combat_heavy")
	var result: Array[float] = await _record(&"emberfall_fight")
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
	assert_gt(Audio.music().layer_gain_db(&"holdout"), AudioMix.SILENT_DB, "the holdout layer")
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_lt(result[0], PRE_LIMITER_MAX_DBFS, "the mix has headroom before the limiter")
	assert_between(result[2], WORST_LUFS.x, WORST_LUFS.y, "Emberfall fight loudness")
	assert_lte(int(result[4]), 48, "the voice budget holds")
	var speaking: Array[float] = MixScene.loudness_while(
		_frames[&"Advisor"], _frames[&"Music"], AudioServer.get_mix_rate()
	)
	gut.p("  while the Advisor speaks on Emberfall: Advisor %.1f LUFS, Music %.1f LUFS" % speaking)
	assert_gt(
		speaking[0],
		speaking[1] + ADVISOR_OVER_MUSIC_LU,
		"the Advisor is heard over the Emberfall battle score and its low end"
	)
	var low: Array[float] = MixScene.low_band_while(
		_frames[&"Advisor"], _frames[&"Music"], AudioServer.get_mix_rate()
	)
	gut.p("  while the Advisor speaks: Music below 150 Hz %.1f dB RMS, Advisor %.1f dB RMS" % low)
	assert_lt(low[0], low[1], "the score's low end stays under the Advisor too")


func test_hollow_calm_sits_quietly() -> void:
	await _land_on_hollow()
	_core().handle_charge_changed(0.3)
	_run_engines()
	Audio.music().force_state(&"calm")
	await wait_seconds(MachineCues.RUN_DELAY)
	var result: Array[float] = await _record(&"hollow_calm")
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
	assert_eq(_core().level(), 1, "the Core's heartbeat")
	assert_gt(_machines().humming_count(), 0, "the engines hum")
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_between(result[2], EXPLORE_LUFS.x, EXPLORE_LUFS.y, "Hollow Meridian calm loudness")


func test_hollow_finale_peak_never_drives_the_limiter() -> void:
	await _land_on_hollow()
	_core().handle_charge_changed(0.95)
	Audio.music().set_layer_gain(&"urgency", 0.0)
	Audio.music().force_state(&"combat_heavy")
	assert_true(_core().handle_awakened(null, PEAK_FROM))
	var result: Array[float] = await _record(&"hollow_finale")
	assert_gt(result[3], RECORD_SECONDS * 0.6, "the mixer ran (captured %.1f s)" % result[3])
	assert_true(_core().is_peaking(), "recorded inside the awakening")
	assert_lt(result[1], CEILING_DBFS, "Master never clips")
	assert_lt(result[0], PRE_LIMITER_MAX_DBFS, "the mix has headroom before the limiter")
	assert_between(result[2], WORST_LUFS.x, WORST_LUFS.y, "finale loudness")
	assert_lte(int(result[4]), 48, "the voice budget holds")
	var speaking: Array[float] = MixScene.loudness_while(
		_frames[&"Advisor"], _frames[&"Music"], AudioServer.get_mix_rate()
	)
	gut.p("  while the Advisor speaks over the peak: Advisor %.1f LUFS, Music %.1f LUFS" % speaking)
	var music: float = MixScene.lufs(_frames[&"Music"], AudioServer.get_mix_rate())
	gut.p("  the awakening over the whole recording: Music %.1f LUFS" % music)
	assert_false(CoreSound.music_ducks(), "the Advisor does not duck the awakening")
	assert_gt(
		speaking[1],
		music - AWAKENING_DUCK_MAX_LU,
		"the campaign's peak keeps its level while the Advisor speaks"
	)


## Phase 9: the planets side by side. Runs last (GUT keeps file order); any
## scene that did not run leaves its planet out.
func test_zz_planets_sit_together() -> void:
	for kind: StringName in [&"calm", &"busy"]:
		var lowest: float = INF
		var highest: float = -INF
		var line: String = ""
		for scene: StringName in PLANET_SCENES:
			var entry: Array = PLANET_SCENES[scene]
			if entry[1] != kind or not measured.has(scene):
				continue
			lowest = minf(lowest, measured[scene])
			highest = maxf(highest, measured[scene])
			var planet: StringName = entry[0]
			line += "%s %.1f, " % [planet, measured[scene]]
		gut.p("%s scenes (LUFS): %s" % [String(kind), line])
		if lowest == INF:
			pending("no %s scene ran" % kind)
			continue
		assert_lte(
			highest - lowest, PLANET_SPREAD_LU[kind], "%s scenes sit together (%s)" % [kind, line]
		)
