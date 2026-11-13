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
## Rides above the ground on lift (skimmers, drones): dust storms slow it less.
@export var hovers: bool = false
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
@export_group("Scanner")
## Scan seconds done per second next to a discovery site; 0 = cannot scan.
@export_range(0.0, 10.0, 0.05) var scan_rate: float = 0.0
## How close to a site's edge the unit scans from, in metres.
@export_range(0.5, 40.0, 0.5, "suffix:m") var scan_range: float = 6.0
@export_group("Stealth")
## How easily the unit is noticed, 0..1. At 1 it is seen like anything else on its
## enemies' vision grid; below 1 a watcher notices it only inside its sight cone,
## within `sight range × signature`, and only after its suspicion has built up.
@export_range(0.0, 1.0, 0.01) var signature: float = 1.0
## How well the unit notices low-signature intruders (scales its suspicion rate);
## 0 = it never notices them.
@export_range(0.0, 4.0, 0.05) var sensor: float = 1.0
## Full width of the sight cone it notices low-signature units in, in degrees
## (360 = all around). Its range is `vision_range`.
@export_range(10.0, 360.0, 5.0, "suffix:°") var sight_angle: float = 360.0
## The unit cloaks while it holds still or creeps (see `cloak_max_speed`).
@export var can_cloak: bool = false
## Signature while cloaked.
@export_range(0.0, 1.0, 0.01) var cloak_signature: float = 0.15
## Top speed while in stealth mode; it stays cloaked at or below it.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var cloak_max_speed: float = 2.6
## Seconds of holding still or creeping before the cloak closes.
@export_range(0.0, 20.0, 0.1, "suffix:s") var cloak_delay: float = 1.2
@export_group("Saboteur")
## Seconds next to an enemy building to sabotage it; 0 = cannot sabotage.
@export_range(0.0, 120.0, 0.5, "suffix:s") var sabotage_time: float = 0.0
## How close to a footprint's edge it works from.
@export_range(0.5, 20.0, 0.5, "suffix:m") var sabotage_range: float = 2.0
@export_group("Custodian")
## Starts dormant: it neither moves nor fires, and nothing aims at it on its own,
## until disturbed (hit, a site near it scanned, or anything comes within
## `wake_radius`).
@export var starts_dormant: bool = false
@export_range(0.0, 100.0, 0.5, "suffix:m") var wake_radius: float = 7.0
## A site scanned within this distance wakes it.
@export_range(0.0, 200.0, 0.5, "suffix:m") var guard_radius: float = 30.0


## True if this unit can construct buildings.
func can_build() -> bool:
	return build_rate > 0.0 and not builds.is_empty()


## True if this unit can scan discovery sites.
func can_scan() -> bool:
	return scan_rate > 0.0


## True if this unit can sabotage enemy buildings.
func can_sabotage() -> bool:
	return sabotage_time > 0.0


## True if this unit can harvest Alloy.
func can_harvest() -> bool:
	return carry_capacity > 0


## The armour combat uses: `armour_type`, or light when it is not stated.
func armour() -> StringName:
	return armour_type if armour_type != &"" else DamageTable.ARMOUR_LIGHT


## True if this unit carries a weapon.
func is_armed() -> bool:
	return weapon != null
