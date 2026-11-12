class_name AiSighting
extends RefCounted
## One enemy unit or building the commander's faction has seen: what it was, where,
## how strong, and when it was last in sight. The live node is only held weakly and
## is used to aim an order at it while it is in sight; knowledge itself comes from
## what was seen.

var key: int = 0
var is_building: bool = false
var def_id: StringName = &""
var position: Vector3 = Vector3.ZERO
## Buildings: the ground they cover (world X/Z).
var footprint: Rect2 = Rect2()
## Fighting value (see AiKnowledge.strength_of).
var strength: float = 0.0
var armed: bool = false
var heavy: bool = false
var last_seen_tick: int = 0

var _ref: WeakRef = null


## Records a fresh look at `entity` on sim tick `now`.
func update(entity: Node3D, now: int) -> void:
	key = entity.get_instance_id()
	_ref = weakref(entity)
	position = AttackCommand.position_of(entity)
	strength = AiKnowledge.strength_of(entity)
	armed = Combat.is_armed(entity)
	last_seen_tick = now
	var unit: Unit = entity as Unit
	if unit != null and unit.def != null:
		def_id = unit.def.id
		heavy = unit.def.armour() == DamageTable.ARMOUR_HEAVY
	var building: Building = entity as Building
	if building != null:
		is_building = true
		footprint = building.footprint()
		if building.def != null:
			def_id = building.def.id


## The live node, or null once it has been freed.
func entity() -> Node3D:
	if _ref == null:
		return null
	var value: Variant = _ref.get_ref()
	if value == null or not is_instance_valid(value):
		return null
	var node: Node3D = value
	return node


## Sim ticks since it was last seen.
func age(now: int) -> int:
	return now - last_seen_tick
