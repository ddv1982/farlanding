class_name HintDef
extends Resource
## One first-time tutorial hint as data (ADR 0011): a small card shown once per
## profile, the first time its trigger fires during a mission. `text` may say
## {command} and {select} for the mouse buttons of the current scheme.

const TRIGGER_MISSION_STARTED: StringName = &"mission_started"
## The player selected something matching `subject` (a capability or a def id).
const TRIGGER_SELECTED: StringName = &"selected"
## A player building matching `subject` finished construction.
const TRIGGER_CONSTRUCTION_COMPLETED: StringName = &"construction_completed"
const TRIGGER_STORM_INCOMING: StringName = &"storm_incoming"
## The tide is about to turn (Thalassa: `Events.tide_turning`).
const TRIGGER_TIDE_TURNING: StringName = &"tide_turning"
## The enemy keeps an alert meter (a stealth mission began).
const TRIGGER_ALERT_METER: StringName = &"alert_meter"
## Capabilities `subject` may name (otherwise it is a def id).
const SUBJECT_BUILDER: StringName = &"builder"
const SUBJECT_HARVESTER: StringName = &"harvester"
const SUBJECT_SCANNER: StringName = &"scanner"
const SUBJECT_SABOTEUR: StringName = &"saboteur"
const SUBJECT_PRODUCER: StringName = &"producer"

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var text: String = ""
@export var trigger: StringName = TRIGGER_MISSION_STARTED
## What the trigger must involve: a capability (builder, harvester, scanner, saboteur,
## producer) or an entity def id; empty = anything.
@export var subject: StringName = &""
## Only in missions of these types (MissionDef.mission_type); empty = every mission.
@export var mission_types: Array[StringName] = []
## Seconds after the trigger before the card appears.
@export_range(0.0, 60.0, 0.5, "suffix:s") var delay_seconds: float = 0.0
