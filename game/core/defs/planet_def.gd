class_name PlanetDef
extends Resource
## One planet (PLAN 2.5): its name and its rule. A MissionDef names the planet it is
## played on; the mission starts the planet's rule in the world.

@export var id: StringName = &""
@export var display_name: String = ""
## One line for the orbital scan (biome, what to expect); the rule has its own.
@export_multiline var summary: String = ""
## The planet's rule, or null for none.
@export var rule: PlanetRule
