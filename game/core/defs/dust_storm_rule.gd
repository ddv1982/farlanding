class_name DustStormRule
extends PlanetRule
## Kessel Reach's rule (PLAN 2.5): periodic dust storms cut vision and ground speed
## for everyone. Storms come on a schedule with some variation, are announced
## `warning_seconds` ahead, build up, hold and die down. The effects scale with the
## storm's intensity (0 clear, 1 full storm); the factors below are the values at full
## strength. Played by `sim/systems/planet/dust_storm_system.gd`.

@export_group("Schedule")
## Seconds from the start of a mission to the first storm (before variation).
@export_range(0.0, 3600.0, 1.0, "suffix:s") var first_storm_seconds: float = 240.0
## Seconds of clear sky between the end of one storm and the start of the next.
@export_range(10.0, 3600.0, 1.0, "suffix:s") var interval_seconds: float = 300.0
## Each wait is shortened or lengthened by up to this much, at random.
@export_range(0.0, 600.0, 1.0, "suffix:s") var interval_variation: float = 60.0
## The storm is announced this long before it starts to build.
@export_range(0.0, 300.0, 1.0, "suffix:s") var warning_seconds: float = 40.0
## Seconds from clear to full strength.
@export_range(1.0, 300.0, 1.0, "suffix:s") var build_seconds: float = 20.0
## Seconds at full strength (before variation).
@export_range(0.0, 600.0, 1.0, "suffix:s") var hold_seconds: float = 50.0
@export_range(0.0, 300.0, 1.0, "suffix:s") var hold_variation: float = 15.0
## Seconds from full strength back to clear.
@export_range(1.0, 300.0, 1.0, "suffix:s") var fade_seconds: float = 25.0
@export_group("Effects at full strength")
## Every vision range (fog of war, targeting) is multiplied by this.
@export_range(0.1, 1.0, 0.05) var vision_factor: float = 0.5
## Ground units' top speed is multiplied by this.
@export_range(0.1, 1.0, 0.05) var ground_speed_factor: float = 0.65
## Hovering units' top speed (they ride above the dust) is multiplied by this.
@export_range(0.1, 1.0, 0.05) var hover_speed_factor: float = 0.85
## Watchers' sight-cone range is multiplied by this (stealth gets easier).
@export_range(0.1, 1.0, 0.05) var sight_factor: float = 0.55
## Weapons reaching further than `long_range_from` lose range ...
@export_range(1.0, 100.0, 0.5, "suffix:m") var long_range_from: float = 18.0
## ... their range is multiplied by this, but never below `long_range_from`.
@export_range(0.1, 1.0, 0.05) var long_range_factor: float = 0.7
