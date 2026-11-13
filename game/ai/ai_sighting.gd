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
## A flying unit (ADR 0016).
var airborne: bool = false
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
		airborne = unit.def.flies
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


func to_dict() -> Dictionary:
	return {
		"entity": Order.entity_id_of(entity()),
		"building": is_building,
		"def": String(def_id),
		"position": var_to_str(position),
		"footprint": var_to_str(footprint),
		"strength": strength,
		"armed": armed,
		"heavy": heavy,
		"airborne": airborne,
		"seen": last_seen_tick,
	}


## Restores a saved sighting; `found` is its entity if it still exists (or null).
func from_dict(data: Dictionary, found: Node3D) -> void:
	is_building = data.get("building", false)
	var saved_def: String = data.get("def", "")
	def_id = StringName(saved_def)
	var position_text: String = data.get("position", "Vector3(0, 0, 0)")
	position = str_to_var(position_text)
	var footprint_text: String = data.get("footprint", "Rect2(0, 0, 0, 0)")
	footprint = str_to_var(footprint_text)
	strength = data.get("strength", 0.0)
	armed = data.get("armed", false)
	heavy = data.get("heavy", false)
	airborne = data.get("airborne", false)
	last_seen_tick = data.get("seen", 0)
	_ref = weakref(found) if found != null else null
