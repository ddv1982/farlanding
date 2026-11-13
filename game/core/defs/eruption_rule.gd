class_name EruptionRule
extends PlanetRule
## Emberfall's rule (PLAN 2.5): Flux vents are rich but erupt; buildings near them take
## damage. Every erupting vent (a ResourceNodeDef with `erupts`) holds a pressure,
## 0..1, that builds while a Flux Tap draws on it and slowly on its own. When it
## reaches the vent's threshold (drawn per cycle between `threshold_min` and 1) the
## eruption is announced `warning_seconds` ahead, then it bursts: buildings within
## `radius` take `building_damage`, units `unit_damage`, the Tap on it is knocked out
## for `knockout_seconds`, and the pressure is empty and stays put for `quiet_seconds`.
## A Tap's owner can vent it early (`vent_*`): a small controlled burst that hurts only
## the Tap a little and empties the pressure, with a cooldown. A mission script may
## call a surge (every vent inside `surge_area` erupts in turn). Played by
## `sim/systems/planet/eruption_system.gd` (ADR 0015).

@export_group("Pressure")
## Pressure per second while a working Flux Tap draws on the vent (0..1 scale).
@export_range(0.0, 1.0, 0.0005) var tapped_rate: float = 0.011
## Pressure per second on a vent nobody taps.
@export_range(0.0, 1.0, 0.0005) var idle_rate: float = 0.002
## Each cycle a vent erupts at a pressure drawn between this and 1.
@export_range(0.0, 1.0, 0.01) var threshold_min: float = 0.85
## Pressure every vent starts a landing with, drawn between 0 and this.
@export_range(0.0, 1.0, 0.01) var start_pressure_max: float = 0.35
@export_group("Eruption")
## Seconds between the announcement and the burst.
@export_range(1.0, 120.0, 1.0, "suffix:s") var warning_seconds: float = 12.0
## Everything within this many metres of the vent is hit.
@export_range(1.0, 60.0, 0.5, "suffix:m") var radius: float = 12.0
## Damage to each building (and the Tap) within the radius.
@export_range(0.0, 5000.0, 5.0) var building_damage: float = 260.0
## Damage to each unit within the radius.
@export_range(0.0, 1000.0, 1.0) var unit_damage: float = 45.0
## Seconds the Tap on an erupting vent yields nothing.
@export_range(0.0, 600.0, 1.0, "suffix:s") var knockout_seconds: float = 40.0
## Seconds after an eruption before the pressure builds again.
@export_range(0.0, 600.0, 1.0, "suffix:s") var quiet_seconds: float = 30.0
@export_group("Controlled venting")
## A Tap may vent its vent only from this pressure on.
@export_range(0.0, 1.0, 0.01) var vent_min_pressure: float = 0.25
## Damage the Tap takes when vented.
@export_range(0.0, 1000.0, 1.0) var vent_damage: float = 40.0
## Seconds the Tap yields nothing after venting.
@export_range(0.0, 120.0, 1.0, "suffix:s") var vent_stall_seconds: float = 6.0
## Seconds before the same vent can be vented again.
@export_range(0.0, 600.0, 1.0, "suffix:s") var vent_cooldown_seconds: float = 90.0
@export_group("Surge")
## Vents inside this area (world X/Z) erupt in a surge: the caldera plateau.
@export var surge_area: Rect2 = Rect2(-26.0, -22.0, 52.0, 44.0)
## Seconds between two vents of a surge bursting (the first at the surge's tick).
@export_range(0.0, 60.0, 0.5, "suffix:s") var surge_step_seconds: float = 3.0
## A surge is announced (Advisor `surge_incoming`) this long before it starts.
@export_range(0.0, 600.0, 1.0, "suffix:s") var surge_warning_seconds: float = 45.0
@export_group("Alerts")
## Seconds between two Advisor `eruption_warning` alerts.
@export_range(0.0, 600.0, 1.0, "suffix:s") var alert_seconds: float = 25.0
## The player hears about a vent within this distance of something of theirs.
@export_range(0.0, 200.0, 1.0, "suffix:m") var alert_distance: float = 30.0


## Seconds a working Tap takes to fill an empty vent.
func seconds_to_fill_tapped() -> float:
	return 1.0 / tapped_rate if tapped_rate > 0.0 else INF
