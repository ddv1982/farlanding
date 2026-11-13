class_name HintDirector
extends RefCounted
## Decides which tutorial hint is due (ADR 0011). It listens to `Events` while a
## mission runs, matches each trigger against the catalog, skips hints this profile
## has seen (`Settings.has_seen_hint`) or that belong to other mission types, and
## queues the rest; `next_due()` hands out one at a time and marks it seen (saved),
## so every hint shows once per profile. Pure logic: TutorialHints draws the card.

## Seconds a mission must have run before any card shows (let the landing settle).
const SETTLE_SECONDS: float = 1.5

var catalog: HintCatalog = null
var active: bool = false
var mission_type: StringName = &""

## Queued: [HintDef, due at (seconds of mission time)].
var _queue: Array[Array] = []
var _clock: float = 0.0
var _connected: bool = false


func setup(p_catalog: HintCatalog) -> void:
	catalog = p_catalog
	if _connected:
		return
	_connected = true
	Events.selection_changed.connect(_on_selection_changed)
	Events.construction_completed.connect(_on_construction_completed)
	Events.storm_incoming.connect(_on_storm_incoming)
	Events.tide_turning.connect(_on_tide_turning)
	Events.eruption_warning.connect(_on_eruption_warning)
	Events.alert_level_changed.connect(_on_alert_level_changed)


## Stops listening (the flow is being freed).
func dispose() -> void:
	if not _connected:
		return
	_connected = false
	Events.selection_changed.disconnect(_on_selection_changed)
	Events.construction_completed.disconnect(_on_construction_completed)
	Events.storm_incoming.disconnect(_on_storm_incoming)
	Events.tide_turning.disconnect(_on_tide_turning)
	Events.eruption_warning.disconnect(_on_eruption_warning)
	Events.alert_level_changed.disconnect(_on_alert_level_changed)


## A mission of `type` began: hints may show, starting with the mission-start ones.
func begin(type: StringName) -> void:
	active = true
	mission_type = type
	_queue.clear()
	_clock = 0.0
	fire(HintDef.TRIGGER_MISSION_STARTED)


## The mission is over: nothing more shows.
func end() -> void:
	active = false
	_queue.clear()


## Advances mission time by `delta` seconds.
func advance(delta: float) -> void:
	_clock += delta


## The hint whose time has come (marked seen), or null.
func next_due() -> HintDef:
	if not active or _clock < SETTLE_SECONDS:
		return null
	for i: int in _queue.size():
		var entry: Array = _queue[i]
		var due: float = entry[1]
		if due > _clock:
			continue
		var hint: HintDef = entry[0]
		_queue.remove_at(i)
		if Settings.has_seen_hint(hint.id):
			return next_due()
		Settings.mark_hint_seen(hint.id)
		return hint
	return null


## Hints waiting (tests).
func queued() -> int:
	return _queue.size()


## `trigger` fired, involving `subjects` (capabilities and def ids).
func fire(trigger: StringName, subjects: Array[StringName] = []) -> void:
	if not active or catalog == null:
		return
	for hint: HintDef in catalog.hints:
		if hint == null or hint.trigger != trigger or Settings.has_seen_hint(hint.id):
			continue
		if not hint.mission_types.is_empty() and not hint.mission_types.has(mission_type):
			continue
		if hint.subject != &"" and not subjects.has(hint.subject):
			continue
		if _is_queued(hint):
			continue
		_queue.append([hint, _clock + hint.delay_seconds])


## Capabilities and the def id of `entity`, for subject matching.
static func subjects_of(entity: Node3D) -> Array[StringName]:
	var found: Array[StringName] = []
	if not is_instance_valid(entity):
		return found
	var unit: Unit = entity as Unit
	if unit != null:
		if unit.builder != null:
			found.append(HintDef.SUBJECT_BUILDER)
		if unit.harvester != null:
			found.append(HintDef.SUBJECT_HARVESTER)
		if unit.scanner != null:
			found.append(HintDef.SUBJECT_SCANNER)
		if unit.saboteur != null:
			found.append(HintDef.SUBJECT_SABOTEUR)
		if unit.def != null:
			found.append(unit.def.id)
	var building: Building = entity as Building
	if building != null:
		if building.producer != null:
			found.append(HintDef.SUBJECT_PRODUCER)
		if building.def != null:
			found.append(building.def.id)
	return found


func _is_queued(hint: HintDef) -> bool:
	for entry: Array in _queue:
		if entry[0] == hint:
			return true
	return false


func _on_selection_changed(entities: Array[Node3D]) -> void:
	var subjects: Array[StringName] = []
	for entity: Node3D in entities:
		for subject: StringName in subjects_of(entity):
			if not subjects.has(subject):
				subjects.append(subject)
	if not subjects.is_empty():
		fire(HintDef.TRIGGER_SELECTED, subjects)


func _on_construction_completed(building: Node3D) -> void:
	var placed: Building = building as Building
	if placed == null or placed.world == null or placed.faction != placed.world.player_faction:
		return
	fire(HintDef.TRIGGER_CONSTRUCTION_COMPLETED, subjects_of(placed))


func _on_storm_incoming(_seconds: float) -> void:
	fire(HintDef.TRIGGER_STORM_INCOMING)


func _on_tide_turning(_seconds: float, _rising: bool) -> void:
	fire(HintDef.TRIGGER_TIDE_TURNING)


func _on_eruption_warning(_vent: Node3D, _seconds: float, _radius: float) -> void:
	fire(HintDef.TRIGGER_ERUPTION_WARNING)


func _on_alert_level_changed(_faction: int, _level: StringName, _previous: StringName) -> void:
	fire(HintDef.TRIGGER_ALERT_METER)
