class_name WorldAiPort
extends AiPort
## AiPort on a live mission: commands go into the mission's CommandQueue and sight
## comes from Combat's per-faction visibility query (the faction's vision grid).
## Custodians are left out of what it reports.

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
