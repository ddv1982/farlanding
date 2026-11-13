class_name MissionDef
extends Resource
## One mission as data (PLAN 3.6): which map, who starts where with what, the enemy
## and how it plays, the objectives, and an optional script for rules data cannot
## express. The map scene holds only terrain, navigation, resources and sites.

const TYPE_CONQUEST: StringName = &"conquest"
const TYPE_SURVEY: StringName = &"survey"
const TYPE_INFILTRATION: StringName = &"infiltration"

@export var id: StringName = &""
@export var title: String = ""
## &"conquest", &"survey", &"infiltration" (later: &"recovery", &"holdout").
@export var mission_type: StringName = TYPE_CONQUEST
## One line for the mission list.
@export var summary: String = ""
@export_multiline var briefing: String = ""
@export var map_scene: PackedScene
## The planet it is played on; its rule (Kessel: dust storms) runs in the mission.
@export var planet: PlanetDef
@export_group("Player")
@export var player_faction: int = 0
## The player's HQ (the Lander); null = no base (and no production from it).
@export var player_hq: BuildingDef
## Where the HQ stands, or where the squad gathers without one.
@export var player_start: Vector3 = Vector3.ZERO
## Direction the starting units face.
@export var player_facing: Vector3 = Vector3(0.0, 0.0, -1.0)
@export var player_roster: Array[UnitDef] = []
## Starting stockpile; -1 = the economy rules' default.
@export var start_alloy: int = -1
@export var start_flux: int = -1
@export var start_intel: int = 0
@export_group("Enemy")
@export var hostile_faction: int = 1
@export var hostile_hq: BuildingDef
@export var hostile_hq_position: Vector3 = Vector3.ZERO
@export var hostile_buildings: Array[BuildingDef] = []
## One centre per entry of `hostile_buildings`.
@export var hostile_building_positions: PackedVector3Array = PackedVector3Array()
## Units lined up at `hostile_start`: harvesters start mining, the rest wait.
@export var hostile_roster: Array[UnitDef] = []
@export var hostile_start: Vector3 = Vector3.ZERO
@export var hostile_facing: Vector3 = Vector3(0.0, 0.0, 1.0)
## The commander that plays the enemy base; none = no base AI.
@export var commander_profile: CommanderProfile
@export_enum("easy", "normal", "hard") var enemy_difficulty: String = "easy"
## Guard posts: units walking patrol routes (run by a GuardCommander).
@export var patrols: Array[PatrolRoute] = []
## The enemy keeps an alert meter (Unaware, Suspicious, Alerted) and its watchers
## notice any intruder, not only cloaked ones.
@export var enemy_alert_meter: bool = false
@export_group("Rules")
@export var objectives: Array[ObjectiveDef] = []
## A MissionScript subclass for rules beyond objectives, or null.
@export var mission_script: Script
## Data for the script (its own Resource type), or null.
@export var script_rules: Resource
## The objective whose deadline is the planet's climax (Survey: the storm that does
## not lift arrives when its countdown ends); empty = none.
@export var climax_objective: StringName = &""
## Props this mission adds to the map (an outpost's cover), or null.
@export var props: PropLayout
## Where the camera looks first; Vector3.INF = near the player's start.
@export var camera_start: Vector3 = Vector3.INF


## Objectives present from the start.
func starting_objectives() -> Array[ObjectiveDef]:
	var result: Array[ObjectiveDef] = []
	for objective: ObjectiveDef in objectives:
		if objective != null and objective.at_start:
			result.append(objective)
	return result


## The objective definition with `objective_id`, or null.
func objective_def(objective_id: StringName) -> ObjectiveDef:
	for objective: ObjectiveDef in objectives:
		if objective != null and objective.id == objective_id:
			return objective
	return null
