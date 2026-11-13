class_name WorldAiPort
extends AiPort
## AiPort on a live mission: commands go into the mission's CommandQueue and sight
## comes from Combat's per-faction visibility query (the faction's vision grid).
## Custodians are left out of what it reports.

## Spacing of the samples along a straight way checked for deep water, in metres.
const DEEP_SAMPLE: float = 3.0

var context: MissionContext
var world: SimWorld


func _init(p_context: MissionContext, p_world: SimWorld, p_faction: int) -> void:
	context = p_context
	world = p_world
	faction = p_faction


func now() -> int:
	return context.sim_clock.get_tick()


func push(command: Command) -> void:
	assert(command.issuer_faction == faction, "The AI only gives orders to its own faction")
	commands_pushed += 1
	context.command_queue.push(command)


func seen_enemies(center: Vector3, radius: float) -> Array[Node3D]:
	if world.combat == null:
		return []
	# The Custodians are not the commander's business: it plays against the player.
	var seen: Array[Node3D] = []
	for entity: Node3D in world.combat.seen_enemies_near(faction, center, radius):
		if not Factions.is_custodian(Combat.faction_of(entity)):
			seen.append(entity)
	return seen


func alert_level() -> StringName:
	if world.stealth == null:
		return StealthSystem.LEVEL_UNAWARE
	return world.stealth.alert_level(faction)


func alert_position() -> Vector3:
	if world.stealth == null:
		return Vector3.INF
	return world.stealth.alert_position(faction)


func storm_intensity() -> float:
	return world.conditions.storm_intensity


func storm_eta_seconds() -> float:
	return world.conditions.storm_eta_seconds


func storm_is_final() -> bool:
	return world.conditions.storm_is_final


## Sites on the orbital scan (charted for everyone) that nobody resolved yet.
func open_sites() -> Array[Node3D]:
	var found: Array[Node3D] = []
	if world.discovery == null:
		return found
	for site: DiscoverySite in world.discovery.sites:
		if site.can_be_scanned():
			found.append(site)
	return found


func tide_level() -> float:
	return world.conditions.tide_level


func shallows_close_seconds() -> float:
	return world.conditions.shallows_close_seconds


func dry_crossing(from: Vector3, to: Vector3) -> Vector3:
	var conditions: WorldConditions = world.conditions
	if world.dry_crossings.is_empty() or not conditions.has_sea() or world.heights == null:
		return Vector3.INF
	if not _crosses_deep_water(from, to, conditions.low_water):
		return Vector3.INF
	var best: Vector3 = Vector3.INF
	var best_length: float = INF
	for crossing: Vector3 in world.dry_crossings:
		var length: float = from.distance_to(crossing) + crossing.distance_to(to)
		if length < best_length:
			best = crossing
			best_length = length
	return best


func vent_dangers() -> Array[Vector4]:
	var eruptions: EruptionSystem = world.planet as EruptionSystem
	if eruptions == null:
		return []
	return eruptions.dangers()


func known_cargo() -> Array[Prop]:
	var found: Array[Prop] = []
	for prop: Prop in world.props:
		if not prop.is_carriable():
			continue
		var holder: int = prop.carrier_faction()
		if holder < 0 or holder == faction or world.combat.can_target(faction, prop.carrier):
			found.append(prop)
	return found


## True if the straight way from `from` to `to` crosses ground the sea never leaves.
func _crosses_deep_water(from: Vector3, to: Vector3, low_water: float) -> bool:
	var length: float = Vector2(to.x - from.x, to.z - from.z).length()
	var steps: int = maxi(1, ceili(length / DEEP_SAMPLE))
	for i: int in steps + 1:
		var point: Vector3 = from.lerp(to, float(i) / steps)
		if world.heights.sample(point.x, point.z) < low_water:
			return true
	return false
