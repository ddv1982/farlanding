class_name Projectile
extends Node3D
## A shot in flight. Combat moves it on sim ticks and places the node between ticks
## every frame, facing along its travel (-Z forward); presentation parents the look
## under it on `Events.projectile_launched`. Shots without splash follow their
## target (they hit what they were fired at); splash shots fly to a fixed point.

const SAVE_VERSION: int = 1
const GROUP: StringName = &"projectiles"

var weapon: WeaponDef
## Who fired it; may be freed while the shot is in flight.
var shooter: Node3D = null
var faction: int = 0
## The entity it follows (shots without splash), or null.
var target: Node3D = null
var start: Vector3 = Vector3.ZERO
var goal: Vector3 = Vector3.ZERO
## Share of the way flown, in [0, 1].
var progress: float = 0.0
## Read by audio: no sound for shots the player cannot see.
var is_visible_to_player: bool = true

var _previous: Vector3 = Vector3.ZERO
var _current: Vector3 = Vector3.ZERO
var _apex: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func setup(
	p_weapon: WeaponDef, p_shooter: Node3D, p_faction: int, from: Vector3, to: Vector3
) -> void:
	weapon = p_weapon
	shooter = p_shooter
	faction = p_faction
	start = from
	goal = to
	progress = 0.0
	var flat: float = Vector2(to.x - from.x, to.z - from.z).length()
	_apex = weapon.arc_height * clampf(flat / maxf(weapon.max_range, 1.0), 0.25, 1.0)
	_current = from
	_previous = from
	position = from


## Simulation position (leads the drawn node by up to one tick).
func sim_position() -> Vector3:
	return _current


## One sim tick of flight. Returns true when it arrived at its goal.
func advance(dt: float) -> bool:
	if is_instance_valid(target) and target.is_inside_tree():
		goal = Weapon.aim_point(target)
	_previous = _current
	var length: float = maxf(start.distance_to(goal), 0.01)
	progress = minf(progress + weapon.projectile_speed * dt / length, 1.0)
	_current = start.lerp(goal, progress) + Vector3.UP * (4.0 * _apex * progress * (1.0 - progress))
	return progress >= 1.0


## Places the node between the last two sim positions; `fraction` in [0, 1].
func interpolate(fraction: float) -> void:
	var at: Vector3 = _previous.lerp(_current, fraction)
	var heading: Vector3 = _current - _previous
	if heading.length_squared() < 1e-8:
		heading = goal - start
	position = at
	if heading.length_squared() > 1e-8 and absf(heading.normalized().y) < 0.999:
		look_at(at + heading, Vector3.UP)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"weapon": weapon.resource_path if weapon != null else "",
		"faction": faction,
		"start": var_to_str(start),
		"goal": var_to_str(goal),
		"progress": progress,
		"target": Order.entity_id_of(target),
	}


## Restores a shot saved by `to_dict()`; returns false if its weapon is gone. The
## target is reconnected through `lookup` (`func(id: int) -> Node3D`).
func from_dict(data: Dictionary, lookup: Callable) -> bool:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Projectile save version")
	var path: String = data.get("weapon", "")
	if path == "" or not ResourceLoader.exists(path):
		return false
	var start_text: String = data.get("start", "Vector3(0, 0, 0)")
	var goal_text: String = data.get("goal", "Vector3(0, 0, 0)")
	var saved_faction: int = data.get("faction", 0)
	var from: Vector3 = str_to_var(start_text)
	var to: Vector3 = str_to_var(goal_text)
	setup(load(path) as WeaponDef, null, saved_faction, from, to)
	progress = data.get("progress", 0.0)
	var target_id: int = data.get("target", -1)
	if target_id >= 0 and lookup.is_valid():
		target = lookup.call(target_id)
	return weapon != null
