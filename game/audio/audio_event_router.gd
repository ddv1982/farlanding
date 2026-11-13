class_name AudioEventRouter
extends Node
## Listens to `Events` and decides what is heard. The decisions themselves live
## in AudioCueSelector (pure, tested); this node only gathers the inputs.
##
## Entity contract: an entity is a Node3D whose `def` property is an EntityDef;
## `def.sound_set` (e.g. &"ranger") names its replies `unit_<set>_<kind>`.
## Buildings are entities in group &"buildings"; their set names the machine
## identity `building_<set>_select`. Economy one-shots play only for the
## player's faction (resource_depleted for anyone: deposits are neutral).
## Advisor alerts go through an AdvisorQueue (throttled, never stacked, and
## place alerts such as under_attack skipped while the camera shows the place).
## Combat events (fire, impacts, deaths) are the CombatSoundRouter's; the
## objective Advisor kinds (objective_new/_done/_failed) the MissionSoundRouter's.

const BUILDINGS_GROUP: StringName = &"buildings"
## A production_started this soon after the same producer finished a unit is
## its queue moving on, not the player clicking: no queue click.
const QUEUE_ADVANCE_WINDOW: float = 0.5

## Only orders from this faction are acknowledged.
@export var player_faction: int = 0

## Plays the first existing event of a candidate list:
## `func(candidates: Array[StringName], position: Vector3) -> StringName`.
var play_first: Callable = func(_ids: Array[StringName], _at: Vector3) -> StringName: return &""
## Length in seconds of an event (its longest variation):
## `func(event_id: StringName) -> float`. Used to keep Advisor phrases apart.
var event_seconds: Callable = func(_id: StringName) -> float: return 1.5
## Where an Advisor alert raised by gameplay happened, if known:
## `func(kind: StringName) -> Vector3` (Vector3.INF when unknown).
var alert_position: Callable = func(_kind: StringName) -> Vector3: return Vector3.INF
## Called with each Advisor kind as its phrase starts: `func(kind: StringName) -> void`
## (the AudioService raises the score's urgency layer on under_attack).
var on_alert_played: Callable = func(_kind: StringName) -> void: pass
## Listener focus on the ground; set by the AudioService.
var focus: Vector3 = Vector3.INF

var _selector: AudioCueSelector = AudioCueSelector.new()
var _advisor: AdvisorQueue = AdvisorQueue.new()
var _last_completion: Dictionary[int, float] = {}  # producer instance id -> time


func _ready() -> void:
	Events.selection_changed.connect(_on_selection_changed)
	Events.command_issued.connect(_on_command_issued)
	Events.ui_feedback.connect(_on_ui_feedback)
	Events.entity_spawned.connect(_on_entity_spawned)
	Events.building_placed.connect(_on_building_placed)
	Events.construction_completed.connect(_on_construction_completed)
	Events.production_started.connect(_on_production_started)
	Events.production_completed.connect(_on_production_completed)
	Events.harvest_delivered.connect(_on_harvest_delivered)
	Events.resource_depleted.connect(_on_resource_depleted)
	Events.advisor_alert.connect(_on_advisor_alert)


func _process(_delta: float) -> void:
	pump_advisor(_now())


## Plays the next waiting Advisor phrase if none is sounding. Returns the
## alert kind played, or &"".
func pump_advisor(now: float) -> StringName:
	var kind: StringName = _advisor.pop_ready(now)
	if kind == &"":
		return &""
	var played: StringName = play_first.call(AudioCueSelector.advisor_events(kind), Vector3.INF)
	var seconds: float = 0.0
	if played != &"":
		seconds = event_seconds.call(played)
	_advisor.started(now, seconds)
	on_alert_played.call(kind)
	return kind


## Offers an Advisor alert at time `now` (tests drive time directly), about a
## world `position` if it has one.
func offer_advisor_alert(kind: StringName, now: float, position: Vector3 = Vector3.INF) -> bool:
	_advisor.focus = focus
	if _advisor.push(kind, now, position):
		pump_advisor(now)
		return true
	return false


static func sound_sets_of(entities: Array[Node3D]) -> Array[StringName]:
	var sets: Array[StringName] = []
	for entity: Node3D in entities:
		if is_instance_valid(entity):
			sets.append(MovementLoops.sound_set_of(entity))
	return sets


## The entity's `faction` property if it has one, else `def.faction`, else -1.
static func faction_of(entity: Node) -> int:
	var own: Variant = entity.get(&"faction")
	if own is int:
		var faction: int = own
		return faction
	var value: Variant = entity.get(&"def")
	if value is EntityDef:
		var def: EntityDef = value
		return def.faction
	return -1


static func is_building(entity: Node) -> bool:
	return entity.is_in_group(BUILDINGS_GROUP)


func _on_selection_changed(entities: Array[Node3D]) -> void:
	var units: Array[Node3D] = []
	var buildings: Array[Node3D] = []
	for entity: Node3D in entities:
		if not is_instance_valid(entity):
			continue
		if is_building(entity):
			buildings.append(entity)
		else:
			units.append(entity)
	if units.is_empty() and not buildings.is_empty():
		_play(_selector.on_building_selection(sound_sets_of(buildings), _now()), Vector3.INF)
	else:
		_play(_selector.on_selection(sound_sets_of(units), _now()), Vector3.INF)


func _on_command_issued(command: Command) -> void:
	if command.issuer_faction != player_faction:
		return
	var sets: Array[StringName] = sound_sets_of(command.entities)
	_play(_selector.on_command(sets, command.kind, _now()), Vector3.INF)
	if command.kind in AudioCueSelector.GROUND_KINDS:
		_play([&"world_order_ping"], command.target_position)


func _on_ui_feedback(kind: StringName) -> void:
	_play(AudioCueSelector.feedback_event(kind), Vector3.INF)


func _on_entity_spawned(entity: Node3D) -> void:
	if not is_instance_valid(entity) or faction_of(entity) != player_faction:
		return
	if is_building(entity):
		return
	var sound_set: StringName = MovementLoops.sound_set_of(entity)
	if sound_set != &"":
		_play([AudioCueSelector.unit_event(sound_set, &"ready")], Vector3.INF)


func _on_building_placed(building: Node3D) -> void:
	if _is_player(building):
		_play([&"base_place"], _position_of(building))


func _on_construction_completed(building: Node3D) -> void:
	if _is_player(building):
		_play([&"base_complete"], _position_of(building))


func _on_production_started(producer: Node3D, _def: EntityDef) -> void:
	if not _is_player(producer):
		return
	var finished_at: float = _last_completion.get(producer.get_instance_id(), -INF)
	if _now() - finished_at > QUEUE_ADVANCE_WINDOW:
		_play([&"ui_queue"], Vector3.INF)


func _on_production_completed(producer: Node3D, unit: Node3D) -> void:
	if not _is_player(producer):
		return
	_last_completion[producer.get_instance_id()] = _now()
	var at: Vector3 = _position_of(producer)
	if not at.is_finite() and is_instance_valid(unit):
		at = _position_of(unit)
	_play([&"base_unit_ready"], at)


func _on_harvest_delivered(hauler: Node3D, _amount: int) -> void:
	if _is_player(hauler):
		_play([&"base_unload"], _position_of(hauler))


func _on_resource_depleted(node: Node3D) -> void:
	if is_instance_valid(node):
		_play([&"base_depleted"], _position_of(node))


func _on_advisor_alert(kind: StringName) -> void:
	if kind in MissionSoundRouter.OBJECTIVE_ALERTS:
		return  # voiced by the MissionSoundRouter with the objective signals
	var at: Vector3 = alert_position.call(kind)
	offer_advisor_alert(kind, _now(), at)


func _is_player(entity: Node) -> bool:
	return is_instance_valid(entity) and faction_of(entity) == player_faction


## World position for a positional sound, or Vector3.INF (plays flat) if the
## entity is gone or not in the tree.
static func _position_of(entity: Node3D) -> Vector3:
	if is_instance_valid(entity) and entity.is_inside_tree():
		return entity.global_position
	return Vector3.INF


func _play(candidates: Array[StringName], at: Vector3) -> void:
	if not candidates.is_empty():
		play_first.call(candidates, at)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
