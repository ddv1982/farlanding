class_name MovementLoops
extends Node
## Keeps a few movement loops audible on the moving units nearest the listener.
##
## Gameplay never calls this. Every SCAN_INTERVAL it reads the scene tree:
## nodes in group &"units" that are Node3D and expose `def` (an EntityDef with a
## `sound_set`). Speed is the unit's `speed` property (m/s) if it has one,
## otherwise it is measured from how far the unit moved since the last scan.
## A unit moving faster than MIN_SPEED with a SoundEvent named
## `move_<sound_set>` is a candidate. Loops follow their unit, fade in and out,
## and rise in level and pitch with speed (relative to `UnitDef.move_speed`).
## A unit whose `is_visible_to_player` is false (fog of war) is not heard; one
## whose `is_cloaked` is true (a Wisp) is heard CLOAKED_DB quieter.

const UNITS_GROUP: StringName = &"units"
const MAX_LOOPS: int = 6
const SCAN_INTERVAL: float = 0.2
const MIN_SPEED: float = 0.3
const FADE_SECONDS: float = 0.3
const DEFAULT_MOVE_SPEED: float = 5.0
## Weight of the newest measurement when speed is measured from positions.
const SPEED_SMOOTHING: float = 0.5
const CLOAKED_DB: float = -9.0

## Ground point the listener is centred on.
var focus: Vector3 = Vector3.ZERO
## Looks up a SoundEvent by id; set by the AudioService.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null

var _players: Array[AudioStreamPlayer3D] = []
var _owners: Array[Node3D] = []
var _levels: PackedFloat32Array = []  # linear fade level per player
var _wanted: Array[bool] = []
var _scan_left: float = 0.0
var _speeds: Dictionary[int, float] = {}  # instance id -> m/s, refreshed per scan
var _last_positions: Dictionary[int, Vector3] = {}
var _last_scan_msec: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	for i: int in MAX_LOOPS:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "Loop%d" % i
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 8.0
		add_child(player)
		_players.append(player)
		_owners.append(null)
		_wanted.append(false)
	_levels.resize(MAX_LOOPS)


func _process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		_rescan()
	for i: int in _players.size():
		_update_player(i, delta)


func active_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer3D in _players:
		if player.playing:
			count += 1
	return count


func _rescan() -> void:
	var nodes: Array[Node3D] = []
	var positions: PackedVector3Array = []
	var events: Array[StringName] = []
	var caps: Dictionary[StringName, int] = {}
	var max_distance: float = 0.0
	_measure_speeds()
	for node: Node in get_tree().get_nodes_in_group(UNITS_GROUP):
		var unit: Node3D = node as Node3D
		if unit == null or not unit.is_inside_tree() or current_speed(unit) < MIN_SPEED:
			continue
		if CombatCues.is_hidden(unit):
			continue
		var event_id: StringName = StringName("move_%s" % sound_set_of(unit))
		var event: SoundEvent = resolve_event.call(event_id)
		if event == null or event.streams.is_empty():
			continue
		nodes.append(unit)
		positions.append(unit.global_position)
		events.append(event_id)
		caps[event_id] = event.max_instances
		max_distance = maxf(max_distance, event.max_distance)
	var chosen: PackedInt32Array = MovementLoopPicker.pick(
		positions, events, caps, focus, MAX_LOOPS, max_distance
	)
	var keep: Array[Node3D] = []
	for i: int in chosen:
		keep.append(nodes[i])
	for i: int in _players.size():
		_wanted[i] = _owners[i] != null and is_instance_valid(_owners[i]) and _owners[i] in keep
	for i: int in chosen:
		var unit: Node3D = nodes[i]
		if not _owners.has(unit):
			var event: SoundEvent = resolve_event.call(events[i])
			_assign(unit, event)


func _assign(unit: Node3D, event: SoundEvent) -> void:
	var slot: int = -1
	for i: int in _players.size():
		if not _wanted[i] and _levels[i] <= 0.0:
			slot = i
			break
	if slot == -1:
		return
	var player: AudioStreamPlayer3D = _players[slot]
	var stream: AudioStream = event.streams[_rng.randi_range(0, event.streams.size() - 1)]
	player.stream = stream
	player.bus = event.bus
	player.max_distance = event.max_distance
	player.volume_db = AudioMix.SILENT_DB
	player.global_position = unit.global_position
	# Random start point so identical loops never phase-lock.
	player.play(_rng.randf() * maxf(stream.get_length() - 0.05, 0.0))
	_owners[slot] = unit
	_wanted[slot] = true
	_levels[slot] = 0.0


func _update_player(i: int, delta: float) -> void:
	var player: AudioStreamPlayer3D = _players[i]
	var unit: Node3D = _owners[i]
	var alive: bool = unit != null and is_instance_valid(unit) and unit.is_inside_tree()
	if not alive:
		_owners[i] = null
		_wanted[i] = false
	var target: float = 1.0 if _wanted[i] else 0.0
	_levels[i] = move_toward(_levels[i], target, delta / FADE_SECONDS)
	if _levels[i] <= 0.0:
		if player.playing:
			player.stop()
		_owners[i] = null
		return
	var ratio: float = 0.0
	var base_db: float = 0.0
	if alive:
		player.global_position = unit.global_position
		ratio = clampf(current_speed(unit) / _top_speed(unit), 0.0, 1.0)
		var event: SoundEvent = resolve_event.call(StringName("move_%s" % sound_set_of(unit)))
		if event != null:
			base_db = event.volume_db
		if StealthCues.flag(unit, &"is_cloaked", false):
			base_db += CLOAKED_DB
	player.volume_db = base_db + AudioMix.linear_to_db_safe(_levels[i] * lerpf(0.4, 1.0, ratio))
	player.pitch_scale = lerpf(0.9, 1.08, ratio)


## Ground speed of a unit in m/s: its `speed` property if it has one,
## otherwise the speed measured over the last scan.
func current_speed(unit: Node3D) -> float:
	var declared: float = speed_property(unit)
	if declared >= 0.0:
		return declared
	return _speeds.get(unit.get_instance_id(), 0.0)


## The unit's `speed` property, or -1 if it has none.
static func speed_property(unit: Node) -> float:
	var value: Variant = unit.get(&"speed")
	if value is float or value is int:
		var speed: float = value
		return absf(speed)
	return -1.0


func _measure_speeds() -> void:
	var now: int = Time.get_ticks_msec()
	var dt: float = (now - _last_scan_msec) / 1000.0
	_last_scan_msec = now
	var positions: Dictionary[int, Vector3] = {}
	var speeds: Dictionary[int, float] = {}
	for node: Node in get_tree().get_nodes_in_group(UNITS_GROUP):
		var unit: Node3D = node as Node3D
		if unit == null or not unit.is_inside_tree():
			continue
		var id: int = unit.get_instance_id()
		var here: Vector3 = unit.global_position
		positions[id] = here
		if dt > 0.0 and _last_positions.has(id):
			var before: Vector3 = _last_positions[id]
			var measured: float = Vector2(here.x - before.x, here.z - before.z).length() / dt
			# The sim moves units in 10 Hz steps; smoothing hides the aliasing.
			var previous: float = _speeds.get(id, measured)
			speeds[id] = lerpf(previous, measured, SPEED_SMOOTHING)
	_last_positions = positions
	_speeds = speeds


## The unit's `def.sound_set`, or &"" if it has none.
static func sound_set_of(unit: Node) -> StringName:
	if unit == null or not is_instance_valid(unit):
		return &""
	var value: Variant = unit.get(&"def")
	if value is EntityDef:
		var def: EntityDef = value
		return def.sound_set
	return &""


static func _top_speed(unit: Node) -> float:
	var value: Variant = unit.get(&"def")
	if value is UnitDef:
		var def: UnitDef = value
		if def.move_speed > 0.0:
			return def.move_speed
	return DEFAULT_MOVE_SPEED
