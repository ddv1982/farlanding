class_name SaveFixture
extends RefCounted
## Real missions on their real map for the save tests (ADR 0013). Lands a mission
## (fresh or restored from a snapshot) under `parent`, with its sim clock driven only
## by `run()` (the clock's own frame driving is switched off), and offers the small
## helpers the round-trip tests share: find units, place a building, compare two
## worlds, normalise a snapshot.

const CAMPAIGN: String = "res://data/campaign/kessel_trail.tres"

var parent: Node


func _init(p_parent: Node) -> void:
	parent = p_parent


## Lands `mission` (with `modifiers`, restored from `restore` when given) and lets the
## navigation map settle for a few physics frames. Time then moves only through `run()`.
func land(
	mission: MissionDef, modifiers: LandingModifiers = null, restore: Dictionary = {}
) -> LandingMap:
	var map: LandingMap = mission.map_scene.instantiate() as LandingMap
	map.mission = mission
	map.modifiers = modifiers
	map.restore_state = restore
	parent.add_child(map)
	map.context.sim_clock.process_mode = Node.PROCESS_MODE_DISABLED
	# The navigation map answers path queries only once it has synchronised with the
	# navmesh the map cut (a threaded bake): wait for a real path.
	var units: Array[Unit] = map.world.units_of(mission.player_faction)
	var from: Vector3 = units[0].sim_position() if not units.is_empty() else Vector3.ZERO
	var navigation: RID = map.get_world_3d().navigation_map
	for i: int in 600:
		await parent.get_tree().physics_frame
		if i < 2 or NavigationServer3D.map_get_iteration_id(navigation) == 0:
			continue
		var to: Vector3 = map.world.paths.closest_point(from + Vector3(20.0, 0.0, -20.0))
		if not map.world.paths.find_path(from, to).is_empty():
			break
	return map


## Runs `ticks` sim ticks, with a physics frame every few (navigation updates).
func run(map: LandingMap, ticks: int) -> void:
	for i: int in ticks:
		map.context.sim_clock.advance(SimClock.TICK_DELTA)
		if i % 5 == 4:
			await parent.get_tree().physics_frame


## Runs until `done` (`func() -> bool`) holds, at most `limit` ticks. Returns whether
## it did.
func run_until(map: LandingMap, done: Callable, limit: int) -> bool:
	for i: int in limit:
		map.context.sim_clock.advance(SimClock.TICK_DELTA)
		if i % 5 == 4:
			await parent.get_tree().physics_frame
		if done.call():
			return true
	return false


## Frees `map` (a Variant: it may already be freed).
func dispose(map: Variant) -> void:
	if not is_instance_valid(map):
		return
	var node: Node = map
	if node.get_parent() == parent:
		parent.remove_child(node)
	node.free()


## The mission of `id` in the catalog or the campaign.
static func mission(id: StringName) -> MissionDef:
	for path: String in [
		"res://data/missions/conquest.tres",
		"res://data/missions/survey.tres",
		"res://data/missions/infiltration.tres",
		"res://data/missions/thalassa_shallows.tres",
		"res://data/missions/thalassa_recovery.tres",
	]:
		var def: MissionDef = load(path) as MissionDef
		if def != null and def.id == id:
			return def
	return null


## The modifiers a fresh campaign lands `node_id` with.
static func campaign_modifiers(node_id: StringName) -> LandingModifiers:
	var campaign: CampaignDef = load(CAMPAIGN) as CampaignDef
	var plan: LandingPlan = LandingPlan.from_state(CampaignState.new(campaign), node_id)
	return LandingBuilder.build(campaign, plan)


## The first living unit of `faction` whose def id is `def_id` (skipping `exclude`).
static func unit_of(
	world: SimWorld, faction: int, def_id: StringName, exclude: Array[Unit] = []
) -> Unit:
	for unit: Unit in world.units_of(faction):
		if unit.def.id == def_id and not unit.is_dead and not exclude.has(unit):
			return unit
	return null


## Puts `unit` down at `at` (standing, no orders): test set-up only.
static func teleport(unit: Unit, at: Vector3) -> void:
	unit.orders.stop()
	var data: Dictionary = unit.locomotion.to_dict()
	var mover: Dictionary = data["mover"]
	mover["position"] = var_to_str(at)
	mover["path"] = var_to_str(PackedVector3Array())
	mover["speed"] = 0.0
	data["travelling"] = false
	unit.locomotion.from_dict(data)


## Makes `entity` (a unit or building) much harder to kill: test set-up only.
static func toughen(entity: Node3D, health: float) -> void:
	Combat.health_of(entity).from_dict({"version": 1, "current": health, "max": health})


static func count_of(world: SimWorld, faction: int, def_id: StringName) -> int:
	var count: int = 0
	for unit: Unit in world.units_of(faction):
		if unit.def.id == def_id and not unit.is_dead:
			count += 1
	return count


## A spot near `hq` where `def` may be placed now, clear of its door and dock, or
## Vector3.INF.
static func free_spot(world: SimWorld, def: BuildingDef, hq: Building) -> Vector3:
	var rules: PlacementRules = world.placement_rules()
	for ring: float in [12.0, 16.0, 20.0, 24.0, 28.0]:
		for step: int in 16:
			var angle: float = TAU * step / 16.0
			var at: Vector3 = rules.snap(
				def, hq.position + Vector3(cos(angle) * ring, 0.0, sin(angle) * ring)
			)
			var clear: bool = (
				at.distance_to(hq.dock_position()) > 12.0
				and at.distance_to(hq.door_position()) > 12.0
			)
			if clear and rules.check(def, at) == PlacementRules.OK:
				return at
	return Vector3.INF


## The snapshot without what legitimately differs between two saves of the same
## situation: the camera, and the explored fog (a load refreshes the player's sight at
## once, where the running game updates it on a staggered tick, so it may only grow:
## see `explored_covers`).
static func normalised(snapshot: Dictionary) -> Dictionary:
	var copy: Dictionary = snapshot.duplicate(true)
	copy.erase("camera")
	var world: Dictionary = copy.get("world", {})
	var vision: Dictionary = world.get("vision", {})
	var grid: Dictionary = vision.get("grid", {})
	grid.erase("explored")
	return copy


## True if every cell explored in `saved` is explored in `loaded` (snapshots).
static func explored_covers(loaded: Dictionary, saved: Dictionary) -> bool:
	var after: Dictionary = loaded["world"]["vision"]["grid"]["explored"]
	var before: Dictionary = saved["world"]["vision"]["grid"]["explored"]
	for faction: Variant in before:
		if not after.has(faction):
			return false
		var old_text: String = before[faction]
		var new_text: String = after[faction]
		var old_cells: PackedByteArray = Marshalls.base64_to_raw(old_text)
		var new_cells: PackedByteArray = Marshalls.base64_to_raw(new_text)
		if old_cells.size() != new_cells.size():
			return false
		for i: int in old_cells.size():
			if new_cells[i] < old_cells[i]:
				return false
	return true


## Lines describing where `a` and `b` (nested saves) differ, at most `limit`.
static func differences(
	a: Variant, b: Variant, path: String = "", limit: int = 12
) -> Array[String]:
	var found: Array[String] = []
	_diff(a, b, path, found, limit)
	return found


static func _diff(a: Variant, b: Variant, path: String, found: Array[String], limit: int) -> void:
	if found.size() >= limit:
		return
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		for key: Variant in da:
			if not db.has(key):
				found.append("%s/%s only in the first" % [path, key])
				continue
			_diff(da[key], db[key], "%s/%s" % [path, key], found, limit)
		for key: Variant in db:
			if not da.has(key):
				found.append("%s/%s only in the second" % [path, key])
		return
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			found.append("%s: %d vs %d entries" % [path, aa.size(), ab.size()])
			return
		for i: int in aa.size():
			_diff(aa[i], ab[i], "%s[%d]" % [path, i], found, limit)
		return
	if var_to_str(a) != var_to_str(b):
		found.append("%s: %s vs %s" % [path, var_to_str(a).left(80), var_to_str(b).left(80)])
