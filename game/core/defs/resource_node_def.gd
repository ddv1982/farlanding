class_name ResourceNodeDef
extends EntityDef
## Data definition for a resource node on the map: an Alloy deposit or a Flux vent.

## &"alloy" (mined by Haulers) or &"flux" (tapped by a Flux Tap).
@export var resource: StringName = &"alloy"
## Units of resource it holds; 0 means it never runs out.
@export_range(0, 1000000, 1) var amount: int = 1500
## Radius of the node on the ground, in metres.
@export_range(0.5, 30.0, 0.1, "suffix:m") var radius: float = 3.0
## Height used for click picking.
@export_range(0.1, 20.0, 0.1, "suffix:m") var height: float = 2.0
## Units path around it (deposits); vents are walkable until a tap is built on them.
@export var blocks_movement: bool = true
## Vents: a Flux Tap on this vent yields this many times faster (Emberfall's rich vents).
@export_range(0.1, 10.0, 0.05) var flux_rate_scale: float = 1.0
## Vents: the planet's eruption rule builds pressure in it and it erupts (ADR 0015).
@export var erupts: bool = false
