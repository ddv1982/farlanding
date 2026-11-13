class_name BuildingDef
extends EntityDef
## Data definition for a building. Local coordinates follow the model: forward
## (the door side) is +Z, towards the default camera; the origin is on the ground, 1 unit = 1 m.

@export_range(1, 100000, 1) var max_health: int = 1000
## Ground area the building blocks, in local X/Z (x, z, width, depth).
@export var footprint: Rect2 = Rect2(-4.0, -4.0, 8.0, 8.0)
## Height of the body, used for click picking.
@export_range(0.5, 60.0, 0.1, "suffix:m") var height: float = 6.0
## False for buildings that cannot be placed by a builder (the Lander).
@export var placeable: bool = true
## The bare model, shown as the placement preview.
@export var model: PackedScene
@export_group("Combat")
## Column of the DamageTable (buildings are &"structure").
@export var armour_type: StringName = &"structure"
## How far the building sees, in metres (fog of war).
@export_range(0.0, 200.0, 0.5, "suffix:m") var vision_range: float = 14.0
## A defence weapon (Sentry), or null. It fires only while the building is powered.
@export var weapon: WeaponDef = null
@export_group("Power")
## Power capacity this building adds once operational.
@export_range(0, 1000, 1) var power_output: int = 0
## Power this building draws once operational.
@export_range(0, 1000, 1) var power_use: int = 0
@export_group("Production")
## Unit types this building can produce, in button order.
@export var produces: Array[UnitDef] = []
## Most units waiting in the production queue (including the one in progress).
@export_range(1, 20, 1) var queue_limit: int = 5
## Units given for free when construction completes (e.g. a Refinery's Hauler).
@export var free_units: Array[UnitDef] = []
## Where produced units appear, in local coordinates (just outside the door).
@export var door: Vector3 = Vector3(0.0, 0.0, 6.0)
@export_group("Economy")
## Haulers unload Alloy here.
@export var accepts_alloy: bool = false
## Where haulers unload, in local coordinates (outside the footprint).
@export var dock: Vector3 = Vector3(0.0, 0.0, 6.0)
## Haulers unload at the nearest drop-off of the highest priority (a Refinery beats
## the Lander, which only stands in until a Refinery exists).
@export_range(0, 10, 1) var dropoff_priority: int = 1
## Resource kind this building must stand on (&"flux" for a Flux Tap), or &"" for none.
@export var requires_resource: StringName = &""
## Flux added every `flux_interval` seconds of work.
@export_range(0, 1000, 1) var flux_amount: int = 0
@export_range(0.1, 120.0, 0.1, "suffix:s") var flux_interval: float = 4.0
## What the tapped Flux is banked as: &"flux", or &"alloy" (the Combine's Siphon burns
## vent Flux into Alloy, the only resource it spends).
@export var flux_banked_as: StringName = &"flux"
@export_group("Antecedent")
## An Antecedent machine (Hollow Meridian's engines, ADR 0017): it stands on the map
## from the start, belongs to nobody (the Custodians) until a faction reactivates it,
## can be taken over and shut down but never destroyed. Its `power_output` goes to
## whoever runs it.
@export var machine: bool = false
@export_group("Survey")
## Field options this building offers once operational (FieldOptionDefs).
@export var field_options: Array[FieldOptionDef] = []


## True if this building can produce units.
func is_producer() -> bool:
	return not produces.is_empty()


## Footprint on the ground for a building standing at `at` (buildings are not rotated).
func world_footprint(at: Vector3) -> Rect2:
	return Rect2(footprint.position + Vector2(at.x, at.z), footprint.size)


## Radius of a circle around the origin that holds the whole footprint.
func footprint_radius() -> float:
	var corner: Vector2 = footprint.position.abs().max(footprint.end.abs())
	return corner.length()
