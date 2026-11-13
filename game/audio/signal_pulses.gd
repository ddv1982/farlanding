class_name SignalPulses
extends Node
## The voice of unresolved discovery sites, and of scanning them.
##
## Pulses: every SCAN_INTERVAL the sites in group &"discovery_sites" are read
## (DiscoveryCues.wants_pulse: known to the player, unresolved, not being
## scanned). The nearest within the pulse event's `max_distance` get a faint
## positional `signal_pulse` loop, at most MAX_PULSES and at most the event's
## `max_instances`. Pulses fade in and out and drop a little as the camera
## zooms out: a clue for a camera that is near, not a beacon across the map.
##
## Scans: `Events.scan_started` starts one `scan_loop` at the site (several
## scanners on one site share it); `scan_interrupted` stops it once the last
## scanner gives up and plays `scan_interrupted` there; `discovery_made`
## stops it silently (the resolve phrase takes over). A scan is heard when the
## scanner is the player's or the site is visible to the player. A scan loop
## whose site vanished, resolved or says it is no longer scanned is stopped.
## Gameplay never calls this.

const MAX_PULSES: int = 3
const MAX_SCANS: int = 2
const SCAN_INTERVAL: float = 0.25
const PULSE_FADE_SECONDS: float = 1.2
const SCAN_FADE_SECONDS: float = 0.15
## Pulse level offset, closest .. furthest zoom (dB).
const PULSE_ZOOM_DB: Vector2 = Vector2(0.0, -6.0)

## Ground point the listener is centred on.
var focus: Vector3 = Vector3.ZERO
## Camera zoom 0 (closest) .. 1 (furthest).
var zoom: float = 0.5
var player_faction: int = 0
## Looks up a SoundEvent by id; set by the AudioService.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## Plays a positional one-shot: `func(event_id: StringName, at: Vector3) -> bool`.
var play_at: Callable = func(_id: StringName, _at: Vector3) -> bool: return false

var _pulse: LoopSlots
var _scan: LoopSlots
var _chosen: Array[Node3D] = []
## Site instance id -> scanner instance ids working on it.
var _scanners: Dictionary[int, Dictionary] = {}
## Site instance ids with a scan loop (looked up again, so a freed site is null).
var _scan_sites: Dictionary[int, bool] = {}
var _scan_left: float = 0.0


func _ready() -> void:
	_pulse = LoopSlots.new(self, "Pulse", MAX_PULSES, 6.0)
	_scan = LoopSlots.new(self, "Scan", MAX_SCANS, 10.0)
	Events.scan_started.connect(handle_scan_started)
	Events.scan_interrupted.connect(handle_scan_interrupted)
	Events.discovery_made.connect(_on_discovery_made)


func _process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		rescan()
	var pulse_db: float = _event_db(DiscoveryCues.PULSE) + _zoom_db()
	_pulse.update(delta / PULSE_FADE_SECONDS, pulse_db)
	_scan.update(delta / SCAN_FADE_SECONDS, _event_db(DiscoveryCues.SCAN_LOOP))


## Sites that carry a pulse after the last scan, nearest first.
func chosen_sites() -> Array[Node3D]:
	return _chosen.duplicate()


## Sites with a scan loop running.
func scanning_sites() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for key: int in _scan_sites:
		var site: Node3D = instance_from_id(key) as Node3D
		if site != null:
			out.append(site)
	return out


func is_scanning(site: Node3D) -> bool:
	return is_instance_valid(site) and _scan_sites.has(site.get_instance_id())


## Pulse and scan players currently sounding (fading ones included).
func playing_count() -> int:
	return _pulse.playing_count() + _scan.playing_count()


func rescan() -> void:
	_check_scans()
	_chosen.clear()
	var event: SoundEvent = resolve_event.call(DiscoveryCues.PULSE)
	if event == null or event.streams.is_empty():
		_pulse.want([])
		return
	var nodes: Array[Node3D] = []
	var positions: PackedVector3Array = []
	var ids: Array[StringName] = []
	for node: Node in get_tree().get_nodes_in_group(DiscoveryCues.SITES_GROUP):
		var site: Node3D = node as Node3D
		if site == null or not site.is_inside_tree() or is_scanning(site):
			continue
		if not DiscoveryCues.wants_pulse(site):
			continue
		nodes.append(site)
		positions.append(site.global_position)
		ids.append(DiscoveryCues.PULSE)
	var caps: Dictionary[StringName, int] = {DiscoveryCues.PULSE: event.max_instances}
	var picked: PackedInt32Array = MovementLoopPicker.pick(
		positions, ids, caps, focus, MAX_PULSES, event.max_distance
	)
	for i: int in picked:
		_chosen.append(nodes[i])
	_pulse.want(_chosen, event)


func handle_scan_started(scanner: Node3D, site: Node3D) -> void:
	if not is_instance_valid(site) or not _hears_scan(scanner, site):
		return
	var key: int = site.get_instance_id()
	if not _scanners.has(key):
		_scanners[key] = {}
	var working: Dictionary = _scanners[key]
	working[_id_of(scanner)] = true
	_scan_sites[key] = true
	_pulse.release(site)
	_chosen.erase(site)
	_scan.want(scanning_sites(), _scan_event())


func handle_scan_interrupted(scanner: Node3D, site: Node3D) -> void:
	if not is_instance_valid(site):
		return
	var key: int = site.get_instance_id()
	if not _scanners.has(key):
		return
	var working: Dictionary = _scanners[key]
	working.erase(_id_of(scanner))
	if not working.is_empty():
		return
	var at: Vector3 = site.global_position if site.is_inside_tree() else Vector3.INF
	_stop_scan(key)
	if at.is_finite():
		play_at.call(DiscoveryCues.SCAN_CUT, at)


func handle_discovery_made(site: Node3D) -> void:
	if not is_instance_valid(site):
		return
	_stop_scan(site.get_instance_id())
	_pulse.release(site)
	_chosen.erase(site)


func _on_discovery_made(site: Node3D, _discovery: Resource, _faction: int) -> void:
	handle_discovery_made(site)


func _check_scans() -> void:
	for key: int in _scan_sites.keys():
		var site: Node3D = instance_from_id(key) as Node3D
		var gone: bool = site == null or not site.is_inside_tree()
		if (
			gone
			or DiscoveryCues.flag(site, &"is_resolved", false)
			or not DiscoveryCues.flag(site, &"is_being_scanned", true)
		):
			_stop_scan(key)


func _stop_scan(key: int) -> void:
	_scanners.erase(key)
	if _scan_sites.has(key):
		_scan_sites.erase(key)
		_scan.want(scanning_sites(), _scan_event())


func _scan_event() -> SoundEvent:
	var event: SoundEvent = resolve_event.call(DiscoveryCues.SCAN_LOOP)
	return event


func _hears_scan(scanner: Node3D, site: Node3D) -> bool:
	if is_instance_valid(scanner) and AudioEventRouter.faction_of(scanner) == player_faction:
		return true
	return DiscoveryCues.flag(site, &"is_visible_to_player", false)


func _event_db(event_id: StringName) -> float:
	var event: SoundEvent = resolve_event.call(event_id)
	return event.volume_db if event != null else 0.0


func _zoom_db() -> float:
	return lerpf(PULSE_ZOOM_DB.x, PULSE_ZOOM_DB.y, clampf(zoom, 0.0, 1.0))


static func _id_of(node: Node) -> int:
	return node.get_instance_id() if is_instance_valid(node) else 0


## A small pool of positional loop players that follow their owners and fade.
class LoopSlots:
	extends RefCounted

	var players: Array[AudioStreamPlayer3D] = []
	var owners: Array[Node3D] = []
	var levels: PackedFloat32Array = []
	var wanted: Array[bool] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	func _init(parent: Node, prefix: String, count: int, unit_size: float) -> void:
		for i: int in count:
			var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			player.name = "%s%d" % [prefix, i]
			player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			player.unit_size = unit_size
			parent.add_child(player)
			players.append(player)
			owners.append(null)
			wanted.append(false)
		levels.resize(count)

	## Keeps loops on `targets` (starting new ones in free slots), fades the rest.
	func want(targets: Array[Node3D], event: SoundEvent = null) -> void:
		for i: int in players.size():
			wanted[i] = is_instance_valid(owners[i]) and owners[i] in targets
		if event == null or event.streams.is_empty():
			return
		for target: Node3D in targets:
			if is_instance_valid(target) and not owners.has(target):
				_assign(target, event)

	## Fades out the loop on `owner`, if any.
	func release(owner: Node3D) -> void:
		for i: int in players.size():
			if owners[i] == owner:
				wanted[i] = false

	func playing_count() -> int:
		var count: int = 0
		for player: AudioStreamPlayer3D in players:
			if player.playing:
				count += 1
		return count

	func update(step: float, volume_db: float) -> void:
		for i: int in players.size():
			var player: AudioStreamPlayer3D = players[i]
			var alive: bool = is_instance_valid(owners[i]) and owners[i].is_inside_tree()
			if not alive:
				wanted[i] = false
			levels[i] = move_toward(levels[i], 1.0 if wanted[i] else 0.0, step)
			if levels[i] <= 0.0:
				if player.playing:
					player.stop()
				owners[i] = null
				continue
			if alive:
				player.global_position = owners[i].global_position
			player.volume_db = volume_db + AudioMix.linear_to_db_safe(levels[i])

	func _assign(target: Node3D, event: SoundEvent) -> void:
		var slot: int = -1
		for i: int in players.size():
			if not wanted[i] and levels[i] <= 0.0:
				slot = i
				break
		if slot == -1:
			return
		var player: AudioStreamPlayer3D = players[slot]
		var stream: AudioStream = event.streams[rng.randi_range(0, event.streams.size() - 1)]
		player.stream = stream
		player.bus = event.bus
		player.max_distance = event.max_distance
		player.volume_db = AudioMix.SILENT_DB
		player.global_position = target.global_position
		# Random start point so neighbouring pulses never fall into step.
		player.play(rng.randf() * maxf(stream.get_length() - 0.05, 0.0))
		owners[slot] = target
		wanted[slot] = true
		levels[slot] = 0.0
