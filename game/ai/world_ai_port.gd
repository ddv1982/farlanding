class_name WorldAiPort
extends AiPort
## AiPort on a live mission: commands go into the mission's CommandQueue and sight
## comes from Combat's per-faction visibility query (the faction's vision grid).

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
	return world.combat.seen_enemies_near(faction, center, radius)
