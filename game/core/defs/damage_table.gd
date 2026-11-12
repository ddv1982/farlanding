class_name DamageTable
extends Resource
## How much of a weapon's damage each armour type takes: damage type x armour type
## multipliers (PLAN 2.3). Pairs that are not listed take full damage.

const ARMOUR_LIGHT: StringName = &"light"
const ARMOUR_HEAVY: StringName = &"heavy"
const ARMOUR_STRUCTURE: StringName = &"structure"

## Keyed "<damage type>/<armour type>", e.g. &"light/heavy".
@export var multipliers: Dictionary[StringName, float] = {}


## Multiplier for `damage_type` hitting `armour_type` (1 when not listed).
func multiplier(damage_type: StringName, armour_type: StringName) -> float:
	return multipliers.get(key(damage_type, armour_type), 1.0)


## Damage `amount` of `damage_type` does to `armour_type`.
func apply(amount: float, damage_type: StringName, armour_type: StringName) -> float:
	return amount * multiplier(damage_type, armour_type)


static func key(damage_type: StringName, armour_type: StringName) -> StringName:
	return StringName("%s/%s" % [damage_type, armour_type])
