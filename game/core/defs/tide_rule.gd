class_name TideRule
extends PlanetRule
## Thalassa Low's rule (PLAN 2.5): the tide floods lowlands on a timer, opening and
## closing routes. The sea holds at low water, rises to high water, holds, falls and
## holds again, each turn announced `warning_seconds` ahead. Ground deeper than
## `wading_depth` under the sea is closed to ground units (hovering units cross it);
## units the sea catches wade out slowly and take light damage. Played by
## `sim/systems/planet/tide_system.gd` (ADR 0014).

@export_group("Sea levels")
## Sea level at low and at high water, in metres (the terrain recipe's numbers).
@export_range(-10.0, 10.0, 0.05, "suffix:m") var low_water: float = -1.3
@export_range(-10.0, 10.0, 0.05, "suffix:m") var high_water: float = 0.15
## Ground units walk through water up to this deep; deeper ground is closed.
@export_range(0.0, 2.0, 0.05, "suffix:m") var wading_depth: float = 0.25
@export_group("Schedule")
## Seconds from the start of a mission until the first rise begins (before variation).
@export_range(0.0, 3600.0, 1.0, "suffix:s") var first_rise_seconds: float = 210.0
## Seconds the sea holds at low water between a fall and the next rise.
@export_range(1.0, 3600.0, 1.0, "suffix:s") var low_hold_seconds: float = 150.0
## Seconds the sea takes to rise from low to high water.
@export_range(1.0, 600.0, 1.0, "suffix:s") var rise_seconds: float = 45.0
## Seconds the sea holds at high water.
@export_range(1.0, 3600.0, 1.0, "suffix:s") var high_hold_seconds: float = 100.0
## Seconds the sea takes to fall from high to low water.
@export_range(1.0, 600.0, 1.0, "suffix:s") var fall_seconds: float = 45.0
## Each hold is shortened or lengthened by up to this much, at random.
@export_range(0.0, 600.0, 1.0, "suffix:s") var hold_variation: float = 20.0
## Every turn (rise or fall) is announced this long before it starts.
@export_range(0.0, 300.0, 1.0, "suffix:s") var warning_seconds: float = 30.0
@export_group("Units caught by the sea")
## Top speed of a ground unit in water deeper than `wading_depth` is multiplied by this.
@export_range(0.05, 1.0, 0.05) var wading_speed_factor: float = 0.35
## Damage per second to a ground unit in water deeper than `wading_depth`.
@export_range(0.0, 100.0, 0.5) var wading_damage_per_second: float = 2.0


## Seconds of one full cycle (low hold, rise, high hold, fall) before variation.
func period_seconds() -> float:
	return low_hold_seconds + rise_seconds + high_hold_seconds + fall_seconds


## The sea's height for a tide level `t` (0 = low water, 1 = high water).
func sea_level(t: float) -> float:
	return lerpf(low_water, high_water, clampf(t, 0.0, 1.0))
