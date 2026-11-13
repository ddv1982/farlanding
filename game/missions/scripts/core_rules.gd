class_name CoreRules
extends Resource
## Data for CoreScript (the finale on Hollow Meridian, ADR 0017): how the Beacon Core
## charges, when the Custodians converge on it, and when the Combine joins the race.

## The prop that is the Core (the map's dais).
@export var core_id: StringName = &"antecedent_site_core"
## A side charges the Core only while it runs at least this many engines ...
@export_range(1, 16, 1) var engines_needed: int = 4
## ... and one of its units that can scan stands this close to the Core's centre.
@export_range(4.0, 40.0, 0.5, "suffix:m") var link_radius: float = 16.0
## Seconds of linking from empty to full with exactly `engines_needed` engines.
@export_range(10.0, 1800.0, 5.0, "suffix:s") var charge_seconds: float = 240.0
## Each engine beyond `engines_needed` charges this much faster (0.25 = +25 %).
@export_range(0.0, 2.0, 0.05) var extra_engine_rate: float = 0.25
## Charge lost per second while a side is not linked (0 = it keeps its charge).
@export_range(0.0, 0.05, 0.0005) var drain_per_second: float = 0.0
@export_group("Custodians")
## As the leading charge passes each of these, the next stage of Custodians wakes ...
@export var stage_charges: PackedFloat32Array = PackedFloat32Array([0.2, 0.45, 0.7, 0.9])
## ... every dormant one within this distance of the Core, and they converge on it.
@export var stage_radii: PackedFloat32Array = PackedFloat32Array([45.0, 80.0, 115.0, 400.0])
@export_group("The Combine")
## The Combine sends a linker to the dais from this mission second on, once it runs
## enough engines.
@export_range(0.0, 3600.0, 5.0, "suffix:s") var enemy_link_after_seconds: float = 300.0
## Armed units sent with its linker.
@export_range(0, 20, 1) var enemy_escort: int = 4
## Armed units it sends at the dais while the player is linked and charging.
@export_range(0, 30, 1) var enemy_strike: int = 8
@export_group("Objectives")
## The player's charge objective and the Combine's (a `core_charge` each).
@export var player_objective: StringName = &"wake_core"
@export var enemy_objective: StringName = &"rival_core"
