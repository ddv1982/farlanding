class_name PlaceBuildingCommand
extends Command
## Place a construction site of `building_def` at `target_position` and send the
## receivers (builders) to build it. The cost is paid when the site is placed; a spot
## that became invalid or a cost that can no longer be paid places nothing. With
## `queued`, builders start after their current orders.

const KIND: StringName = &"place_building"

var building_def: BuildingDef
## The site created when the command ran, or null.
var placed: Building = null


func _init(
	p_issuer_faction: int = 0,
	p_entities: Array[Node3D] = [],
	p_def: BuildingDef = null,
	p_position: Vector3 = Vector3.ZERO,
	p_queued: bool = false,
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	building_def = p_def
	target_position = p_position
	queued = p_queued


func execute() -> void:
	var world: SimWorld = world_of(entities)
	if world == null or building_def == null:
		return
	var is_player: bool = issuer_faction == world.player_faction
	if world.placement_rules().check(building_def, target_position) != PlacementRules.OK:
		if is_player:
			Events.ui_feedback.emit(&"placement_invalid")
		return
	if not world.economy.pay(issuer_faction, building_def):
		if is_player:
			Events.ui_feedback.emit(&"not_enough_resources")
		return
	placed = world.spawn_building(building_def, issuer_faction, target_position, false)
	Events.building_placed.emit(placed)
	if is_player:
		Events.advisor_alert.emit(&"building_placed")
	BuildCommand.give_build_orders(entities, issuer_faction, placed, queued)


## The world of the first receiver that knows it, or null.
static func world_of(receivers: Array[Node3D]) -> SimWorld:
	for entity: Node3D in receivers:
		var value: Variant = entity.get(&"world")
		if value is SimWorld:
			var world: SimWorld = value
			return world
	return null
