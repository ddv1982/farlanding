## Autoload `Audio`: the only way sound gets played. Gameplay never calls this for
## its own events — `audio/` listens to `Events` and decides what is heard. The
## public surface below is a contract other systems rely on.
##
## Inside: every SoundEvent under `res://data/sounds/` is registered by id at
## startup. Flat (interface, replies, Advisor) and positional sounds each have a
## pool of players behind a VoiceBudget (priority stealing, per-event caps and
## cooldowns). An AudioListener3D sits above the camera's ground focus point;
## zoom moves it up and reshapes bus levels (AudioMix). Child nodes: the
## AudioEventRouter (Events -> sounds, Advisor alert queue), MovementLoops,
## BaseLoops (construction, production, mining, building hum), the
## MusicDirector, the SignalPulses (discovery-site pulses and scan loops) and
## the DiscoverySoundRouter (resolve phrases, Intel, field options, codex).
## While a discovery resolves, a BusDucker briefly lowers music, ambience and
## effects. Phase 5 adds the StealthSoundRouter (alert stingers, spotted,
## cloaks, the stealth music mood), SuspicionTones (the watchers' rising tone)
## and the MissionSoundRouter (objectives, briefing and debrief beds, launch,
## storm). The combat and stealth moods both ask for music states; a
## MusicArbiter decides which one plays. Phase 6 adds the StormSound (the dust
## storm's beds, gusts, debris, the world muffle and its release), the
## AmbienceDirector (layered, wandering planet beds and positional details),
## the score's urgency layer while the base is under attack, transition hits
## on the beat (ScoreTransitions) and the pause and menu mix overlays.
## Phase 7 adds the CampaignSoundRouter: aboard the Meridian between landings
## (any campaign screen) the ship score plays in that screen's state, the
## AmbienceDirector plays the ship, and the ship mix applies; a landing hands
## back to the planet's score (`switch_score`: one player, never two scores).
## Phase 8a adds the planets as data (PlanetAudio: score and ambience set per
## planet id, `play_planet`; found by itself from the running mission when a
## mission starts), the TideSound (Thalassa's tide: water beds, rush and pull,
## the turning warnings, the score's tide layer) and score-specific transition
## hits and ending stings (`<hit>_<score id>` before the generic one).
## Phase 8b adds Emberfall: the EruptionSound (child "Eruption": vent
## build-ups, blasts, the score's pressure layer) and the HoldoutSound (child
## "Holdout": the survival timer's holdout layer, one-minute cue, approaching
## engine and arrival). Both are reached by name; the public surface is full.
extends Node

const EVENTS_DIR: String = "res://data/sounds"
const DEFAULT_SCORE: String = "res://data/sounds/music/kessel_reach.tres"
const SHIP_SCORE: String = "res://data/sounds/music/meridian.tres"
## Leaving the ship, the planet's score comes in at the briefing bed's level
## and waits there for the briefing (or the mission) to set it.
const LANDING_DIP_DB: float = MissionSoundRouter.BRIEFING_DUCK_DB
const FLAT_VOICES: int = 16
const POSITIONAL_VOICES: int = 32
## Zoom changes smaller than this do not touch the bus volumes.
const ZOOM_EPSILON: float = 0.01
## The music layer that surfaces as discovery sites are resolved.
const TRAIL_LAYER: StringName = &"trail"
## The music layer of the Survey storm (silent until the storm warning).
const STORM_LAYER: StringName = &"storm"
## The score layer that urges while the base is under attack.
const URGENCY_LAYER: StringName = &"urgency"
## The music layer of the tide (Thalassa), following the water level.
const TIDE_LAYER: StringName = &"tide"
## Emberfall's layer that rises as a vent near the base fills.
const PRESSURE_LAYER: StringName = &"pressure"
## The score layer of a Holdout's last minutes.
const HOLDOUT_LAYER: StringName = &"holdout"
## How long the urgency layer stays after an under-attack alert (s).
const URGENCY_HOLD: float = 24.0
## The objective type whose failure means the rival won the Intel race.
const RIVAL_INTEL_TYPE: StringName = &"rival_intel"
## The score dips this far under an ending sting.
const STING_DIP_DB: float = -6.0

var _events: Dictionary[StringName, SoundEvent] = {}
var _last_variation: Dictionary[StringName, int] = {}
var _flat_budget: VoiceBudget = VoiceBudget.new(FLAT_VOICES)
var _positional_budget: VoiceBudget = VoiceBudget.new(POSITIONAL_VOICES)
var _flat_players: Array[AudioStreamPlayer] = []
var _positional_players: Array[AudioStreamPlayer3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _listener: AudioListener3D
var _listener_active: bool = false
var _focus: Vector3 = Vector3.ZERO
var _zoom: float = 0.5
var _applied_zoom: float = -1.0
var _router: AudioEventRouter
var _combat: CombatSoundRouter
var _loops: MovementLoops
var _base_loops: BaseLoops
var _music: MusicDirector
var _pulses: SignalPulses
var _discovery: DiscoverySoundRouter
var _stealth: StealthSoundRouter
var _tones: SuspicionTones
var _missions: MissionSoundRouter
var _ducker: BusDucker = BusDucker.new()
var _ducking: bool = false
var _combat_music: StringName = MusicMood.EXPLORE
var _stealth_music: StringName = &""
var _storm: StormSound
var _ambience: AmbienceDirector
var _paused: bool = false
var _menu: bool = false
var _muffle: float = 0.0
var _storm_mission_db: float = AudioMix.SILENT_DB
var _storm_weather_db: float = AudioMix.SILENT_DB
var _urgency_until: float = -INF
var _outsurveyed: bool = false
var _campaign: CampaignSoundRouter
var _ship: bool = false
var _ship_score: MusicScore
var _planet_score: MusicScore
var _planet_ambience: AmbienceSet
var _tide: TideSound
var _eruption: EruptionSound
var _holdout: HoldoutSound


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_events(EVENTS_DIR)
	_build_pools()
	_listener = AudioListener3D.new()
	_listener.name = &"Listener"
	add_child(_listener)
	_router = AudioEventRouter.new()
	_router.name = &"EventRouter"
	_router.play_first = play_first
	_router.event_seconds = func(event_id: StringName) -> float:
		var event: SoundEvent = get_event(event_id)
		return event.longest_seconds() if event != null else 0.0
	add_child(_router)
	_combat = CombatSoundRouter.new()
	_combat.name = &"CombatRouter"
	_combat.resolve_event = get_event
	_combat.play_at = play_at
	_combat.offer_alert = func(kind: StringName, at: Vector3) -> void:
		_router.offer_advisor_alert(kind, _now(), at)
	_combat.set_music_state = func(state: StringName) -> void:
		_combat_music = state
		_request_music()
	_combat.end_music = _end_music
	_router.alert_position = func(_kind: StringName) -> Vector3:
		return _combat.last_hurt_position(_now())
	add_child(_combat)
	_loops = MovementLoops.new()
	_loops.name = &"MovementLoops"
	_loops.resolve_event = get_event
	add_child(_loops)
	_base_loops = BaseLoops.new()
	_base_loops.name = &"BaseLoops"
	_base_loops.resolve_event = get_event
	_base_loops.play_at = play_at
	add_child(_base_loops)
	_music = MusicDirector.new()
	_music.name = &"MusicDirector"
	add_child(_music)
	_music.set_layer_gain(STORM_LAYER, AudioMix.SILENT_DB)
	_music.set_layer_gain(URGENCY_LAYER, AudioMix.SILENT_DB)
	_music.set_layer_gain(TIDE_LAYER, AudioMix.SILENT_DB)
	_music.set_layer_gain(PRESSURE_LAYER, AudioMix.SILENT_DB)
	_music.set_layer_gain(HOLDOUT_LAYER, AudioMix.SILENT_DB)
	_router.on_alert_played = _on_alert_played
	_pulses = SignalPulses.new()
	_pulses.name = &"SignalPulses"
	_pulses.resolve_event = get_event
	_pulses.play_at = play_at
	add_child(_pulses)
	_discovery = DiscoverySoundRouter.new()
	_discovery.name = &"DiscoveryRouter"
	_discovery.play_first = play_first
	_discovery.event_seconds = _router.event_seconds
	_discovery.duck = duck_for
	_discovery.set_trail_gain = func(gain_db: float) -> void:
		_music.set_layer_gain(TRAIL_LAYER, gain_db)
	add_child(_discovery)
	_stealth = StealthSoundRouter.new()
	_stealth.name = &"StealthRouter"
	_stealth.play_first = play_first
	_stealth.duck = duck_for
	_stealth.set_music_state = func(state: StringName) -> void:
		_stealth_music = state
		_request_music()
	add_child(_stealth)
	_tones = SuspicionTones.new()
	_tones.name = &"SuspicionTones"
	_tones.resolve_event = get_event
	add_child(_tones)
	_missions = MissionSoundRouter.new()
	_missions.name = &"MissionRouter"
	_missions.play_first = play_first
	_missions.offer_alert = func(kind: StringName) -> void:
		_router.offer_advisor_alert(kind, _now())
	_missions.play_bed = play_bed
	_missions.stop_bed = _music.stop_bed
	_missions.set_layer_gain = func(layer: StringName, gain_db: float) -> void:
		if layer == STORM_LAYER:
			_storm_mission_db = gain_db
			_apply_storm_layer()
		else:
			_music.set_layer_gain(layer, gain_db)
	add_child(_missions)
	_storm = StormSound.new()
	_storm.name = &"Storm"
	_storm.resolve_event = get_event
	_storm.play_first = play_first
	_storm.play_at = play_at
	_storm.set_music_gain = func(gain_db: float) -> void:
		_storm_weather_db = gain_db
		_apply_storm_layer()
	_storm.set_muffle = set_muffle
	add_child(_storm)
	_ambience = AmbienceDirector.new()
	_ambience.name = &"Ambience"
	_ambience.resolve_event = get_event
	_ambience.play_at = play_at
	add_child(_ambience)
	_storm.set_ambience_cover = _ambience.set_storm_cover
	_tide = TideSound.new()
	_tide.name = &"Tide"
	_tide.resolve_event = get_event
	_tide.play_first = play_first
	_tide.set_music_gain = func(gain_db: float) -> void: _music.set_layer_gain(TIDE_LAYER, gain_db)
	_tide.set_ambience_tide = _ambience.set_tide
	add_child(_tide)
	_eruption = EruptionSound.new()
	_eruption.name = &"Eruption"
	_eruption.resolve_event = get_event
	_eruption.duck = duck_for
	_eruption.set_music_gain = func(gain_db: float) -> void:
		_music.set_layer_gain(PRESSURE_LAYER, gain_db)
	add_child(_eruption)
	_holdout = HoldoutSound.new()
	_holdout.name = &"Holdout"
	_holdout.play_first = play_first
	_holdout.resolve_event = get_event
	_holdout.set_music_gain = func(gain_db: float) -> void:
		_music.set_layer_gain(HOLDOUT_LAYER, gain_db)
	add_child(_holdout)
	_campaign = CampaignSoundRouter.new()
	_campaign.name = &"CampaignRouter"
	_campaign.play_first = play_first
	_campaign.play_at = play_at
	_campaign.offer_alert = func(kind: StringName) -> void:
		_router.offer_advisor_alert(kind, _now())
	_campaign.show_screen = _show_screen
	_campaign.launch = _on_launch
	add_child(_campaign)
	if ResourceLoader.exists(SHIP_SCORE):
		_ship_score = load(SHIP_SCORE)
	Events.ui_feedback.connect(_on_ui_feedback)
	Events.mission_started.connect(_on_mission_started)
	Events.objective_failed.connect(_on_objective_failed)
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()
	if ResourceLoader.exists(DEFAULT_SCORE):
		var score: MusicScore = load(DEFAULT_SCORE)
		play_score(score)
	# Added last so it leaves the tree first (siblings exit in reverse order).
	var guard: ShutdownGuard = ShutdownGuard.new()
	guard.name = &"ShutdownGuard"
	guard.target = self
	add_child(guard)


## Plays a sound event by id. Leave `position` at Vector3.INF for non-positional
## sounds (interface, advisor).
func play(event_id: StringName, position: Vector3 = Vector3.INF) -> void:
	_start(event_id, position)


## Called by the camera every frame. `focus` is the ground point the camera looks
## at; `zoom` runs from 0 (closest) to 1 (furthest) and shapes the mix.
func set_listener_focus(focus: Vector3, zoom: float) -> void:
	_focus = focus
	_zoom = clampf(zoom, 0.0, 1.0)
	_listener.global_position = focus + Vector3.UP * AudioMix.listener_height(_zoom)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var yaw: float = camera.global_rotation.y if camera != null else 0.0
	_listener.global_basis = Basis(Vector3.UP, yaw)
	if not _listener_active:
		_listener.make_current()
		_listener_active = true
	_loops.focus = focus
	_base_loops.focus = focus
	_router.focus = focus
	_combat.focus = focus
	_pulses.focus = focus
	_pulses.zoom = _zoom
	_tones.focus = focus
	_storm.focus = focus
	_ambience.focus = focus
	_eruption.focus = focus
	if absf(_zoom - _applied_zoom) >= ZOOM_EPSILON:
		_apply_volumes()


## Requests a music state, e.g. &"explore", &"tension", &"combat".
func set_music_state(state: StringName) -> void:
	_music.set_state(state)


# --- Additions beyond the original contract -----------------------------------


## Starts a planet's score at once (and the ambience of the planet whose id
## the score carries, else Kessel Reach's). Aboard the ship it is only
## remembered: it plays when the landing takes over.
func play_score(score: MusicScore) -> void:
	_planet_score = score
	var planet: PlanetAudio = PlanetAudio.find(score.id) if score != null else null
	_planet_ambience = planet.ambience if planet != null else AmbienceCues.kessel()
	if _ship:
		return
	# The ambience is the AmbienceDirector's (layered, wandering beds).
	_music.play_score(score, null)
	_ambience.start(_planet_ambience)


## Makes `planet_id`'s score and ambience the planet's (PlanetAudio, from
## `res://data/sounds/planets/<id>.tres`): the score fades over from whatever
## plays, the ambience changes if it is another planet's. Nothing changes for
## an id without a file, or for the planet already playing. Aboard the ship it
## is only remembered. Called by the AudioService itself when a mission starts.
func play_planet(planet_id: StringName) -> void:
	var planet: PlanetAudio = PlanetAudio.find(planet_id)
	if planet == null or planet.score == null:
		return
	_planet_score = planet.score
	_planet_ambience = planet.ambience if planet.ambience != null else AmbienceCues.kessel()
	if _ship:
		return
	if _music.target_score() != planet.score:
		_music.switch_score(planet.score)
	if _ambience.ambience_set() != _planet_ambience:
		_ambience.start(_planet_ambience)


## Shows a campaign screen (Phase 7): any screen but &"" is aboard the ship.
## Driven by `Events.campaign_screen_changed` (CampaignSoundRouter).
func _show_screen(screen: StringName) -> void:
	if not CampaignCues.is_ship_screen(screen):
		_leave_ship(true)
		return
	var state: StringName = CampaignCues.music_state(screen)
	if not _missions.is_menu_open():
		_music.stop_bed()  # the debrief's bed, or a hand-over dip
	if _ship:
		_music.switch_score(_ship_score, state)
		_ambience.set_ship_screen(screen)
		return
	_ship = true
	_missions.handle_left_landing()
	_stop_world_voices()
	_storm.handle_mission_started()  # a storm left behind on the planet ends
	_tide.handle_mission_started()  # and so does the sea
	_eruption.handle_mission_started()  # and the vents
	_holdout.handle_mission_started()
	if _ship_score != null:
		_music.switch_score(_ship_score, state)
	_ambience.start_ship(screen)
	_apply_volumes()


func has_event(event_id: StringName) -> bool:
	return _events.has(event_id)


func get_event(event_id: StringName) -> SoundEvent:
	var event: SoundEvent = _events.get(event_id, null)
	return event


## Plays a positional event with an extra volume offset (combat ducking).
## Returns true if it started.
func play_at(event_id: StringName, position: Vector3, volume_offset_db: float = 0.0) -> bool:
	return _start(event_id, position, volume_offset_db)


## Plays the first candidate that exists as an event; returns its id or &"".
func play_first(candidates: Array[StringName], position: Vector3 = Vector3.INF) -> StringName:
	for event_id: StringName in candidates:
		if _events.has(event_id):
			_start(event_id, position)
			return event_id
	return &""


## Briefly lowers music, ambience and effects for `hold` seconds (plus a
## release), so a discovery phrase stands out.
func duck_for(hold: float) -> void:
	_ducker.duck(_now(), hold)
	_ducking = true
	_apply_volumes()


## Current duck offset of a bus in dB (0 when not ducked), for tests.
func duck_offset_db(bus: StringName) -> float:
	return _ducker.offset_db(bus, _now())


## Loops the stream of bed event `event_id` under a panel (briefing, debrief),
## dipping the score by `duck_db`.
func play_bed(event_id: StringName, duck_db: float) -> void:
	var event: SoundEvent = get_event(event_id)
	if event != null and not event.streams.is_empty():
		_music.play_bed(event.streams[0], duck_db)


## The music state requested last (after merging combat and stealth), for tests.
func music_state() -> StringName:
	return _music.current_state()


## Applies the storm's world muffle (0 clear .. 1 full): a low-pass on the SFX
## and Ambience buses and a level dip (StormCues). Unit replies, the Advisor,
## the interface and the stingers are on other buses and stay clear.
func set_muffle(amount: float) -> void:
	var clamped: float = clampf(amount, 0.0, 1.0)
	if is_equal_approx(clamped, _muffle):
		return
	_muffle = clamped
	var cutoff: float = StormCues.muffle_cutoff_hz(_muffle)
	for bus: StringName in AudioMix.MUFFLED_BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		var effect: int = _effect_index(index, AudioMix.MUFFLE_EFFECT)
		if effect < 0:
			continue
		var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(index, effect)
		filter.cutoff_hz = cutoff
		AudioServer.set_bus_effect_enabled(index, effect, _muffle > 0.001)
	_apply_volumes()


func muffle() -> float:
	return _muffle


## The storm (for the mix test and tests): its node.
func storm() -> StormSound:
	return _storm


func ambience() -> AmbienceDirector:
	return _ambience


func music() -> MusicDirector:
	return _music


## Stops every one-shot and every world loop (movement, base, signal and
## suspicion loops) at once; the score, the ambience and the storm go on. For
## leaving a mission mid-sound and for tests that measure the mix.
func stop_all_voices() -> void:
	for i: int in _flat_players.size():
		_flat_players[i].stop()
		_flat_budget.release(i)
	for i: int in _positional_players.size():
		_positional_players[i].stop()
		_positional_budget.release(i)
	for node: Node in [_loops, _base_loops, _pulses, _tones]:
		ShutdownGuard._stop_all(node)
	_ducker = BusDucker.new()
	_ducking = false
	_apply_volumes()


## Voices in use (flat + positional), for the debug overlay and tests.
func active_voices() -> int:
	return _flat_budget.active_count() + _positional_budget.active_count()


# --- Internals ----------------------------------------------------------------


func _process(_delta: float) -> void:
	if _ducking:
		_ducking = _ducker.is_active(_now())
		_apply_volumes()
	if _urgency_until != -INF and _now() >= _urgency_until:
		_urgency_until = -INF
		_music.set_layer_gain(URGENCY_LAYER, AudioMix.SILENT_DB)


func _start(event_id: StringName, position: Vector3, volume_offset_db: float = 0.0) -> bool:
	var event: SoundEvent = _events.get(event_id, null)
	if event == null or event.streams.is_empty():
		return false
	var positional: bool = event.positional and position.is_finite()
	if positional and _listener_active and event.max_distance > 0.0:
		if Vector2(position.x - _focus.x, position.z - _focus.z).length() > event.max_distance:
			return false
	var last: int = _last_variation.get(event_id, -1)
	var index: int = SoundEvent.pick_index(
		event.streams.size(), last, _rng.randf(), event.avoid_repeat
	)
	var stream: AudioStream = event.streams[index]
	var pitch: float = 1.0
	if event.pitch_variation > 0.0:
		pitch = pow(2.0, _rng.randf_range(-event.pitch_variation, event.pitch_variation) / 12.0)
	var budget: VoiceBudget = _positional_budget if positional else _flat_budget
	var voice: int = (
		budget
		. request(
			event_id,
			event.priority,
			event.max_instances,
			event.cooldown,
			stream.get_length() / pitch,
			_now(),
		)
	)
	if voice == VoiceBudget.REJECTED:
		return false
	_last_variation[event_id] = index
	if positional:
		var player3d: AudioStreamPlayer3D = _positional_players[voice]
		player3d.stop()
		player3d.stream = stream
		player3d.bus = event.bus
		player3d.volume_db = event.volume_db + volume_offset_db
		player3d.pitch_scale = pitch
		player3d.max_distance = event.max_distance
		player3d.global_position = position
		player3d.play()
	else:
		var player: AudioStreamPlayer = _flat_players[voice]
		player.stop()
		player.stream = stream
		player.bus = event.bus
		player.volume_db = event.volume_db + volume_offset_db
		player.pitch_scale = pitch
		player.play()
	return true


func _register_events(dir_path: String) -> void:
	for entry: String in ResourceLoader.list_directory(dir_path):
		var path: String = dir_path.path_join(entry)
		if entry.ends_with("/"):
			_register_events(path.trim_suffix("/"))
			continue
		if not (entry.ends_with(".tres") or entry.ends_with(".res")):
			continue
		var event: SoundEvent = load(path) as SoundEvent
		if event == null:
			continue
		if event.id == &"" or _events.has(event.id):
			push_error("Audio: SoundEvent %s has an empty or duplicate id '%s'" % [path, event.id])
			continue
		_events[event.id] = event


func _build_pools() -> void:
	for i: int in FLAT_VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Flat%d" % i
		player.finished.connect(_flat_budget.release.bind(i))
		add_child(player)
		_flat_players.append(player)
	for i: int in POSITIONAL_VOICES:
		var player3d: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player3d.name = "Positional%d" % i
		player3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player3d.unit_size = 10.0
		player3d.finished.connect(_positional_budget.release.bind(i))
		add_child(player3d)
		_positional_players.append(player3d)


func _apply_volumes() -> void:
	_applied_zoom = _zoom
	var zoom: float = AudioMix.SHIP_ZOOM if _ship else _zoom
	var now: float = _now()
	for i: int in AudioServer.bus_count:
		var bus: StringName = AudioServer.get_bus_name(i)
		var setting: float = 1.0
		if AudioMix.SETTING_FOR_BUS.has(bus):
			var value: Variant = Settings.get(AudioMix.SETTING_FOR_BUS[bus])
			if value is float:
				setting = value
		var volume: float = AudioMix.bus_volume_db(bus, setting, zoom)
		if volume > AudioMix.SILENT_DB:
			volume += _ducker.offset_db(bus, now)
			volume += AudioMix.overlay_db(bus, _paused, _menu, _muffle)
			if _ship:
				volume = maxf(volume + AudioMix.ship_db(bus), AudioMix.SILENT_DB)
		AudioServer.set_bus_volume_db(i, volume)


## Mission over: the music settles into its victory or defeat state (quieter
## layers, at once) and the matching sting plays over it.
func _end_music(won: bool) -> void:
	_storm.handle_mission_ended(won)
	_music.force_state(MusicMood.VICTORY if won else MusicMood.DEFEAT)
	var storm_level: float = maxf(_storm.intensity(), _storm.cues.target)
	var played: StringName = play_first(
		_voiced(StormCues.ending_stings(won, storm_level, _outsurveyed))
	)
	if played != &"":
		_music.dip_for(get_event(played).longest_seconds(), STING_DIP_DB)
		_campaign.note_ending_sting(_now())


## Merges the combat and stealth moods and, when the state changes in a way a
## fade cannot hide, plays a transition hit on the next beat.
func _request_music() -> void:
	var before: StringName = _music.current_state()
	_music.set_state(MusicArbiter.pick(_combat_music, _stealth_music))
	var after: StringName = _music.current_state()
	var hit: StringName = ScoreTransitions.hit_for(before, after)
	if hit != &"":
		var hits: Array[StringName] = _voiced([hit])
		_music.at_next_beat(func() -> void: play_first(hits))


## The storm layer follows whichever asks for more: the mission deadline
## (Survey's minute warning) or the weather itself.
func _apply_storm_layer() -> void:
	_music.set_layer_gain(STORM_LAYER, maxf(_storm_mission_db, _storm_weather_db))


func _on_alert_played(kind: StringName) -> void:
	if kind == &"under_attack":
		_urgency_until = _now() + URGENCY_HOLD
		_music.set_layer_gain(URGENCY_LAYER, 0.0)


func _on_ui_feedback(kind: StringName) -> void:
	match kind:
		&"pause_open":
			_paused = true
		&"pause_close":
			_paused = false
		&"menu_open":
			_menu = true
		&"menu_close", &"briefing_open":
			_menu = false
		_:
			return
	_apply_volumes()


func _on_mission_started() -> void:
	# A mission is a landing: if the campaign did not say so, leave the ship
	# now (no hand-over dip: the mission router has set the score's level).
	_leave_ship(false)
	_paused = false
	_menu = false
	_urgency_until = -INF
	_outsurveyed = false
	_music.set_layer_gain(URGENCY_LAYER, AudioMix.SILENT_DB)
	_apply_volumes()
	# The map sets its mission before it announces the start: read the planet
	# once the frame's setup is done.
	_detect_planet.call_deferred()


## The planet of the mission that just started, from the running map (nothing
## changes if none is found: the planet playing stays).
func _detect_planet() -> void:
	if not is_inside_tree():
		return
	var planet_id: StringName = PlanetAudio.planet_id_in(get_tree().current_scene)
	if planet_id != &"":
		play_planet(planet_id)


## `ids` with the playing score's own versions first (ScoreTransitions.voiced).
func _voiced(ids: Array[StringName]) -> Array[StringName]:
	return ScoreTransitions.voiced(ids, _music.score.id if _music.score != null else &"")


## The loss reason for the ending sting: the rival banked its Intel first. Read
## by name so audio does not depend on the mission classes.
func _on_objective_failed(objective: RefCounted) -> void:
	if objective == null:
		return
	var def: Variant = objective.get(&"def")
	if def is Resource:
		var resource: Resource = def
		if resource.get(&"type") == RIVAL_INTEL_TYPE:
			_outsurveyed = true


## Back to the planet: its score fades in where the ship's fades out (with the
## hand-over dip when `hold_dip`), its ambience returns, the ship mix lifts.
func _leave_ship(hold_dip: bool) -> void:
	if not _ship:
		return
	_ship = false
	if _planet_score != null:
		_music.switch_score(_planet_score, &"", LANDING_DIP_DB if hold_dip else 0.0)
	_ambience.start(_planet_ambience)
	_apply_volumes()


## Launch confirmed on the star map: the ship's music starts handing over to
## the planet at once, under the launch gesture; the ambience waits for the
## landing screen.
func _on_launch() -> void:
	if _ship and _planet_score != null:
		_music.switch_score(_planet_score, &"", LANDING_DIP_DB)


## Stops the world's one-shots (the positional pool) and loops; interface,
## Advisor and stings (the flat pool) ring on.
func _stop_world_voices() -> void:
	for i: int in _positional_players.size():
		_positional_players[i].stop()
		_positional_budget.release(i)
	for node: Node in [_loops, _base_loops, _pulses, _tones]:
		ShutdownGuard._stop_all(node)


static func _effect_index(bus_index: int, effect_name: StringName) -> int:
	if bus_index < 0:
		return -1
	for i: int in AudioServer.get_bus_effect_count(bus_index):
		if AudioServer.get_bus_effect(bus_index, i).resource_name == effect_name:
			return i
	return -1


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Leaves the tree before the players do. A player that leaves the tree only
## pauses its stream, and on quit the audio server shuts down before the mixer
## frees paused streams, which then show up as leaked. So: stop everything
## while still in the tree, and give the mix thread a moment to let go.
class ShutdownGuard:
	extends Node

	const GRACE_MSEC: int = 100

	var target: Node

	func _exit_tree() -> void:
		if target != null and _stop_all(target) > 0:
			OS.delay_msec(GRACE_MSEC)

	## Stops every player under `node` (a real stop, not the pause a player does
	## when it leaves the tree). Returns how many were playing.
	static func _stop_all(node: Node) -> int:
		var count: int = 0
		for child: Node in node.get_children():
			count += _stop_all(child)
			var flat: AudioStreamPlayer = child as AudioStreamPlayer
			if flat != null and flat.playing:
				flat.stop()
				count += 1
			var spatial: AudioStreamPlayer3D = child as AudioStreamPlayer3D
			if spatial != null and spatial.playing:
				spatial.stop()
				count += 1
		return count
