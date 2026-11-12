class_name AudioEventRouter
extends Node
## Listens to `Events` and decides what is heard. The decisions themselves live
## in AudioCueSelector (pure, tested); this node only gathers the inputs.
##
## Entity contract: an entity is a Node3D whose `def` property is an EntityDef;
## `def.sound_set` (e.g. &"ranger") names its replies `unit_<set>_<kind>`.

## Only orders from this faction are acknowledged.
@export var player_faction: int = 0

## Plays the first existing event of a candidate list:
## `func(candidates: Array[StringName], position: Vector3) -> StringName`.
var play_first: Callable = func(_ids: Array[StringName], _at: Vector3) -> StringName: return &""

var _selector: AudioCueSelector = AudioCueSelector.new()


func _ready() -> void:
	Events.selection_changed.connect(_on_selection_changed)
	Events.command_issued.connect(_on_command_issued)
	Events.ui_feedback.connect(_on_ui_feedback)
	Events.entity_spawned.connect(_on_entity_spawned)
	Events.entity_died.connect(_on_entity_died)


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


func _on_selection_changed(entities: Array[Node3D]) -> void:
	_play(_selector.on_selection(sound_sets_of(entities), _now()), Vector3.INF)


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
	var sound_set: StringName = MovementLoops.sound_set_of(entity)
	if sound_set != &"":
		_play([AudioCueSelector.unit_event(sound_set, &"ready")], Vector3.INF)


func _on_entity_died(entity: Node3D) -> void:
	if not is_instance_valid(entity):
		return
	var sound_set: StringName = MovementLoops.sound_set_of(entity)
	if sound_set != &"":
		var at: Vector3 = entity.global_position if entity.is_inside_tree() else Vector3.INF
		_play([AudioCueSelector.unit_event(sound_set, &"death")], at)


func _play(candidates: Array[StringName], at: Vector3) -> void:
	if not candidates.is_empty():
		play_first.call(candidates, at)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
