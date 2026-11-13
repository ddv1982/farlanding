class_name MachineryRule
extends PlanetRule
## Hollow Meridian's rule (PLAN 2.5): Custodians everywhere; power comes from
## reactivating old machinery. Antecedent engines (the map's `machine` buildings) stand
## dormant, held by nobody. A unit that can build or scan reactivates one by working
## next to it for `reactivate_seconds` (an order, interrupted by anything that ends it);
## from then on the engine adds its power to that faction. An enemy can take a running
## engine over the same way in `takeover_seconds`. An engine whose health runs out
## shuts down for `shutdown_seconds` (no power, nobody can shoot it, anybody but its
## owner may claim it in `reactivate_seconds`) and restarts at full health; it is never
## destroyed. Starting work on an engine wakes the dormant Custodians within
## `disturb_radius`, and they go for the worker. Reactors cannot be built here, and the
## headquarters give only `headquarters_power_scale` of their power. Played by
## `sim/systems/planet/machinery_system.gd` (ADR 0017).

@export_group("Reactivation")
## Seconds one worker needs to bring a dormant engine back (several add up).
@export_range(1.0, 120.0, 0.5, "suffix:s") var reactivate_seconds: float = 12.0
## Seconds one worker needs to take an engine running for another faction over.
@export_range(1.0, 240.0, 0.5, "suffix:s") var takeover_seconds: float = 24.0
## Progress lost per second while nobody works on an engine (0..1 scale).
@export_range(0.0, 1.0, 0.01) var progress_decay: float = 0.05
## A worker must stand within this many metres of the engine's footprint.
@export_range(0.5, 20.0, 0.5, "suffix:m") var work_range: float = 3.0
@export_group("Shutdown")
## Seconds an engine stays shut down once its health ran out.
@export_range(1.0, 600.0, 1.0, "suffix:s") var shutdown_seconds: float = 45.0
@export_group("Custodians")
## Dormant Custodians within this many metres of an engine wake when work on it starts.
@export_range(0.0, 200.0, 1.0, "suffix:m") var disturb_radius: float = 32.0
## Woken Custodians chase the worker at most this far from where they stood.
@export_range(0.0, 200.0, 1.0, "suffix:m") var chase_distance: float = 40.0
@export_group("Power")
## Building types nobody may place on this planet (the Reactor: power is the engines').
@export var locked_buildings: Array[StringName] = [&"concord_reactor"]
## Share of their power the headquarters (and anything else that is not a machine)
## still give.
@export_range(0.0, 1.0, 0.05) var headquarters_power_scale: float = 0.5
@export_group("Alerts")
## The player hears `machine_lost` at most this often.
@export_range(0.0, 120.0, 1.0, "suffix:s") var alert_seconds: float = 10.0
