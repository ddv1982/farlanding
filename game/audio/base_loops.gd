class_name BaseLoops
extends Node
## Positional loops for the player's base, nearest to the listener first:
##
## - `loop_construct` on a building under construction,
## - `loop_produce` on a building producing a unit,
## - `loop_mine` on a hauler harvesting at a deposit,
## - `loop_hum` (quiet) on any other operational building.
##
## Gameplay never calls this. Every SCAN_INTERVAL it reads groups &"buildings"
## and &"units" (player faction only, so nothing leaks through fog) and these
## OPTIONAL properties, each read with `get()` and ignored unless it is a bool:
##
##   building.is_under_construction  site -> construct loop
##   building.is_producing           -> produce loop
##   building.is_powered             false -> no hum (true or absent: hum)
##   unit.is_harvesting              -> mine loop at the unit
##
## Without the first two, state comes from Events instead: building_placed
## until construction_completed marks a site; production_started /
## production_completed count a producer's work. Without `is_harvesting` there
## is simply no mining loop. `power_changed` for the player dims and lowers the
## hum and production loops while power is short.
##
## Hums have identities: a building or unit whose sound set has an event
## `loop_hum_<set>` hums with it (Survey Lab, Combine hub/forge/spire, the
## Warden), others with the generic `loop_hum`. Buildings of other factions
## hum only while `is_visible_to_player` is true (absent: silent). A unit with
## a `loop_hum_<set>` hums while idle: `is_dormant` true, or, without that
## property, a `speed` below MovementLoops.MIN_SPEED (absent: idle). When a
## unit's `is_dormant` turns from true to false where the player can see it,
## `unit_<set>_wake` plays there once.

const BUILDINGS_GROUP: StringName = &"buildings"
const UNITS_GROUP: StringName = &"units"
const CONSTRUCT: StringName = &"loop_construct"
const PRODUCE: StringName = &"loop_produce"
const MINE: StringName = &"loop_mine"
const HUM: StringName = &"loop_hum"
const MAX_LOOPS: int = 6
const SCAN_INTERVAL: float = 0.25
const FADE_SECONDS: float = 0.5
## Added to the distance when ranking (metres): busy sounds win over hums.
const RANK_PENALTY: Dictionary[StringName, float] = {
	CONSTRUCT: 0.0, MINE: 0.0, PRODUCE: 4.0, HUM: 20.0
}
const HUM_PREFIX: String = "loop_hum"
const LOW_POWER_DB: float = -6.0
const LOW_POWER_PITCH: float = 0.94
## Event-derived production state is forgotten after this long without news
## (a cancelled queue sends no event).
const PRODUCTION_STALE_SECONDS: float = 90.0

## Ground point the listener is centred on.
var focus: Vector3 = Vector3.ZERO
## Looks up a SoundEvent by id; set by the AudioService.
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## Plays a positional one-shot (the wake): `func(id: StringName, at: Vector3) -> bool`.
var play_at: Callable = func(_id: StringName, _at: Vector3) -> bool: return false
var player_faction: int = 0

var _players: Array[AudioStreamPlayer3D] = []
var _owners: Array[Node3D] = []
var _loop_ids: Array[StringName] = []
var _levels: PackedFloat32Array = []
var _wanted: Array[bool] = []
var _chosen_owners: Array[Node3D] = []
var _chosen_ids: Array[StringName] = []
var _scan_left: float = 0.0
var _sites: Dictionary[int, bool] = {}
var _work: Dictionary[int, int] = {}  # producer instance id -> units in progress
var _work_time: Dictionary[int, float] = {}
var _low_power: bool = false
var _dormant: Dictionary[int, bool] = {}  # unit instance id -> was dormant at last scan
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	for i: int in MAX_LOOPS:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "BaseLoop%d" % i
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 8.0
		add_child(player)
		_players.append(player)
		_owners.append(null)
		_loop_ids.append(&"")
		_wanted.append(false)
	_levels.resize(MAX_LOOPS)
	Events.building_placed.connect(_on_building_placed)
	Events.construction_completed.connect(_on_construction_completed)
	Events.production_started.connect(_on_production_started)
	Events.production_completed.connect(_on_production_completed)
	Events.power_changed.connect(_on_power_changed)
	Events.entity_died.connect(_on_entity_died)


func _process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		rescan()
	for i: int in _players.size():
		_update_player(i, delta)


## Which loop an entity should carry, or &"" for none. `site` and `producing`
## are the event-derived fallbacks used when the entity lacks the property.
static func loop_for(node: Node, is_building: bool, site: bool, producing: bool) -> StringName:
	if not is_building:
		return MINE if flag(node, &"is_harvesting", false) else &""
	if flag(node, &"is_under_construction", site):
		return CONSTRUCT
	if flag(node, &"is_producing", producing):
		return PRODUCE
	return HUM if flag(node, &"is_powered", true) else &""


## The hum an entity carries: `loop_hum_<set>` if that event exists, else the
## generic hum for buildings and none for units. `has_event` answers whether
## an event id exists.
static func hum_for(node: Node, is_building: bool, has_event: Callable) -> StringName:
	var sound_set: StringName = MovementLoops.sound_set_of(node)
	if sound_set != &"":
		var own: StringName = StringName("%s_%s" % [HUM_PREFIX, sound_set])
		if has_event.call(own):
			return own
	return HUM if is_building else &""


## True for any hum, generic or with an identity.
static func is_hum(loop_id: StringName) -> bool:
	return String(loop_id).begins_with(HUM_PREFIX)


## A unit at rest: `is_dormant` if it has one, else a low or absent `speed`.
static func is_idle(unit: Node) -> bool:
	var dormant: Variant = unit.get(&"is_dormant")
	if dormant is bool:
		var result: bool = dormant
		return result
	return MovementLoops.speed_property(unit) < MovementLoops.MIN_SPEED


## A bool property of `node`, or `fallback` if it has none (or not a bool).
static func flag(node: Node, property: StringName, fallback: bool) -> bool:
	var value: Variant = node.get(property)
	if value is bool:
		var result: bool = value
		return result
	return fallback


func is_low_power() -> bool:
	return _low_power


## The entities and loop ids chosen by the last scan, nearest first.
func chosen() -> Array[Array]:
	var out: Array[Array] = []
	for i: int in _chosen_owners.size():
		out.append([_chosen_owners[i], _chosen_ids[i]])
	return out


func rescan() -> void:
	var nodes: Array[Node3D] = []
	var positions: PackedVector3Array = []
	var ids: Array[StringName] = []
	var penalties: PackedFloat32Array = []
	var caps: Dictionary[StringName, int] = {}
	var now: float = _now()
	_forget_stale_work(now)
	for group: StringName in [BUILDINGS_GROUP, UNITS_GROUP]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var entity: Node3D = node as Node3D
			if entity == null or not entity.is_inside_tree():
				continue
			var is_building: bool = group == BUILDINGS_GROUP
			var own: bool = AudioEventRouter.faction_of(entity) == player_faction
			if not is_building:
				_watch_wake(entity, own)
			if not own and not flag(entity, &"is_visible_to_player", false):
				continue
			var key: int = entity.get_instance_id()
			var loop_id: StringName = &""
			if own:
				var in_progress: int = _work.get(key, 0)
				loop_id = loop_for(entity, is_building, _sites.has(key), in_progress > 0)
			elif is_building:
				loop_id = HUM
			if loop_id == &"" and not is_building and is_idle(entity):
				loop_id = HUM
			if loop_id == HUM:
				loop_id = hum_for(entity, is_building, _has_event)
			if loop_id == &"":
				continue
			var event: SoundEvent = resolve_event.call(loop_id)
			if event == null or event.streams.is_empty():
				continue
			var distance: float = (
				Vector2(entity.global_position.x - focus.x, entity.global_position.z - focus.z)
				. length()
			)
			if event.max_distance > 0.0 and distance > event.max_distance:
				continue
			nodes.append(entity)
			positions.append(entity.global_position)
			ids.append(loop_id)
			var penalty: float = (
				RANK_PENALTY[HUM] if is_hum(loop_id) else RANK_PENALTY.get(loop_id, 0.0)
			)
			penalties.append(penalty)
			caps[loop_id] = event.max_instances
	var picked: PackedInt32Array = MovementLoopPicker.pick(
		positions, ids, caps, focus, MAX_LOOPS, 0.0, penalties
	)
	_chosen_owners.clear()
	_chosen_ids.clear()
	for i: int in picked:
		_chosen_owners.append(nodes[i])
		_chosen_ids.append(ids[i])
	_apply_choice()


func _apply_choice() -> void:
	for i: int in _players.size():
		_wanted[i] = false
		if not is_instance_valid(_owners[i]):
			continue
		for k: int in _chosen_owners.size():
			if _chosen_owners[k] == _owners[i] and _chosen_ids[k] == _loop_ids[i]:
				_wanted[i] = true
				break
	for k: int in _chosen_owners.size():
		if _slot_of(_chosen_owners[k], _chosen_ids[k]) == -1:
			_assign(_chosen_owners[k], _chosen_ids[k])


func _slot_of(owner: Node3D, loop_id: StringName) -> int:
	for i: int in _players.size():
		if is_instance_valid(_owners[i]) and _owners[i] == owner and _loop_ids[i] == loop_id:
			return i
	return -1


func _assign(owner: Node3D, loop_id: StringName) -> void:
	var event: SoundEvent = resolve_event.call(loop_id)
	if event == null or event.streams.is_empty():
		return
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
	player.global_position = owner.global_position
	# Random start point so identical loops never phase-lock.
	player.play(_rng.randf() * maxf(stream.get_length() - 0.05, 0.0))
	_owners[slot] = owner
	_loop_ids[slot] = loop_id
	_wanted[slot] = true
	_levels[slot] = 0.0


func _update_player(i: int, delta: float) -> void:
	var player: AudioStreamPlayer3D = _players[i]
	var alive: bool = is_instance_valid(_owners[i]) and _owners[i].is_inside_tree()
	if not alive:
		_owners[i] = null
		_wanted[i] = false
	var owner: Node3D = _owners[i]
	_levels[i] = move_toward(_levels[i], 1.0 if _wanted[i] else 0.0, delta / FADE_SECONDS)
	if _levels[i] <= 0.0:
		if player.playing:
			player.stop()
		_owners[i] = null
		_loop_ids[i] = &""
		return
	var base_db: float = 0.0
	var event: SoundEvent = resolve_event.call(_loop_ids[i])
	if event != null:
		base_db = event.volume_db
	var dims: bool = (
		_low_power
		and (is_hum(_loop_ids[i]) or _loop_ids[i] == PRODUCE)
		and alive
		and AudioEventRouter.faction_of(owner) == player_faction
	)
	if alive:
		player.global_position = owner.global_position
	player.volume_db = (
		base_db + (LOW_POWER_DB if dims else 0.0) + AudioMix.linear_to_db_safe(_levels[i])
	)
	player.pitch_scale = LOW_POWER_PITCH if dims else 1.0


func _has_event(event_id: StringName) -> bool:
	var event: SoundEvent = resolve_event.call(event_id)
	return event != null and not event.streams.is_empty()


## Plays `unit_<set>_wake` when a dormant unit wakes where the player can see it.
func _watch_wake(unit: Node3D, own: bool) -> void:
	var value: Variant = unit.get(&"is_dormant")
	if not value is bool:
		return
	var dormant: bool = value
	var key: int = unit.get_instance_id()
	var was: bool = _dormant.get(key, false)
	_dormant[key] = dormant
	if was and not dormant and (own or not CombatCues.is_hidden(unit)):
		var sound_set: StringName = MovementLoops.sound_set_of(unit)
		if sound_set != &"":
			play_at.call(AudioCueSelector.unit_event(sound_set, &"wake"), unit.global_position)


func _forget_stale_work(now: float) -> void:
	for key: int in _work_time.keys():
		if now - _work_time[key] > PRODUCTION_STALE_SECONDS:
			_work.erase(key)
			_work_time.erase(key)


func _on_building_placed(building: Node3D) -> void:
	if is_instance_valid(building):
		_sites[building.get_instance_id()] = true


func _on_construction_completed(building: Node3D) -> void:
	if is_instance_valid(building):
		_sites.erase(building.get_instance_id())


func _on_production_started(producer: Node3D, _def: EntityDef) -> void:
	if is_instance_valid(producer):
		var key: int = producer.get_instance_id()
		var count: int = _work.get(key, 0)
		_work[key] = count + 1
		_work_time[key] = _now()


func _on_production_completed(producer: Node3D, _unit: Node3D) -> void:
	if is_instance_valid(producer):
		var key: int = producer.get_instance_id()
		var count: int = _work.get(key, 0)
		_work[key] = maxi(count - 1, 0)
		_work_time[key] = _now()


func _on_power_changed(faction: int, produced: int, used: int) -> void:
	if faction == player_faction:
		_low_power = used > produced


func _on_entity_died(entity: Node3D) -> void:
	if is_instance_valid(entity):
		var key: int = entity.get_instance_id()
		_sites.erase(key)
		_dormant.erase(key)
		_work.erase(key)
		_work_time.erase(key)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
