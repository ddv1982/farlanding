class_name MoveCommand
extends Command
## Move a group to a ground point. The group arrives in a Formation
## facing its direction of travel. With `queued`, the move is appended as a waypoint
## after each unit's current orders.

const KIND_MOVE: StringName = &"move"


func _init(
	p_kind: StringName = KIND_MOVE,
	p_issuer_faction: int = 0,
	p_entities: Array[Node3D] = [],
	p_target: Vector3 = Vector3.ZERO,
	p_queued: bool = false,
) -> void:
	assert(p_kind == KIND_MOVE, "Not a move kind: %s" % p_kind)
	super(p_kind, p_issuer_faction, p_entities)
	target_position = p_target
	queued = p_queued


func execute() -> void:
	var units: Array[Unit] = []
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if unit != null and unit.orders != null and unit.faction == issuer_faction:
			units.append(unit)
	if units.is_empty():
		return
	var starts: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var centroid: Vector3 = Vector3.ZERO
	for unit: Unit in units:
		var start: Vector3 = unit.global_position
		if unit.locomotion != null:
			start = unit.locomotion.mover.position
		if queued:
			start = unit.orders.last_destination(start)
		starts.append(start)
		centroid += start
		radii.append(unit.def.radius if unit.def != null else 0.5)
	centroid /= float(units.size())
	var heading: Vector3 = target_position - centroid
	if Vector2(heading.x, heading.z).length() < 0.5:
		heading = Mover.forward_for(
			units[0].locomotion.mover.yaw if units[0].locomotion != null else 0.0
		)
	var walkable: Callable = Callable()
	if units[0].locomotion != null:
		# The sea is ignored here (a tidal map, ADR 0014): a slot on flooded ground
		# stays where it was asked for, and the unit waits on the shore for low water.
		walkable = units[0].locomotion.paths.for_hover().is_walkable
	var formation: Formation = Formation.new(
		units.size(), target_position, heading, Formation.spacing_for(radii), walkable
	)
	var slot_of: PackedInt32Array = formation.assign(starts)
	var orders: Array[Order] = []
	for i: int in units.size():
		orders.append(Order.new(kind, formation.slots[slot_of[i]]))
	_plan_group_paths(units, orders)
	for i: int in units.size():
		units[i].orders.give(orders[i], queued)


## Units that start this order now share one group path request (one per path
## service: hovering units path across flooded shallows); queued orders ask for their
## own path when they start.
func _plan_group_paths(units: Array[Unit], orders: Array[Order]) -> void:
	var by_service: Dictionary[PathService, Array] = {}
	for i: int in units.size():
		if units[i].locomotion != null and (not queued or units[i].orders.is_idle()):
			var service: PathService = units[i].locomotion.paths
			if not by_service.has(service):
				by_service[service] = []
			by_service[service].append(i)
	for service: PathService in by_service:
		var now: Array = by_service[service]
		var starts: PackedVector3Array = PackedVector3Array()
		var goals: PackedVector3Array = PackedVector3Array()
		for index: Variant in now:
			var i: int = index
			starts.append(units[i].locomotion.mover.position)
			goals.append(orders[i].target_position)
		var paths: Array[PackedVector3Array] = service.find_group_paths(starts, goals)
		for k: int in now.size():
			var i: int = now[k]
			orders[i].path = paths[k]
