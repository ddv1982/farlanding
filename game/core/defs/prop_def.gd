class_name PropDef
extends EntityDef
## Map dressing that matters (ADR 0011): crates, wall segments, tanks, boulders. It
## blocks movement like a building (its footprint is cut out of the navmesh) and,
## when `blocks_sight` is set, blocks line of sight for the vision grid and for
## watchers' sight cones, so it makes honest cover. Never selectable, never a target
## of its own; with health it can be destroyed (splash damage, or an attack order).

## Prop dimensions in metres: width (X), height (Y), depth (Z) before turning.
@export var size: Vector3 = Vector3(2.0, 2.0, 2.0)
## Cut out of the navmesh (units walk round it).
@export var blocks_movement: bool = true
## Hides what is behind it from vision and sight cones. Only honoured from
## Prop.MIN_SIGHT_HEIGHT up: a knee-high prop never hides anything.
@export var blocks_sight: bool = true
## Hit points; 0 = indestructible.
@export_range(0, 100000, 1) var max_health: int = 0
## Column of the DamageTable it is hit on.
@export var armour_type: StringName = &"heavy"
## The prop's look (a model scene). Null or missing shows a placeholder box.
@export var model: PackedScene
## A unit can pick it up and carry it (an Antecedent artefact, ADR 0014). Carriable
## props should neither block movement nor sight.
@export var carriable: bool = false


## True if it can be destroyed.
func is_destructible() -> bool:
	return max_health > 0
