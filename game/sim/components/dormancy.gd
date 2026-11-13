class_name Dormancy
extends Node
## Keeps a Custodian unit dormant (PLAN 2.1) until something disturbs it: it neither
## moves nor fires, and no weapon picks it as a target on its own. It wakes when it
## is hit, when a site within its def's `guard_radius` is scanned (SimWorld.disturb),
## or when any unit of another faction comes within `wake_radius`. Awake, it is an
## ordinary armed unit, hostile to everyone near it. It never falls asleep again.

## The unit woke up.
signal woke

const SAVE_VERSION: int = 1
## Sim ticks between looks for intruders.
const LOOK_PERIOD: int = 3

var unit: Unit = null
var is_dormant: bool = true

var _countdown: int = 0


func setup(p_unit: Unit) -> void:
	unit = p_unit
	_countdown = absi(unit.entity_id) % LOOK_PERIOD


## One sim tick while dormant: wakes if an intruder is within reach.
func tick() -> void:
	if not is_dormant or unit == null or unit.world == null or unit.world.combat == null:
		return
	_countdown -= 1
	if _countdown > 0:
		return
	_countdown = LOOK_PERIOD
	var at: Vector3 = unit.sim_position()
	for other: Node3D in unit.world.combat.entities_near(at, unit.def.wake_radius):
		var other_unit: Unit = other as Unit
		if other_unit == null or other_unit.faction == unit.faction or other_unit.is_dead:
			continue
		var there: Vector3 = other_unit.sim_position()
		# A faction may tread more quietly (ADR 0017: the `custodian_disturb` perk).
		var reach: float = unit.def.wake_radius * _disturb_scale(other_unit)
		if Vector2(there.x - at.x, there.z - at.z).length() <= reach:
			wake()
			return


func _disturb_scale(intruder: Unit) -> float:
	if intruder.def == null:
		return 1.0
	return FactionPerks.of(unit.world.perks, intruder.faction).scale(
		intruder.def.id, FactionPerks.CUSTODIAN_DISTURB
	)


func wake() -> void:
	if not is_dormant:
		return
	is_dormant = false
	woke.emit()


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "dormant": is_dormant}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Dormancy save version")
	is_dormant = data.get("dormant", true)
