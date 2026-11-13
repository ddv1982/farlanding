class_name ObjectiveDef
extends Resource
## One mission objective as data (PLAN 3.6). `type` picks the reusable Objective
## class (see ObjectiveFactory); the other fields are its parameters, and each type
## reads only the ones it needs.

const TYPE_DESTROY_ALL: StringName = &"destroy_all"
const TYPE_DESTROY_COUNT: StringName = &"destroy_count"
const TYPE_KEEP_ALIVE: StringName = &"keep_alive"
const TYPE_REACH_AREA: StringName = &"reach_area"
const TYPE_GATHER_INTEL: StringName = &"gather_intel"
const TYPE_SURVIVE: StringName = &"survive"
const TYPE_STAY_UNDETECTED: StringName = &"stay_undetected"
const TYPE_SCAN_SITES: StringName = &"scan_sites"
const TYPE_SABOTAGE: StringName = &"sabotage"
## Fails when the rival (`side`) banks `amount` Intel first (the Survey race).
const TYPE_RIVAL_INTEL: StringName = &"rival_intel"
## Whose things an objective is about.
const SIDE_PLAYER: StringName = &"player"
const SIDE_ENEMY: StringName = &"enemy"
const SIDE_CUSTODIAN: StringName = &"custodian"

@export var id: StringName = &""
@export var title: String = ""
## &"primary", &"secondary" or &"hidden" (a hidden one appears once achieved).
@export var kind: StringName = &"primary"
@export var type: StringName = TYPE_DESTROY_ALL
## Holds until the end (keep alive, stay undetected): it does not block a win and
## counts as done when the mission is won.
@export var passive: bool = false
## Fails if still open this many seconds after it began; 0 = no deadline.
@export_range(0.0, 7200.0, 1.0, "suffix:s") var deadline_seconds: float = 0.0
## False: the mission script adds it later (it is not there at the start).
@export var at_start: bool = true
@export_group("Parameters")
## &"player", &"enemy" or &"custodian".
@export var side: StringName = SIDE_ENEMY
## Only these types count (units or buildings); empty = any.
@export var defs: Array[EntityDef] = []
## A count: units to bring, kills, Intel to bank, sites to scan.
@export_range(0, 100000, 1) var amount: int = 1
## Every matching unit must take part (reach the area / stay alive), not `amount`.
@export var require_all: bool = false
## Survive: seconds to hold out.
@export_range(0.0, 7200.0, 1.0, "suffix:s") var seconds: float = 0.0
## Discovery ids (scan_sites).
@export var site_ids: Array[StringName] = []
## The area of reach_area (and the marker of any objective with `marked`).
@export var area_center: Vector3 = Vector3.ZERO
@export_range(0.0, 200.0, 0.5, "suffix:m") var area_radius: float = 0.0
