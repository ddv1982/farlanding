class_name EconomyRules
extends Resource
## Tuning numbers for the base-and-economy rules of one mission. One `.tres` per rule set.

@export_group("Start")
@export_range(0, 100000, 1) var start_alloy: int = 600
@export_range(0, 100000, 1) var start_flux: int = 100
@export_group("Power")
## Speed of construction, production and Flux tapping while power used exceeds
## power produced (1 = no slowdown).
@export_range(0.05, 1.0, 0.05) var low_power_rate: float = 0.5
@export_group("Production")
## Share of the cost returned when a queued unit is cancelled.
@export_range(0.0, 1.0, 0.05) var cancel_refund: float = 1.0
@export_group("Placement")
## Free space kept between building footprints, in metres.
@export_range(0.0, 10.0, 0.1, "suffix:m") var building_gap: float = 1.0
## Steepest average ground slope a building may stand on.
@export_range(0.0, 45.0, 0.5, "suffix:°") var max_slope: float = 12.0
## A Flux Tap snaps onto a free vent whose centre is this close to the cursor.
@export_range(0.0, 20.0, 0.5, "suffix:m") var vent_snap_distance: float = 6.0
@export_group("Harvesting")
## A Hauler whose deposit runs out looks this far (from that deposit) for another.
@export_range(0.0, 500.0, 1.0, "suffix:m") var deposit_search_radius: float = 70.0
