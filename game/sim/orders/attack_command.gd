class_name AttackCommand
extends Command
## Attack one enemy unit or building the issuing faction can see. Each armed
## receiver closes to just inside its weapon range (from a building's edge) and fires
## until the target dies; the group spreads in an arc on the side it approaches from.
## Unarmed receivers only walk up to `ENGAGE_RANGE` from it. With `queued`, the attack
## runs after each unit's current orders.

const KIND: StringName = &"attack"
## Where unarmed units stop, and the engagement distance of units without a range.
const ENGAGE_RANGE: float = 10.0


func _init(
	p_issuer_faction: int = 0,
	p_entities: Array[Node3D] = [],
	p_target: Node3D = null,
	p_queued: bool = false,
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	target_entity = p_target
	queued = p_queued


## True when `target` may be attacked by `faction`: a live unit or building of
## another faction.
static func is_valid_target(target: Variant, faction: int) -> bool:
	if not is_instance_valid(target):
		return false
	if target is Unit:
		var unit: Unit = target
		return unit.is_inside_tree() and unit.faction != faction and not unit.is_dead
	if target is Building:
		var building: Building = target
		return building.is_inside_tree() and building.faction != faction and not building.is_dead
	return false


## How far the target's body reaches from its origin: a building's footprint.
static func body_radius(target: Node3D) -> float:
	var building: Building = target as Building
	if building != null and building.def != null:
		return building.def.footprint_radius()
	return 0.0


## Simulation position of an entity (the mover's, which leads the drawn node).
static func position_of(entity: Node3D) -> Vector3:
	var unit: Unit = entity as Unit
	if unit != null and unit.locomotion != null:
		return unit.locomotion.mover.position
	return entity.global_position


## Offsets from the target, one per start, each `engage_range` long. Units take
## neighbouring slots `spacing` apart on an arc centred on the side the group comes
## from, keeping their left-to-right order so paths do not cross.
static func engage_offsets(
	target: Vector3, starts: PackedVector3Array, engage_range: float, spacing: float
) -> PackedVector3Array:
	var count: int = starts.size()
	var offsets: PackedVector3Array = PackedVector3Array()
	offsets.resize(count)
	if count == 0:
		return offsets
	var centroid: Vector3 = Vector3.ZERO
	for start: Vector3 in starts:
		centroid += start
	centroid /= float(count)
	var base: Vector3 = Vector3(centroid.x - target.x, 0.0, centroid.z - target.z)
	var base_angle: float = atan2(base.x, base.z) if base.length_squared() > 1e-4 else 0.0
	var relative: Array[float] = []
	var order: Array[int] = []
	for i: int in count:
		var to_start: Vector3 = starts[i] - target
		var angle: float = atan2(to_start.x, to_start.z)
		relative.append(
			angle_difference(base_angle, angle) if base.length_squared() > 1e-4 else 0.0
		)
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return relative[a] < relative[b])
	var step: float = minf(spacing / maxf(engage_range, 0.1), TAU / count)
	for k: int in count:
		var angle: float = base_angle + (k - (count - 1) * 0.5) * step
		offsets[order[k]] = Vector3(sin(angle), 0.0, cos(angle)) * engage_range
	return offsets


func execute() -> void:
	if not is_valid_target(target_entity, issuer_faction):
		return
	var world: SimWorld = PlaceBuildingCommand.world_of(entities)
	if (
		world != null
		and world.combat != null
		and not world.combat.can_target(issuer_faction, target_entity)
	):
		return
	var units: Array[Unit] = []
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if (
			unit != null
			and unit != target_entity
			and unit.orders != null
			and unit.faction == issuer_faction
		):
			units.append(unit)
	if units.is_empty():
		return
	target_position = position_of(target_entity)
	var starts: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var ranges: PackedFloat32Array = PackedFloat32Array()
	var widest: float = 0.0
	var body: float = body_radius(target_entity)
	for unit: Unit in units:
		var start: Vector3 = position_of(unit)
		if queued:
			start = unit.orders.last_destination(start)
		starts.append(start)
		radii.append(unit.def.radius if unit.def != null else 0.5)
		var reach: float = unit.orders.engage_distance if unit.weapon != null else ENGAGE_RANGE
		ranges.append(reach + body)
		widest = maxf(widest, reach + body)
	var offsets: PackedVector3Array = engage_offsets(
		target_position, starts, widest, Formation.spacing_for(radii)
	)
	for i: int in units.size():
		var offset: Vector3 = offsets[i].normalized() * ranges[i]
		if units[i].weapon == null:
			units[i].orders.give(Order.new(MoveCommand.KIND_MOVE, target_position + offset), queued)
			continue
		var order: Order = Order.new(kind, target_position)
		order.target_entity = target_entity
		order.engage_offset = offset
		units[i].orders.give(order, queued)
