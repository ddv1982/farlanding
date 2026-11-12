class_name UnitDef
extends EntityDef
## Data definition for a mobile unit. Distances in metres, speeds per second.

@export_range(1, 100000, 1) var max_health: int = 100
@export_range(0.0, 100.0, 0.1, "suffix:m/s") var move_speed: float = 5.0
@export_range(0.0, 1440.0, 1.0, "suffix:°/s") var turn_speed: float = 360.0
@export_range(0.0, 200.0, 0.5, "suffix:m") var vision_range: float = 20.0
## Body radius for avoidance, formation spacing and click picking.
@export_range(0.1, 20.0, 0.05, "suffix:m") var radius: float = 0.5
## Also used for braking.
@export_range(0.1, 200.0, 0.1, "suffix:m/s²") var acceleration: float = 10.0
@export_group("Combat")
## Column of the DamageTable: &"light" or &"heavy". Empty = not stated (taken as
## light by combat; audio then guesses the weight class from the unit).
@export var armour_type: StringName = &""
## The unit's gun, or null for an unarmed unit (it only moves near an attack target).
@export var weapon: WeaponDef = null
@export_group("Builder")
## Buildings this unit can construct (shown in its build menu): BuildingDefs, typed
## as EntityDef because BuildingDef already refers to UnitDef (a cycle between the
## two scripts would leak them at exit).
@export var builds: Array[EntityDef] = []
## Construction seconds added per second of work at full power; 0 = cannot build.
@export_range(0.0, 10.0, 0.05) var build_rate: float = 0.0
## How close to a footprint's edge a builder works from, in metres.
@export_range(0.5, 20.0, 0.1, "suffix:m") var work_range: float = 3.0
@export_group("Harvester")
## Alloy carried per trip; 0 = cannot harvest.
@export_range(0, 10000, 1) var carry_capacity: int = 0
## Seconds spent mining one load at a deposit.
@export_range(0.1, 120.0, 0.1, "suffix:s") var mine_time: float = 4.0
## Seconds spent unloading at a refinery dock.
@export_range(0.1, 120.0, 0.1, "suffix:s") var unload_time: float = 1.5


## True if this unit can construct buildings.
func can_build() -> bool:
	return build_rate > 0.0 and not builds.is_empty()


## True if this unit can harvest Alloy.
func can_harvest() -> bool:
	return carry_capacity > 0


## The armour combat uses: `armour_type`, or light when it is not stated.
func armour() -> StringName:
	return armour_type if armour_type != &"" else DamageTable.ARMOUR_LIGHT


## True if this unit carries a weapon.
func is_armed() -> bool:
	return weapon != null
