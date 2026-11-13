class_name PlanetRule
extends Resource
## A planet's one rule (PLAN 2.5) as data: the numbers live in a subclass Resource
## (e.g. DustStormRule) and `system` names the simulation script that plays it (a
## PlanetRuleSystem subclass in `sim/systems/planet/`). A new planet adds a rule
## Resource and a system script; the engine does not change (ADR 0011).

@export var id: StringName = &""
## What the rule does, in one line (briefing, codex).
@export_multiline var summary: String = ""
## The PlanetRuleSystem subclass that runs this rule on a mission's sim clock.
@export var system: Script
## Seed for the rule's random choices, so a mission plays the same each time.
@export var random_seed: int = 1
