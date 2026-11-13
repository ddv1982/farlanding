class_name Objective
extends RefCounted
## One mission objective at run time (PLAN 3.6). Small subclasses in
## `missions/objectives/` decide when it is achieved or lost; the Mission evaluates
## every active objective each sim tick and announces changes on `Events`
## (objective_added / updated / completed / failed). Audio, UI and presentation read
## `id`, `title`, `kind`, `state`, `progress_text`, and `has_area` / `area_center` /
## `area_radius` for a marker, `countdown_tick` for a timer.

const KIND_PRIMARY: StringName = &"primary"
const KIND_SECONDARY: StringName = &"secondary"
const KIND_HIDDEN: StringName = &"hidden"
const STATE_ACTIVE: StringName = &"active"
const STATE_DONE: StringName = &"done"
const STATE_FAILED: StringName = &"failed"
const SAVE_VERSION: int = 1

var id: StringName = &""
var title: String = ""
var kind: StringName = KIND_PRIMARY
var state: StringName = STATE_ACTIVE
var progress_text: String = ""
## Holds until the end: does not block a win, done when the mission is won.
var passive: bool = false
## A hidden objective becomes known once achieved; the others are known at once.
var is_known: bool = true
## A place on the map this objective is about (shown by a marker and the minimap).
var has_area: bool = false
var area_center: Vector3 = Vector3.ZERO
var area_radius: float = 0.0
## Sim tick a timer runs to (a deadline, or the end of a hold-out); -1 = none.
var countdown_tick: int = -1
## True: failing at `countdown_tick`; false: the countdown is the goal (Survive).
var countdown_fails: bool = true
## Sim tick it began.
var started_tick: int = 0
var def: ObjectiveDef = null
var mission: Mission = null


## Copies the shared fields of `p_def`.
func configure(p_def: ObjectiveDef) -> void:
	def = p_def
	id = p_def.id
	title = p_def.title
	kind = p_def.kind
	passive = p_def.passive
	if p_def.area_radius > 0.0:
		has_area = true
		area_center = p_def.area_center
		area_radius = p_def.area_radius


## Begins in `p_mission` at its current tick.
func start(p_mission: Mission) -> void:
	mission = p_mission
	is_known = kind != KIND_HIDDEN
	started_tick = mission.now()
	if def != null and def.deadline_seconds > 0.0:
		set_deadline(def.deadline_seconds)
	_start()


## Fails if not achieved within `seconds` from now.
func set_deadline(seconds: float) -> void:
	countdown_tick = mission.now() + CommanderDifficulty.ticks(seconds)
	countdown_fails = true


## Seconds left on the countdown at `tick` (0 when none or over).
func seconds_left(tick: int) -> float:
	if countdown_tick < 0:
		return 0.0
	return maxf(float(countdown_tick - tick) / SimClock.TICK_RATE, 0.0)


## One sim tick while active.
func evaluate() -> void:
	if state != STATE_ACTIVE:
		return
	_evaluate()
	if state == STATE_ACTIVE and countdown_fails and countdown_tick >= 0:
		if mission.now() >= countdown_tick:
			fail()


func is_active() -> bool:
	return state == STATE_ACTIVE


func complete() -> void:
	_set_state(STATE_DONE)


func fail() -> void:
	_set_state(STATE_FAILED)


## Changes the progress line (announced when it differs).
func set_progress(text: String) -> void:
	if text == progress_text:
		return
	progress_text = text
	if mission != null:
		mission.on_objective_progress(self)


## Moves its area (e.g. the extraction point moved), announced as an update.
func move_area(center: Vector3, radius: float = -1.0) -> void:
	has_area = true
	area_center = center
	if radius > 0.0:
		area_radius = radius
	if mission != null:
		mission.on_objective_progress(self)


## Something died (forwarded by the mission while active).
func on_entity_died(_entity: Node3D) -> void:
	pass


## The mission was won: a passive objective still holding counts as done.
func on_mission_won() -> void:
	if state == STATE_ACTIVE and passive:
		complete()


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"id": id,
		"state": state,
		"known": is_known,
		"progress": progress_text,
		"countdown": countdown_tick,
		"started": started_tick,
		"area": var_to_str(area_center),
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Objective save version")
	var saved_state: StringName = data.get("state", STATE_ACTIVE)
	state = saved_state
	is_known = data.get("known", is_known)
	progress_text = data.get("progress", "")
	countdown_tick = data.get("countdown", -1)
	started_tick = data.get("started", 0)
	var text: String = data.get("area", "Vector3(0, 0, 0)")
	area_center = str_to_var(text)


## Override: set up (look at the world as it is when the objective begins).
func _start() -> void:
	pass


## Override: one sim tick; call complete(), fail() or set_progress().
func _evaluate() -> void:
	pass


func _set_state(next: StringName) -> void:
	if state != STATE_ACTIVE or next == state:
		return
	state = next
	if mission != null:
		mission.on_objective_finished(self)


## The factions `side` names, seen from the mission's player.
func factions_of(side: StringName) -> Array[int]:
	var result: Array[int] = []
	match side:
		ObjectiveDef.SIDE_PLAYER:
			result.append(mission.player_faction)
		ObjectiveDef.SIDE_CUSTODIAN:
			result.append(Factions.CUSTODIANS)
		_:
			result.append_array(mission.enemy_factions())
	return result


## True if `entity` is one of the things `def` is about (side and types).
func matches(entity: Node3D) -> bool:
	var faction: int = Combat.faction_of(entity)
	if faction < 0 or not factions_of(def.side).has(faction):
		return false
	if def.defs.is_empty():
		return true
	var value: Variant = entity.get(&"def")
	return value is EntityDef and def.defs.has(value)


## Living units and buildings `def` is about.
func living_matches(include_units: bool = true, include_buildings: bool = true) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if include_units:
		for unit: Unit in mission.world.units:
			if Combat.is_alive(unit) and matches(unit):
				found.append(unit)
	if include_buildings:
		for building: Building in mission.world.buildings:
			if Combat.is_alive(building) and matches(building):
				found.append(building)
	return found
