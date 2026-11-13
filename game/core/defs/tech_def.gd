class_name TechDef
extends Resource
## One node of the Meridian's tech web (PLAN 1, ADR 0012): bought once with banked
## Intel, permanent for the campaign, applied at the start of every later landing.
## Some need an Antecedent discovery made on an earlier landing; nothing else buys
## them (PLAN 2.4).

## Settled ids: the icon is `res://assets/icons/tech_<id>.png`.
@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
## The web's three branches: &"survey", &"industry", &"arms".
@export var branch: StringName = &""
@export_range(0, 10000, 1) var intel_cost: int = 50
## Techs that must be owned first.
@export var requires: Array[StringName] = []
## A discovery id the campaign must have made first (empty = none).
@export var requires_discovery: StringName = &""
## Where the node sits on the web: column (depth) and row.
@export var grid: Vector2i = Vector2i.ZERO
@export var effects: Array[PerkEffect] = []
