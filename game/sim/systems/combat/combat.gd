class_name Combat
extends Node3D
## Shots, projectiles and damage for one mission. Each sim tick SimWorld calls
## `begin_tick()` (rebuilds the spatial grid of living units and buildings), lets
## every weapon act, then `tick_projectiles()`. Weapons ask it for targets
## (`find_target`, `can_target`) and fire through `fire()`. Damage goes through the
## DamageTable into each entity's Health. Projectiles are children of this node.
## Registered on the MissionContext as `SERVICE_KEY`.

const SERVICE_KEY: StringName = &"combat"
const SAVE_VERSION: int = 1
## Spatial grid cell, in metres.
const GRID_CELL: float = 16.0
## Largest body radius (a building's footprint) a range check must reach into.
const MAX_BODY_RADIUS: float = 9.0
## Unarmed units and buildings rank this many metres further away as targets, so
## weapons shoot the things shooting back first.
const SOFT_TARGET_PENALTY: float = 6.0
## Ticks between two `under_attack` Advisor alerts (one second).
const ALERT_TICKS: int = 10
## Splash damage at the edge of the radius, as a share of full damage.
const SPLASH_EDGE: float = 0.5

var world: SimWorld = null
var damage_table: DamageTable = DamageTable.new()
var player_faction: int = 0
## Sim ticks seen so far (weapons stagger their target looks on it).
var tick_count: int = 0
var projectiles: Array[Projectile] = []
## Wall-clock cost of the last tick's grid rebuild plus projectile flight, in µs.
var last_tick_usec: int = 0

var _grid: SpatialGrid = SpatialGrid.new(GRID_CELL)
var _last_alert_tick: int = -1000000


func setup(p_world: SimWorld, p_table: DamageTable, p_player_faction: int) -> void:
	world = p_world
	if p_table != null:
		damage_table = p_table
	player_faction = p_player_faction


## Start of a sim tick: re-buckets every living unit and building.
func begin_tick(units: Array[Unit], buildings: Array[Building]) -> void:
	var started: int = Time.get_ticks_usec()
	tick_count += 1
	_grid.clear()
	for unit: Unit in units:
		if not unit.is_dead:
			_grid.insert(unit, unit.sim_position())
	for building: Building in buildings:
		if not building.is_dead:
			_grid.insert(building, building.position)
	last_tick_usec = Time.get_ticks_usec() - started


## True if `faction` may shoot `target` now: a living unit or building of another
## faction on a cell that faction can see.
func can_target(faction: int, target: Variant) -> bool:
	if not is_alive(target):
		return false
	var node: Node3D = target
	var target_faction: int = faction_of(node)
	if target_faction < 0 or target_faction == faction:
		return false
	return world == null or world.vision == null or world.vision.can_see(faction, node)


## The best target for `faction` whose body is within `reach` of `from`: the
## nearest visible enemy, armed units before unarmed ones and buildings. Null if none.
func find_target(faction: int, from: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var best_score: float = INF
	for candidate: Node3D in _grid.query(from, reach + MAX_BODY_RADIUS):
		var candidate_faction: int = faction_of(candidate)
		if candidate_faction == faction or candidate_faction < 0:
			continue
		var distance: float = reach_to(candidate, from)
		if distance > reach:
			continue
		var score: float = distance + (0.0 if is_armed(candidate) else SOFT_TARGET_PENALTY)
		if score >= best_score or not can_target(faction, candidate):
			continue
		best = candidate
		best_score = score
	return best


## Fires one projectile (or an instant hit) of `def` from `muzzle` at `target`.
func fire(
	def: WeaponDef,
	shooter: Node3D,
	faction: int,
	muzzle: Vector3,
	target: Node3D,
	aim_at: Vector3,
) -> void:
	Events.weapon_fired.emit(shooter, def, muzzle, aim_at)
	if def.projectile_speed <= 0.0:
		_impact(def, shooter, faction, aim_at, target)
		return
	var goal: Vector3 = aim_at
	if def.splash_radius > 0.0:
		# Lobbed shots fly to where the target will be, and can be dodged.
		goal += _velocity_of(target) * def.travel_time(muzzle.distance_to(aim_at))
		goal.y = minf(goal.y, aim_at.y)
	var shot: Projectile = Projectile.new()
	shot.name = &"Projectile"
	shot.setup(def, shooter, faction, muzzle, goal)
	if def.splash_radius <= 0.0:
		shot.target = target
	add_child(shot)
	_update_seen(shot)
	projectiles.append(shot)
	Events.projectile_launched.emit(shot, def)


## Moves every shot one tick; shots that arrive deal their damage and leave.
func tick_projectiles(dt: float) -> void:
	var started: int = Time.get_ticks_usec()
	var flying: Array[Projectile] = []
	for shot: Projectile in projectiles:
		if not is_instance_valid(shot):
			continue
		if not shot.advance(dt):
			flying.append(shot)
			_update_seen(shot)
			continue
		var victim: Node3D = shot.target if is_alive(shot.target) else null
		var shooter: Node3D = shot.shooter if is_instance_valid(shot.shooter) else null
		_impact(shot.weapon, shooter, shot.faction, shot.sim_position(), victim)
		shot.queue_free()
	projectiles = flying
	last_tick_usec += Time.get_ticks_usec() - started


## Places every shot between sim ticks.
func interpolate(fraction: float) -> void:
	for shot: Projectile in projectiles:
		if is_instance_valid(shot):
			shot.interpolate(fraction)


## Deals `amount` of `damage_type` to `entity` through the DamageTable. Returns the
## damage taken. Raises the player's `under_attack` alert at most once a second.
func damage(entity: Node3D, amount: float, damage_type: StringName, attacker: Node3D) -> float:
	var health: Health = health_of(entity)
	if health == null or health.is_dead():
		return 0.0
	var source: Node3D = attacker if is_instance_valid(attacker) else null
	var taken: float = health.take(
		damage_table.apply(amount, damage_type, health.armour_type), source
	)
	if taken > 0.0 and source != null and world != null and world.vision != null:
		world.vision.expose(source, faction_of(entity))
	if taken > 0.0 and faction_of(entity) == player_faction:
		if tick_count - _last_alert_tick >= ALERT_TICKS:
			_last_alert_tick = tick_count
			Events.advisor_alert.emit(&"under_attack")
	return taken


func to_dict() -> Dictionary:
	var shots: Array[Dictionary] = []
	for shot: Projectile in projectiles:
		if is_instance_valid(shot):
			shots.append(shot.to_dict())
	return {"version": SAVE_VERSION, "tick": tick_count, "projectiles": shots}


## Restores the tick count and the shots in flight; call after the entities exist.
func from_dict(data: Dictionary, lookup: Callable) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Combat save version")
	tick_count = data.get("tick", 0)
	var shots: Array = data.get("projectiles", [])
	for entry: Variant in shots:
		var shot_data: Dictionary = entry
		var shot: Projectile = Projectile.new()
		if not shot.from_dict(shot_data, lookup):
			shot.free()
			continue
		shot.name = &"Projectile"
		add_child(shot)
		projectiles.append(shot)
		Events.projectile_launched.emit(shot, shot.weapon)


## True for a unit or building that is in the world and not dead.
static func is_alive(entity: Variant) -> bool:
	if not is_instance_valid(entity) or not entity is Node3D:
		return false
	var node: Node3D = entity
	if not node.is_inside_tree() or node.is_queued_for_deletion():
		return false
	var health: Health = health_of(node)
	return health != null and not health.is_dead()


## The entity's faction, or -1 for things without one (resource nodes).
static func faction_of(entity: Node3D) -> int:
	if entity is Unit:
		return (entity as Unit).faction
	if entity is Building:
		return (entity as Building).faction
	return -1


static func health_of(entity: Node3D) -> Health:
	if entity is Unit:
		return (entity as Unit).health
	if entity is Building:
		return (entity as Building).health
	return null


## True for a unit or building with a weapon.
static func is_armed(entity: Node3D) -> bool:
	if entity is Unit:
		return (entity as Unit).weapon != null
	if entity is Building:
		return (entity as Building).weapon != null
	return false


## Ground distance from `from` to the edge of `entity`'s body.
static func reach_to(entity: Node3D, from: Vector3) -> float:
	var at: Vector3 = AttackCommand.position_of(entity)
	var flat: float = Vector2(at.x - from.x, at.z - from.z).length()
	return maxf(flat - AttackCommand.body_radius(entity), 0.0)


func _impact(def: WeaponDef, shooter: Node3D, faction: int, point: Vector3, victim: Node3D) -> void:
	Events.projectile_impacted.emit(def, point, victim)
	if def.splash_radius <= 0.0:
		if victim != null:
			damage(victim, def.damage, def.damage_type, shooter)
		return
	var hit: Array[Node3D] = []
	if victim != null:
		hit.append(victim)
		damage(victim, def.damage, def.damage_type, shooter)
	for entity: Node3D in _grid.query(point, def.splash_radius + MAX_BODY_RADIUS):
		if hit.has(entity) or not is_alive(entity):
			continue
		var entity_faction: int = faction_of(entity)
		if entity_faction == faction or entity_faction < 0:
			continue
		var distance: float = reach_to(entity, point)
		if distance > def.splash_radius:
			continue
		hit.append(entity)
		var falloff: float = lerpf(1.0, SPLASH_EDGE, distance / def.splash_radius)
		damage(entity, def.damage * falloff, def.damage_type, shooter)


func _update_seen(shot: Projectile) -> void:
	var seen: bool = (
		world == null
		or world.vision == null
		or shot.faction == player_faction
		or world.vision.grid.is_visible(player_faction, shot.sim_position())
	)
	shot.is_visible_to_player = seen
	shot.visible = seen


static func _velocity_of(entity: Node3D) -> Vector3:
	var unit: Unit = entity as Unit
	if unit != null and unit.locomotion != null:
		return unit.locomotion.mover.velocity
	return Vector3.ZERO
