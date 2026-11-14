class_name VentKeeper
extends RefCounted
## How the enemy commander copes with Emberfall's vents (ADR 0015), run on each of its
## decisions. It reads only public knowledge (the vents' dangers through its AiPort)
## and its own things, and acts only through Commands:
##
## - its Taps vent on purpose once their vent's pressure passes the profile's
##   `vent_at_pressure` (when the EruptionSystem allows it), so they are not knocked out;
## - its units standing within a vent's radius that bursts within `vent_flee_seconds`
##   walk out of it (an army is not left parked on a vent about to burst);
## - it keeps `extractors_wanted` extractors (the Combine Siphon) on vents it has
##   explored near home that are not about to burst, built by an idle builder. This
##   last part works on any planet with vents (calm vents never burst).

## A unit walks this far beyond the danger radius.
const CLEARANCE: float = 5.0
## Sim ticks before the same unit is sent out of the same danger again.
const REORDER_TICKS: int = 50
## A vent counts as "near home" within this share of the profile's deposit radius.
const HOME_SHARE: float = 1.5
## A vent this full or fuller is not built on.
const BUILD_MAX_PRESSURE: float = 0.6
## Sim ticks before the same vent is tried again after a placement on it (2 min). A
## refused placement (ground it cannot build on) used to be retried every decision,
## holding a builder forever (found by the balance harness, ADR 0018).
const RETRY_TICKS: int = 1200

var port: AiPort
var world: SimWorld
var profile: CommanderProfile
var faction: int = 1
## Units ordered out of danger -> sim tick of that order.
var _fled: Dictionary[int, int] = {}
## Vent (instance id) -> sim tick before which it is not built on again.
var _tried: Dictionary[int, int] = {}


func _init(p_port: AiPort, p_world: SimWorld, p_profile: CommanderProfile) -> void:
	port = p_port
	world = p_world
	profile = p_profile
	faction = port.faction


## One decision: vent, flee, build. `home` is the base; `builders` its idle builders.
## Returns the builder it put to work (so the caller does not order it again), or null.
func decide(home: Vector3, builders: Array[Unit]) -> Unit:
	var eruptions: EruptionSystem = world.planet as EruptionSystem
	if eruptions != null:
		_vent_taps(eruptions)
		_flee(port.vent_dangers())
	return _build(eruptions, home, builders)


func _vent_taps(eruptions: EruptionSystem) -> void:
	if profile.vent_at_pressure <= 0.0:
		return
	var taps: Array[Node3D] = []
	for building: Building in world.buildings_of(faction):
		if building.vent == null or not building.vent.erupts():
			continue
		var pressure: float = eruptions.pressure_of(building.vent)
		var bursting: bool = eruptions.seconds_to_burst(building.vent) < INF
		if (
			(pressure >= profile.vent_at_pressure or bursting)
			and eruptions.can_vent(building) == EruptionSystem.OK
		):
			taps.append(building)
	if not taps.is_empty():
		port.push(VentCommand.new(faction, taps))


func _flee(dangers: Array[Vector4]) -> void:
	if dangers.is_empty():
		return
	var now: int = port.now()
	for danger: Vector4 in dangers:
		if danger.w > profile.vent_flee_seconds:
			continue
		var centre: Vector2 = Vector2(danger.x, danger.y)
		var reach: float = danger.z + CLEARANCE * 0.5
		for unit: Unit in world.units_of(faction):
			if unit.is_dead or unit.orders == null:
				continue
			var there: Vector3 = unit.sim_position()
			var offset: Vector2 = Vector2(there.x, there.z) - centre
			if offset.length() > reach:
				continue
			if now - _fled.get(unit.entity_id, -REORDER_TICKS) < REORDER_TICKS:
				continue
			_fled[unit.entity_id] = now
			var away: Vector2 = offset.normalized() if offset.length() > 0.1 else Vector2.RIGHT
			var out: Vector2 = centre + away * (danger.z + CLEARANCE)
			var goal: Vector3 = world.paths.closest_point(Vector3(out.x, there.y, out.y))
			port.push(
				MoveCommand.new(MoveCommand.KIND_MOVE, faction, [unit] as Array[Node3D], goal)
			)


func _build(eruptions: EruptionSystem, home: Vector3, builders: Array[Unit]) -> Unit:
	var def: BuildingDef = profile.extractor
	if def == null or profile.extractors_wanted <= 0 or builders.is_empty():
		return null
	if FactionPerks.of(world.perks, faction).is_locked(def.id):
		return null
	var have: int = 0
	for building: Building in world.buildings_of(faction):
		if building.def == def:
			have += 1
	if have >= profile.extractors_wanted:
		return null
	if world.economy.stockpile(faction).alloy < def.cost_alloy:
		return null
	var best: ResourceNode = null
	var best_distance: float = profile.deposit_radius * HOME_SHARE
	for node: ResourceNode in world.resource_nodes:
		if not node.is_free_vent() or not _explored(node.position):
			continue
		if _tried.get(node.get_instance_id(), -1) > port.now():
			continue
		if (
			eruptions != null
			and node.erupts()
			and eruptions.pressure_of(node) >= BUILD_MAX_PRESSURE
		):
			continue
		var distance: float = AiGroup.flat_distance(node.position, home)
		if distance < best_distance:
			best = node
			best_distance = distance
	if best == null:
		return null
	var builder: Unit = builders[0]
	_tried[best.get_instance_id()] = port.now() + RETRY_TICKS
	port.push(PlaceBuildingCommand.new(faction, [builder] as Array[Node3D], def, best.position))
	return builder


func _explored(at: Vector3) -> bool:
	return world.vision == null or world.vision.grid.is_explored(faction, at)
