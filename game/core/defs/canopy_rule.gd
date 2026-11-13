class_name CanopyRule
extends PlanetRule
## Verdance's rule (PLAN 2.5): canopy hides ground units from the air and from
## long-range sight. The crowns are the map's `canopy_zones` (MapDef). A ground unit
## (or a building) standing under one is seen by an enemy only while a ground unit or
## building of that enemy is within `close_sight` of it (the faction's perks may widen
## that), never by a flying unit, and for `fire_reveal_seconds` after it fired. Under a
## crown a unit sees out as usual: the cover is an ambush. Air units cannot target it.
## Played by `sim/systems/planet/canopy_system.gd` (ADR 0016).

## An enemy ground observer this close sees a unit under a crown, in metres.
@export_range(0.0, 60.0, 0.5, "suffix:m") var close_sight: float = 9.0
## A unit or building under a crown that fires is seen by everyone this long.
@export_range(0.0, 60.0, 0.5, "suffix:s") var fire_reveal_seconds: float = 4.0
## Buildings under a crown are hidden the same way (until something comes close or
## they fire).
@export var hides_buildings: bool = true
