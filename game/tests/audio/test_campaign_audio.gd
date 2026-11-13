extends GutTest
## Phase 7: the campaign layer's sound. Pure rules (CampaignCues), the
## CampaignSoundRouter driven with stubs, and the real `Audio` autoload driven
## by emitting the campaign signals (the campaign screens may emit nothing yet).

const EVENTS_DIR: String = "res://data/sounds"
const SHIP_SCORE: String = "res://data/sounds/music/meridian.tres"
const PLANET_SCORE: String = "res://data/sounds/music/kessel_reach.tres"

var _router: CampaignSoundRouter
var _played: Array[StringName] = []
var _offsets: Array[float] = []
var _offered: Array[StringName] = []
var _screens: Array[StringName] = []
var _launches: int = 0


func before_each() -> void:
	_played.clear()
	_offsets.clear()
	_offered.clear()
	_screens.clear()
	_launches = 0
	_router = CampaignSoundRouter.new()
	_router.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		_played.append(ids[0])
		return ids[0]
	_router.play_at = func(id: StringName, _at: Vector3, db: float) -> bool:
		_played.append(id)
		_offsets.append(db)
		return true
	_router.offer_alert = func(kind: StringName) -> void: _offered.append(kind)
	_router.show_screen = func(screen: StringName) -> void: _screens.append(screen)
	_router.launch = func() -> void: _launches += 1
	add_child_autofree(_router)
	_router.set_process(false)


func _event(group: String, id: String) -> SoundEvent:
	var path: String = "%s/%s/%s.tres" % [EVENTS_DIR, group, id]
	return load(path) as SoundEvent if ResourceLoader.exists(path) else null


# --- Pure rules -------------------------------------------------------------------


func test_every_screen_has_its_music_state() -> void:
	var score: MusicScore = load(SHIP_SCORE)
	for screen: StringName in CampaignCues.SCREENS:
		assert_eq(CampaignCues.music_state(screen), screen)
		assert_not_null(score.find_state(screen), "the ship score has %s" % screen)
	assert_eq(CampaignCues.music_state(&"hangar"), CampaignCues.STAR_MAP, "unknown -> star map")
	assert_false(CampaignCues.is_ship_screen(&""), '&"" is a landing')
	assert_true(CampaignCues.is_ship_screen(&"loadout"))


func test_ship_score_layers_are_one_loop() -> void:
	var score: MusicScore = load(SHIP_SCORE)
	assert_eq(score.clips.size(), 1, "one clip: moving between screens never restarts")
	var clip: MusicClip = score.clips[0]
	var length: float = clip.layers[0].get_length()
	for i: int in clip.layers.size():
		assert_almost_eq(clip.layers[i].get_length(), length, 0.01, clip.layer_names[i])
		var ogg: AudioStreamOggVorbis = clip.layers[i] as AudioStreamOggVorbis
		assert_true(ogg.loop, "%s loops" % clip.layer_names[i])
	for state: MusicState in score.states:
		assert_eq(state.layer_volumes_db.size(), clip.layers.size(), String(state.name))
	var planet: MusicScore = load(PLANET_SCORE)
	assert_ne(score.bpm, planet.bpm, "not the Kessel grid")


func test_screens_move_layers_not_the_piece() -> void:
	var score: MusicScore = load(SHIP_SCORE)
	var clip: MusicClip = score.clips[0]
	var web: int = clip.layer_names.find("web")
	var loadout: int = clip.layer_names.find("loadout")
	var title: int = clip.layer_names.find("title")
	var pad: int = clip.layer_names.find("pad")
	for state: StringName in CampaignCues.SCREENS:
		var v: PackedFloat32Array = _levels(score, state)
		assert_gt(v[pad], AudioMix.SILENT_DB, "the pad carries every screen (%s)" % state)
	assert_gt(_levels(score, &"tech_web")[web], AudioMix.SILENT_DB, "the web layer on the web")
	assert_eq(_levels(score, &"star_map")[web], AudioMix.SILENT_DB)
	assert_gt(_levels(score, &"loadout")[loadout], AudioMix.SILENT_DB)
	assert_eq(_levels(score, &"tech_web")[loadout], AudioMix.SILENT_DB)
	assert_gt(_levels(score, &"title")[title], AudioMix.SILENT_DB, "the title arrangement")
	assert_eq(_levels(score, &"star_map")[title], AudioMix.SILENT_DB)


func _levels(score: MusicScore, state: StringName) -> PackedFloat32Array:
	return score.find_state(state).layer_volumes_db


func test_a_mouse_sweep_does_not_machine_gun() -> void:
	var cues: CampaignCues = CampaignCues.new()
	assert_eq(cues.hover(0.0), 0.0, "the first hover plays")
	assert_eq(cues.hover(0.03), CampaignCues.SKIP, "too close")
	assert_eq(cues.hover(0.1), 0.0)
	# A sweep: a hover every 20 ms for 1.5 s (75 nodes).
	var sweep: CampaignCues = CampaignCues.new()
	var heard: int = 0
	var quiet: int = 0
	for i: int in 75:
		var offset: float = sweep.hover(10.0 + i * 0.02)
		if offset != CampaignCues.SKIP:
			heard += 1
			if offset < 0.0:
				quiet += 1
	assert_lte(heard, 12, "a sweep plays a sparkle, not 75 ticks (%d)" % heard)
	assert_gte(heard, 5, "but it is heard")
	assert_gt(quiet, 0, "and the burst steps back")


func test_saves_are_confirmed_sparingly() -> void:
	var cues: CampaignCues = CampaignCues.new()
	assert_true(cues.save_allowed(&"autosave", 0.0))
	assert_false(cues.save_allowed(&"autosave", 30.0), "autosaves happen often")
	assert_true(cues.save_allowed(&"slot_1", 30.0), "a save the player asked for")
	assert_false(cues.save_allowed(&"slot_1", 31.0))
	assert_true(cues.save_allowed(&"slot_1", 33.0))
	assert_true(cues.save_allowed(&"Auto_2", 61.0))


func test_ship_details_vary() -> void:
	var last: StringName = &""
	var seen: Dictionary[StringName, bool] = {}
	for i: int in 200:
		var kind: StringName = CampaignCues.pick_detail(float(i % 97) / 97.0, last)
		assert_ne(kind, last, "never the same detail twice running")
		seen[kind] = true
		last = kind
	assert_eq(seen.size(), CampaignCues.DETAILS.size(), "every detail comes up")
	assert_gt(
		CampaignCues.detail_gap(0.5, CampaignCues.TITLE),
		CampaignCues.detail_gap(0.5, CampaignCues.MERIDIAN),
		"further from the hull on the title"
	)


# --- Router -----------------------------------------------------------------------


func test_hovers_go_through_the_limiter() -> void:
	assert_eq(_router.handle_ui_feedback(&"map_node_hover", 0.0), &"ui_map_node_hover")
	assert_eq(_router.handle_ui_feedback(&"tech_hover", 0.02), &"", "rate-limited")
	assert_eq(_router.handle_ui_feedback(&"tech_hover", 0.2), &"ui_tech_hover")
	assert_eq(_router.handle_ui_feedback(&"map_node_select", 0.3), &"", "the naming rule's")


func test_the_event_router_leaves_hovers_to_the_campaign() -> void:
	var events: AudioEventRouter = AudioEventRouter.new()
	var heard: Array[StringName] = []
	events.play_first = func(ids: Array[StringName], _at: Vector3) -> StringName:
		heard.append(ids[0])
		return ids[0]
	add_child_autofree(events)
	events.set_process(false)
	Events.ui_feedback.emit(&"map_node_hover")
	Events.ui_feedback.emit(&"tech_hover")
	assert_eq(heard, [] as Array[StringName])
	for kind: StringName in [
		&"title_open",
		&"map_open",
		&"map_node_select",
		&"map_launch",
		&"tech_open",
		&"tech_buy",
		&"loadout_open",
		&"loadout_change",
	]:
		Events.ui_feedback.emit(kind)
		assert_eq(heard[-1], StringName("ui_%s" % kind))
	assert_eq(
		AudioCueSelector.feedback_event(&"tech_denied"),
		[&"ui_tech_denied", &"ui_invalid"] as Array[StringName]
	)


func test_launch_starts_the_hand_over() -> void:
	_router.handle_ui_feedback(&"map_launch", 0.0)
	assert_eq(_launches, 1)


func test_tech_seal_never_doubles() -> void:
	# The purchase click carries the seal: an unlock signal with it is silent,
	# whichever comes first.
	_router.handle_ui_feedback(&"tech_buy", 1.0)
	_router.handle_tech_unlocked(1.01)
	assert_eq(_router.update(3.0), &"")
	_router.handle_tech_unlocked(10.0)
	_router.handle_ui_feedback(&"tech_buy", 10.1)
	assert_eq(_router.update(12.0), &"")
	# A tech granted without a click: the seal alone, a moment later.
	_router.handle_tech_unlocked(20.0)
	assert_eq(_router.update(20.1), &"")
	assert_eq(_router.update(20.0 + CampaignCues.TECH_PAIR_WINDOW), &"ui_tech_unlocked")
	assert_eq(_router.update(30.0), &"", "once")


func test_return_phrase_waits_for_the_ship() -> void:
	_router.handle_screen_changed(&"", 0.0)
	_router.handle_landing_resolved(true, 100.0)
	assert_eq(_offered, [] as Array[StringName], "not over the debrief")
	assert_eq(_router.pending_return(), &"campaign_return_won")
	_router.handle_screen_changed(&"star_map", 140.0)
	assert_eq(_offered, [&"campaign_return_won"] as Array[StringName])
	assert_eq(_router.pending_return(), &"")
	_router.handle_screen_changed(&"meridian", 150.0)
	assert_eq(_offered.size(), 1, "once")


func test_return_phrase_does_not_stack_on_the_ending_sting() -> void:
	_router.handle_screen_changed(&"", 0.0)
	_router.note_ending_sting(100.0)
	_router.handle_landing_resolved(false, 100.5)
	_router.handle_screen_changed(&"star_map", 104.0)
	assert_eq(_offered, [] as Array[StringName], "the verdict was just heard")
	# Resolved while aboard (no debrief): voiced at once.
	_router.handle_landing_resolved(false, 200.0)
	assert_eq(_offered, [&"campaign_return_lost"] as Array[StringName])


func test_a_new_landing_or_a_load_drops_what_was_pending() -> void:
	_router.handle_screen_changed(&"", 0.0)
	_router.handle_landing_resolved(true, 10.0)
	_router.handle_tech_unlocked(10.0)
	Events.mission_started.emit()
	assert_eq(_router.pending_return(), &"")
	assert_eq(_router.update(20.0), &"")
	_router.handle_landing_resolved(true, 30.0)
	Events.campaign_loaded.emit(&"slot_1")
	assert_eq(_router.pending_return(), &"")


func test_saves_are_rate_limited_in_the_router() -> void:
	assert_true(_router.handle_campaign_saved(&"autosave", 0.0))
	assert_false(_router.handle_campaign_saved(&"autosave", 5.0))
	assert_eq(_played, [&"ui_campaign_saved"] as Array[StringName])


func test_screens_are_forwarded() -> void:
	Events.campaign_screen_changed.emit(&"tech_web")
	assert_eq(_screens, [&"tech_web"] as Array[StringName])
	assert_eq(_router.screen(), &"tech_web")


# --- Advisor ----------------------------------------------------------------------


func test_campaign_advisor_kinds_are_ranked_and_queued() -> void:
	for kind: StringName in [
		&"campaign_route_open",
		&"campaign_tech_available",
		&"campaign_intel_banked",
		&"campaign_return_won",
		&"campaign_return_lost",
	]:
		assert_true(AdvisorQueue.THROTTLE.has(kind), "%s throttled" % kind)
		assert_true(AdvisorQueue.PRIORITY.has(kind), "%s ranked" % kind)
		var event: SoundEvent = _event("advisor", "advisor_%s" % kind)
		assert_not_null(event, String(kind))
		if event != null:
			assert_eq(event.bus, &"Advisor")
	# Home first, then what it brought, then the way on; none on top of another.
	var queue: AdvisorQueue = AdvisorQueue.new()
	assert_true(queue.push(&"campaign_route_open", 0.0))
	assert_true(queue.push(&"campaign_intel_banked", 0.0))
	assert_true(queue.push(&"campaign_return_won", 0.0))
	assert_eq(queue.pop_ready(0.0), &"campaign_return_won")
	var won: SoundEvent = _event("advisor", "advisor_campaign_return_won")
	queue.started(0.0, won.longest_seconds())
	assert_eq(queue.pop_ready(0.5), &"", "one phrase at a time")
	var after: float = won.longest_seconds() + AdvisorQueue.GAP
	assert_eq(queue.pop_ready(after), &"campaign_intel_banked")
	var banked: SoundEvent = _event("advisor", "advisor_campaign_intel_banked")
	queue.started(after, banked.longest_seconds())
	var third: float = after + banked.longest_seconds() + AdvisorQueue.GAP
	assert_lt(third, AdvisorQueue.MAX_WAIT, "the third phrase is still fresh")
	assert_eq(queue.pop_ready(third), &"campaign_route_open")
	assert_false(queue.push(&"campaign_return_lost", 1.0), "won and lost share a throttle")


# --- Data -------------------------------------------------------------------------


func test_campaign_events_exist_on_their_buses() -> void:
	var expected: Dictionary[String, StringName] = {
		"ambience/amb_ship_hum": &"Ambience",
		"ambience/amb_ship_air": &"Ambience",
		"shipdetail/amb_ship_relay": &"Ambience",
		"shipdetail/amb_ship_creak": &"Ambience",
		"shipdetail/amb_ship_machine": &"Ambience",
		"shipdetail/amb_ship_ping": &"Ambience",
	}
	for kind: String in [
		"title_open",
		"map_open",
		"map_node_hover",
		"map_node_select",
		"map_launch",
		"tech_open",
		"tech_hover",
		"tech_buy",
		"tech_unlocked",
		"tech_denied",
		"loadout_open",
		"loadout_change",
		"campaign_saved",
	]:
		expected["ui/ui_%s" % kind] = &"UI"
	for path: String in expected:
		var parts: PackedStringArray = path.split("/")
		var event: SoundEvent = _event(parts[0], parts[1])
		assert_not_null(event, path)
		if event == null:
			continue
		assert_eq(event.bus, expected[path], "%s bus" % path)
		assert_false(event.streams.is_empty(), "%s has streams" % path)
		assert_false(event.positional, "%s is flat" % path)
	assert_gt(_event("ui", "ui_map_node_hover").streams.size(), 2, "hover variations")
	assert_gt(_event("shipdetail", "amb_ship_relay").streams.size(), 1, "relay variations")
	for bed: String in ["amb_ship_hum", "amb_ship_air"]:
		var ogg: AudioStreamOggVorbis = _event("ambience", bed).streams[0] as AudioStreamOggVorbis
		assert_true(ogg.loop, "%s loops" % bed)
