class_name RouteNodeDef
extends Resource
## One landing on the campaign's route (PLAN 1, ADR 0012): a planet, a mission, where
## it sits on the star map, and the landings that open once it is won. Lives in
## `campaign/` (not `core/defs/`) because it names a MissionDef.

## Settled ids (the save refers to them).
@export var id: StringName = &""
@export var title: String = ""
@export var planet: PlanetDef
@export var mission: MissionDef
## Position on the star map, 0..1 on both axes.
@export var map_position: Vector2 = Vector2(0.5, 0.5)
## Nodes that open when this one is won.
@export var leads_to: Array[StringName] = []
## Nodes that close for good when this one is won (the other side of a branch).
@export var excludes: Array[StringName] = []
## Techs that must be owned before it can be launched (empty = none).
@export var requires_tech: Array[StringName] = []
## Nodes that must be won before it can be launched, besides the one leading here.
@export var requires_nodes: Array[StringName] = []
## The orbital scan: what the Meridian's sensors make of the landing site.
@export_multiline var scan_summary: String = ""
## What the landing is expected to pay in Intel and finds (star map hover).
@export_multiline var intel_notes: String = ""
## True for a landing that stands in for content not built yet (its planet's own
## map and rule come later); the star map marks it.
@export var placeholder: bool = false
