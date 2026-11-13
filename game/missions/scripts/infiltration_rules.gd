class_name InfiltrationRules
extends Resource
## Data for InfiltrationScript: what happens once the squad is discovered.

## The objective whose completion opens the way out (the sabotage).
@export var target_objective: StringName = &"sabotage_uplink"
## The way out, added once the target objective is done (a reach_area objective).
@export var extraction: ObjectiveDef
## Where the way out moves to once the outpost is alerted.
@export var alerted_extraction: Vector3 = Vector3.ZERO
## Seconds left to get out once the outpost is alerted.
@export_range(0.0, 3600.0, 5.0, "suffix:s") var alerted_deadline_seconds: float = 300.0
## Reinforcements that answer the first alarms, one group per alarm.
@export var reinforcements: Array[UnitDef] = []
## Where they arrive.
@export var reinforcement_entry: Vector3 = Vector3.ZERO
@export_range(0, 10, 1) var max_reinforcement_waves: int = 1
