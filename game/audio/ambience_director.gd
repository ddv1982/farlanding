class_name AmbienceDirector
extends Node
## The planet's ambience (Phase 6): layered beds that wander and positional
## details around the listener, shaped by where the camera is. Rules in
## AmbienceCues; this node measures the context and plays.
##
## Context, re-read every SCAN_INTERVAL from scene groups (duck-typed, all
## optional): the nearest Flux node (group `resource_nodes`, `resource()` ==
## &"flux"); the nearest Antecedent site (group `discovery_sites`,
## `discovery_type` == &"antecedent"); the nearest building of another faction
## (group `buildings`) that the player has seen (`is_visible_to_player` true
## at least once this mission). The storm's cover comes from StormSound.
##
## Beds loop on this node's own players (Ambience bus): the score's ambience
## event (the base wind), `amb_kessel_air` and `amb_kessel_hush`. Details are
## positional one-shots (`play_at`): free kinds on a ring around the listener,
## vents at the Flux node, industry at the Combine building.
##
## Ship mode (Phase 7, `start_ship`): between landings the planet beds fade
## out and the Meridian's beds fade in on their own players (hull hum and air
## handling, wandering like the planet's), with flat ship details (relay ticks,
## hull creaks, a far machine, a cooling pipe; the pan is in the files) every
## 5-12 s. Rules in CampaignCues. `start` (the planet) fades the ship out
## again. Nothing is scanned on the ship.

const AMBIENCE_BUS: StringName = &"Ambience"
const SCAN_INTERVAL: float = 1.5
const FADE_IN: float = 4.0
## Fade between the ship's beds and the planet's (s).
const SHIP_FADE: float = 2.0
## How fast nearness and storm cover move (per second), so a camera jump
## glides rather than cuts.
const CONTEXT_RATE: float = 0.4
const FLUX: StringName = &"flux"
const ANTECEDENT: StringName = &"antecedent"

## Looks up a SoundEvent: `func(id: StringName) -> SoundEvent`.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## Plays a positional event: `func(id: StringName, at: Vector3, offset_db: float) -> bool`.
var play_at: Callable = func(_id: StringName, _at: Vector3, _db: float) -> bool: return false
## Listener focus on the ground; set by the AudioService.
var focus: Vector3 = Vector3.ZERO
## Only buildings of other factions count as Combine industry.
var player_faction: int = 0
## Re-read the scene every SCAN_INTERVAL (tests turn it off and set the context).
var auto_scan: bool = true

var _players: Dictionary[StringName, AudioStreamPlayer] = {}
var _wander_db: Dictionary[StringName, float] = {}
var _wander_target: Dictionary[StringName, float] = {}
var _next_wander: Dictionary[StringName, float] = {}
var _context: Dictionary = {}
var _context_target: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock: float = 0.0
var _next_scan: float = 0.0
var _next_detail: float = INF
var _last_detail: StringName = &""
var _fade: float = 0.0
var _running: bool = false
var _seen: Dictionary[int, bool] = {}
var _vent_at: Vector3 = Vector3.INF
var _base_at: Vector3 = Vector3.INF
var _ship: bool = false
var _ship_screen: StringName = &""
var _ship_fade: float = 0.0
var _ship_players: Dictionary[StringName, AudioStreamPlayer] = {}
var _ship_wander_db: Dictionary[StringName, float] = {}
var _ship_wander_target: Dictionary[StringName, float] = {}
var _ship_next_wander: Dictionary[StringName, float] = {}
var _next_ship_detail: float = INF
var _last_ship_detail: StringName = &""


func _ready() -> void:
	for bed: StringName in AmbienceCues.BEDS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Bed_%s" % bed
		player.bus = AMBIENCE_BUS
		player.volume_db = AudioMix.SILENT_DB
		add_child(player)
		_players[bed] = player
		_wander_db[bed] = 0.0
		_wander_target[bed] = 0.0
		_next_wander[bed] = 0.0
	for bed: StringName in CampaignCues.BEDS:
		var ship_player: AudioStreamPlayer = AudioStreamPlayer.new()
		ship_player.name = "Ship_%s" % bed
		ship_player.bus = AMBIENCE_BUS
		ship_player.volume_db = AudioMix.SILENT_DB
		add_child(ship_player)
		_ship_players[bed] = ship_player
		_ship_wander_db[bed] = 0.0
		_ship_wander_target[bed] = 0.0
		_ship_next_wander[bed] = 0.0
	for key: StringName in [
		AmbienceCues.VENT_NEAR, AmbienceCues.BASE_NEAR, AmbienceCues.SITE_NEAR, AmbienceCues.STORM
	]:
		_context[key] = 0.0
		_context_target[key] = 0.0
	Events.mission_started.connect(handle_mission_started)


## Starts the beds. `wind` is the score's own ambience stream (may be null).
## The ship's beds, if they play, fade out.
func start(wind: AudioStream) -> void:
	_running = true
	_ship = false
	_ship_screen = &""
	_next_ship_detail = INF
	_fade = 0.0
	_start_bed(AmbienceCues.BED_WIND, wind)
	_start_bed(AmbienceCues.BED_AIR, _stream_of(AmbienceCues.BED_AIR))
	_next_detail = _clock + AmbienceCues.detail_gap(_context, _rng.randf())


## Ship mode: the planet fades out, the Meridian's beds fade in.
func start_ship(screen: StringName) -> void:
	_running = true
	if not _ship:
		_ship = true
		_next_detail = INF
		for bed: StringName in CampaignCues.BEDS:
			var player: AudioStreamPlayer = _ship_players[bed]
			if not player.playing:
				_start_on(player, _stream_of(bed))
	set_ship_screen(screen)


## The ship screen shown (the title sits further from the hull).
func set_ship_screen(screen: StringName) -> void:
	var was: StringName = _ship_screen
	_ship_screen = screen
	if was == &"" or _next_ship_detail == INF:
		_next_ship_detail = _clock + CampaignCues.detail_gap(_rng.randf(), screen)


func is_ship() -> bool:
	return _ship


func ship_bed_volume_db(bed: StringName) -> float:
	var player: AudioStreamPlayer = _ship_players.get(bed, null)
	return player.volume_db if player != null else AudioMix.SILENT_DB


func ship_bed_playing(bed: StringName) -> bool:
	var player: AudioStreamPlayer = _ship_players.get(bed, null)
	return player != null and player.playing


func stop() -> void:
	_running = false
	_ship = false
	_ship_fade = 0.0
	for player: AudioStreamPlayer in _players.values():
		player.stop()
	for player: AudioStreamPlayer in _ship_players.values():
		player.stop()


func _process(delta: float) -> void:
	if _running:
		advance(delta)


## Advances by `delta` seconds (tests call this directly). Returns the detail
## kind started on this step, or &"".
func advance(delta: float) -> StringName:
	_clock += delta
	if _ship:
		_fade = move_toward(_fade, 0.0, delta / SHIP_FADE)
	else:
		_fade = minf(_fade + delta / FADE_IN, 1.0)
	_ship_fade = move_toward(_ship_fade, 1.0 if _ship else 0.0, delta / SHIP_FADE)
	_apply_ship_beds(delta)
	if _ship:
		_apply_beds()
		return _ship_detail()
	if auto_scan and _clock >= _next_scan:
		_next_scan = _clock + SCAN_INTERVAL
		scan()
	for key: Variant in _context_target.keys():
		var now_value: float = _context[key]
		var goal: float = _context_target[key]
		_context[key] = move_toward(now_value, goal, CONTEXT_RATE * delta)
	_wander(delta)
	_apply_beds()
	if _clock < _next_detail:
		return &""
	_next_detail = _clock + AmbienceCues.detail_gap(_context, _rng.randf())
	return play_detail(_rng.randf())


## The storm's cover, 0..1 (from StormSound).
func set_storm_cover(amount: float) -> void:
	_context_target[AmbienceCues.STORM] = clampf(amount, 0.0, 1.0)


## Picks and plays one detail for `roll`; returns its kind or &"".
func play_detail(roll: float) -> StringName:
	var weights: Dictionary[StringName, float] = AmbienceCues.detail_weights(_context)
	if not _base_at.is_finite():
		weights[AmbienceCues.INDUSTRY] = 0.0  # nowhere to put it
	var kind: StringName = AmbienceCues.pick(weights, roll, _last_detail)
	if kind == &"":
		return &""
	var at: Vector3 = _detail_position(kind)
	if not at.is_finite():
		return &""
	_last_detail = kind
	play_at.call(kind, at, 0.0)
	return kind


## Re-reads the context from the scene (cheap: a few groups, nearest only).
func scan() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	var vent: float = INF
	_vent_at = Vector3.INF
	for node: Node in tree.get_nodes_in_group(&"resource_nodes"):
		var spot: Node3D = node as Node3D
		if spot == null or not spot.has_method(&"resource"):
			continue
		if spot.call(&"resource") != FLUX:
			continue
		var d: float = _flat_distance(spot.global_position)
		if d < vent:
			vent = d
			_vent_at = spot.global_position
	var site: float = INF
	for node: Node in tree.get_nodes_in_group(&"discovery_sites"):
		var place: Node3D = node as Node3D
		if place == null or place.get(&"discovery_type") != ANTECEDENT:
			continue
		site = minf(site, _flat_distance(place.global_position))
	var base: float = INF
	_base_at = Vector3.INF
	for node: Node in tree.get_nodes_in_group(&"buildings"):
		var building: Node3D = node as Node3D
		if building == null or AudioEventRouter.faction_of(building) == player_faction:
			continue
		if AudioEventRouter.faction_of(building) < 0:
			continue
		if building.get(&"is_visible_to_player") == true:
			_seen[building.get_instance_id()] = true
		if not _seen.has(building.get_instance_id()):
			continue
		var d: float = _flat_distance(building.global_position)
		if d < base:
			base = d
			_base_at = building.global_position
	set_nearness(
		AmbienceCues.nearness(vent, AmbienceCues.NEAR_VENT),
		AmbienceCues.nearness(base, AmbienceCues.NEAR_BASE),
		AmbienceCues.nearness(site, AmbienceCues.NEAR_SITE),
	)


## Sets the nearness targets directly (tests; `scan` uses it too).
func set_nearness(vent: float, base: float, site: float) -> void:
	_context_target[AmbienceCues.VENT_NEAR] = vent
	_context_target[AmbienceCues.BASE_NEAR] = base
	_context_target[AmbienceCues.SITE_NEAR] = site


## Jumps the context to its targets (tests).
func settle() -> void:
	for key: Variant in _context_target.keys():
		_context[key] = _context_target[key]


func context() -> Dictionary:
	return _context.duplicate()


func bed_volume_db(bed: StringName) -> float:
	var player: AudioStreamPlayer = _players.get(bed, null)
	return player.volume_db if player != null else AudioMix.SILENT_DB


func handle_mission_started() -> void:
	_seen.clear()
	_last_detail = &""
	_next_scan = _clock
	if _running:
		_next_detail = _clock + AmbienceCues.detail_gap(_context, _rng.randf())


func _ship_detail() -> StringName:
	if _clock < _next_ship_detail:
		return &""
	_next_ship_detail = _clock + CampaignCues.detail_gap(_rng.randf(), _ship_screen)
	var kind: StringName = CampaignCues.pick_detail(_rng.randf(), _last_ship_detail)
	_last_ship_detail = kind
	play_at.call(kind, Vector3.INF, 0.0)
	return kind


func _apply_ship_beds(delta: float) -> void:
	var fade_db: float = AudioMix.linear_to_db_safe(_ship_fade)
	var offset: float = CampaignCues.TITLE_BED_DB if _ship_screen == CampaignCues.TITLE else 0.0
	for bed: StringName in CampaignCues.BEDS:
		var player: AudioStreamPlayer = _ship_players[bed]
		if fade_db <= AudioMix.SILENT_DB:
			if player.playing and not _ship:
				player.stop()
			player.volume_db = AudioMix.SILENT_DB
			continue
		if _clock >= _ship_next_wander[bed]:
			_ship_next_wander[bed] = _clock + AmbienceCues.wander_gap(_rng.randf())
			_ship_wander_target[bed] = CampaignCues.wander_target_db(bed, _rng.randf())
		var rate: float = 9.0 / AmbienceCues.WANDER_GLIDE
		_ship_wander_db[bed] = move_toward(
			_ship_wander_db[bed], _ship_wander_target[bed], rate * delta
		)
		player.volume_db = _ship_wander_db[bed] + offset + fade_db


func _wander(delta: float) -> void:
	for bed: StringName in AmbienceCues.BED_RANGE_DB:
		if _clock >= _next_wander[bed]:
			_next_wander[bed] = _clock + AmbienceCues.wander_gap(_rng.randf())
			_wander_target[bed] = AmbienceCues.wander_target_db(bed, _rng.randf())
		var rate: float = 9.0 / AmbienceCues.WANDER_GLIDE
		_wander_db[bed] = move_toward(_wander_db[bed], _wander_target[bed], rate * delta)


func _apply_beds() -> void:
	var fade_db: float = AudioMix.linear_to_db_safe(_fade)
	for bed: StringName in AmbienceCues.BEDS:
		var player: AudioStreamPlayer = _players[bed]
		var level: float = AmbienceCues.bed_db(bed, _wander_db[bed], _context)
		if level <= AudioMix.SILENT_DB or fade_db <= AudioMix.SILENT_DB:
			if (bed == AmbienceCues.BED_HUSH or _ship) and player.playing:
				player.stop()
			player.volume_db = AudioMix.SILENT_DB
			continue
		if bed == AmbienceCues.BED_HUSH and not player.playing:
			_start_bed(bed, _stream_of(bed))
		player.volume_db = level + fade_db


func _start_bed(bed: StringName, stream: AudioStream) -> void:
	_start_on(_players[bed], stream)


func _start_on(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	player.stream = stream
	player.play(_rng.randf() * maxf(stream.get_length() - 1.0, 0.0))


func _stream_of(event_id: StringName) -> AudioStream:
	var event: SoundEvent = resolve_event.call(event_id)
	if event == null or event.streams.is_empty():
		return null
	return event.streams[0]


func _detail_position(kind: StringName) -> Vector3:
	if kind == AmbienceCues.VENT and _vent_at.is_finite():
		return _vent_at
	if kind == AmbienceCues.INDUSTRY:
		return _base_at
	var angle: float = _rng.randf() * TAU
	var distance: float = _rng.randf_range(AmbienceCues.DETAIL_RING.x, AmbienceCues.DETAIL_RING.y)
	return focus + Vector3(cos(angle), 0.0, sin(angle)) * distance


func _flat_distance(at: Vector3) -> float:
	return Vector2(at.x - focus.x, at.z - focus.z).length()
