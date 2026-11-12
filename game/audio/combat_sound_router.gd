class_name CombatSoundRouter
extends Node
## Listens to the combat Events and decides what is heard; the decisions live in
## pure classes (CombatCues: which event; CombatMixer: what survives a crowded
## frame; MusicMood: which music state). This node only gathers inputs.
##
## - weapon_fired: `weapon_<set>_fire` (or its alias in CombatCues) at the
##   muzzle, unless the shooter is hidden (`is_visible_to_player == false`).
##   A Sentry that starts firing after a pause also swings its turret
##   (`base_turret_traverse`).
## - projectile_impacted: impact or explosion at the hit point; skipped if the
##   victim is hidden, or for ground hits if the fog says the point is hidden.
## - entity_died: death per weight class, building collapse.
## - entity_damaged on the player's side: offers &"under_attack" to the Advisor
##   (the AdvisorQueue throttles it and skips it while the camera shows the fight).
## - All of the above feed MusicMood; mission_ended plays a sting and settles.
##
## Fog query for ground impacts, first that exists: a node in group FOG_GROUP
## with `is_point_visible_to_player(position: Vector3) -> bool`; else the
## mission's vision grid, reached read-only through any entity seen in a combat
## event (`entity.world.vision.grid.is_visible(player_faction, position)`);
## else the impact is heard.

const FOG_GROUP: StringName = &"fog_of_war"
const FOG_METHOD: StringName = &"is_point_visible_to_player"
const MOOD_INTERVAL: float = 0.25
## A Sentry silent for this long swings onto its next target audibly.
const TRAVERSE_AFTER: float = 3.0
const TRAVERSE_EVENT: StringName = &"base_turret_traverse"
const SENTRY_SET: StringName = &"sentry"
## A gameplay `advisor_alert(&"under_attack")` is placed at the last hurt
## position if it was this recent.
const HURT_MEMORY: float = 3.0
const MAX_TRACKED_SHOOTERS: int = 256

@export var player_faction: int = 0

## Listener focus on the ground; set by the AudioService.
var focus: Vector3 = Vector3.ZERO
## `func(event_id: StringName) -> SoundEvent`
var resolve_event: Callable = func(_id: StringName) -> SoundEvent: return null
## `func(event_id: StringName, position: Vector3, volume_offset_db: float) -> bool`
var play_at: Callable = func(_id: StringName, _at: Vector3, _db: float) -> bool: return false
## `func(kind: StringName, position: Vector3) -> void`: offers an Advisor alert.
var offer_alert: Callable = func(_kind: StringName, _at: Vector3) -> void: pass
## `func(state: StringName) -> void`
var set_music_state: Callable = func(_state: StringName) -> void: pass
## `func(won: bool) -> void`: settles the music and plays the sting.
var end_music: Callable = func(_won: bool) -> void: pass

var mixer: CombatMixer = CombatMixer.new()
var mood: MusicMood = MusicMood.new()

var _mood_left: float = 0.0
var _music_state: StringName = &""
var _last_fire: Dictionary[int, float] = {}
var _last_hurt_position: Vector3 = Vector3.INF
var _last_hurt_time: float = -INF
var _vision_grid: Object = null


func _ready() -> void:
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.projectile_impacted.connect(_on_projectile_impacted)
	Events.entity_damaged.connect(_on_entity_damaged)
	Events.entity_died.connect(_on_entity_died)
	Events.mission_ended.connect(_on_mission_ended)


func _process(delta: float) -> void:
	flush(_now())
	_mood_left -= delta
	if _mood_left <= 0.0:
		_mood_left = MOOD_INTERVAL
		update_mood(_now())


## Plays what this frame's combat offers earned. Returns the ids started.
func flush(now: float) -> Array[StringName]:
	return mixer.flush(now, focus, play_at)


## Re-evaluates the music state and requests it if it changed.
func update_mood(now: float) -> StringName:
	var wanted: StringName = mood.update(now)
	if wanted != _music_state:
		_music_state = wanted
		if not mood.is_over():
			set_music_state.call(wanted)
	return wanted


## Where the player was last hurt, if recent (for gameplay-raised alerts).
func last_hurt_position(now: float) -> Vector3:
	if now - _last_hurt_time <= HURT_MEMORY:
		return _last_hurt_position
	return Vector3.INF


# --- Event handlers (public `handle_*` so tests can pass a time) -------------


func handle_weapon_fired(shooter: Node3D, weapon: Resource, muzzle: Vector3, now: float) -> void:
	_learn_vision(shooter)
	var at: Vector3 = muzzle if muzzle.is_finite() else _position_of(shooter)
	var hidden: bool = CombatCues.is_hidden(shooter)
	var player: bool = _is_player(shooter)
	if player or not hidden:
		mood.note_fire(_distance(at), now)
	if hidden or not at.is_finite():
		return
	for event_id: StringName in CombatCues.fire_events(weapon):
		if _has(event_id):
			_offer(event_id, at)
			break
	if _is_sentry(shooter, weapon):
		_maybe_traverse(shooter, at, now)


func handle_projectile_impacted(
	weapon: Resource, position: Vector3, victim: Node3D, _now_s: float
) -> void:
	if not position.is_finite():
		return
	if victim != null and is_instance_valid(victim):
		if CombatCues.is_hidden(victim):
			return
	elif not is_point_visible(position):
		return
	for event_id: StringName in CombatCues.impact_events(weapon, victim):
		if _has(event_id):
			_offer(event_id, position)
			return


func handle_entity_damaged(entity: Node3D, amount: float, attacker: Node3D, now: float) -> void:
	if entity == null or not is_instance_valid(entity) or amount <= 0.0:
		return
	_learn_vision(entity)
	var at: Vector3 = _position_of(entity)
	var victim_is_player: bool = _is_player(entity)
	var attacker_is_player: bool = attacker != null and _is_player(attacker)
	mood.note_damage(victim_is_player, attacker_is_player, _distance(at), now)
	if victim_is_player and not attacker_is_player and not mood.is_over():
		_last_hurt_position = at
		_last_hurt_time = now
		offer_alert.call(&"under_attack", at)


func handle_entity_died(entity: Node3D, now: float) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var at: Vector3 = _position_of(entity)
	var faction: int = AudioEventRouter.faction_of(entity)
	if faction != -1:
		mood.note_death(faction == player_faction, _distance(at), now)
	if CombatCues.is_hidden(entity) or not at.is_finite():
		return
	for event_id: StringName in CombatCues.death_events(entity):
		if _has(event_id):
			_offer(event_id, at)
			return


func handle_mission_ended(won: bool) -> void:
	if mood.is_over():
		return
	mood.end_mission(won)
	_music_state = mood.state
	end_music.call(won)


## True unless a fog node says the point is hidden.
func is_point_visible(position: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var answer: Variant = null
	var fog: Node = get_tree().get_first_node_in_group(FOG_GROUP)
	if fog != null and fog.has_method(FOG_METHOD):
		answer = fog.call(FOG_METHOD, position)
	elif is_instance_valid(_vision_grid) and _vision_grid.has_method(&"is_visible"):
		answer = _vision_grid.call(&"is_visible", player_faction, position)
	if answer is bool:
		var visible: bool = answer
		return visible
	return true


# --- Internals ----------------------------------------------------------------


func _on_weapon_fired(shooter: Node3D, weapon: Resource, muzzle: Vector3, _target: Vector3) -> void:
	handle_weapon_fired(shooter, weapon, muzzle, _now())


func _on_projectile_impacted(weapon: Resource, position: Vector3, victim: Node3D) -> void:
	handle_projectile_impacted(weapon, position, victim, _now())


func _on_entity_damaged(entity: Node3D, amount: float, attacker: Node3D) -> void:
	handle_entity_damaged(entity, amount, attacker, _now())


func _on_entity_died(entity: Node3D) -> void:
	handle_entity_died(entity, _now())


func _on_mission_ended(won: bool) -> void:
	handle_mission_ended(won)


func _offer(event_id: StringName, at: Vector3) -> void:
	var event: SoundEvent = resolve_event.call(event_id)
	if event == null:
		return
	mixer.offer(event_id, at, event.priority, event.max_distance)


func _has(event_id: StringName) -> bool:
	var event: SoundEvent = resolve_event.call(event_id)
	return event != null


## Remembers the mission's vision grid from an entity, if it exposes one.
func _learn_vision(entity: Node) -> void:
	if is_instance_valid(_vision_grid) or entity == null or not is_instance_valid(entity):
		return
	var world: Variant = entity.get(&"world")
	if not world is Object:
		return
	var world_object: Object = world
	var vision: Variant = world_object.get(&"vision")
	if not vision is Object:
		return
	var vision_object: Object = vision
	var grid: Variant = vision_object.get(&"grid")
	if grid is Object:
		_vision_grid = grid


func _is_sentry(shooter: Node3D, weapon: Resource) -> bool:
	var weapon_set: StringName = CombatCues.string_name_of(weapon, &"sound_set")
	if CombatCues.FIRE_ALIASES.get(weapon_set, weapon_set) == SENTRY_SET:
		return true
	return shooter != null and MovementLoops.sound_set_of(shooter) == SENTRY_SET


func _maybe_traverse(shooter: Node3D, at: Vector3, now: float) -> void:
	if shooter == null or not is_instance_valid(shooter):
		return
	var key: int = shooter.get_instance_id()
	var last: float = _last_fire.get(key, -INF)
	if _last_fire.size() >= MAX_TRACKED_SHOOTERS and not _last_fire.has(key):
		_last_fire.clear()
	_last_fire[key] = now
	if now - last >= TRAVERSE_AFTER:
		play_at.call(TRAVERSE_EVENT, at, 0.0)


func _is_player(entity: Node) -> bool:
	return (
		entity != null
		and is_instance_valid(entity)
		and AudioEventRouter.faction_of(entity) == player_faction
	)


func _distance(at: Vector3) -> float:
	if not at.is_finite():
		return INF
	return Vector2(at.x - focus.x, at.z - focus.z).length()


static func _position_of(entity: Node3D) -> Vector3:
	if entity != null and is_instance_valid(entity) and entity.is_inside_tree():
		return entity.global_position
	return Vector3.INF


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
