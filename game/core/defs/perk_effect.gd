class_name PerkEffect
extends Resource
## One effect a tech, a loadout choice or an earlier discovery has on a landing
## (ADR 0012). Pure data: the campaign turns a list of these into the landing's
## LandingModifiers when it starts.

## Makes the entity type or field option `target` available (the campaign starts
## some locked).
const KIND_UNLOCK: StringName = &"unlock"
## Multiplies `stat` (a FactionPerks stat) by `factor`, for `target` or, when empty,
## for every entity of the player.
const KIND_SCALE: StringName = &"scale"
## `count` extra `unit`s land with the starting crew.
const KIND_UNITS: StringName = &"units"
## Adds `alloy`, `flux` and `intel` to the starting stockpile.
const KIND_RESOURCES: StringName = &"resources"
## Unlocks the field option `target` from the start (as its discovery would).
const KIND_UNLOCK_OPTION: StringName = &"unlock_option"
## `count` free uses of the field option `target`.
const KIND_CHARGE_OPTION: StringName = &"charge_option"
## The site of the discovery `target` starts charted (the orbital scan knows it).
const KIND_CHART_SITE: StringName = &"chart_site"
const KINDS: Array[StringName] = [
	KIND_UNLOCK,
	KIND_SCALE,
	KIND_UNITS,
	KIND_RESOURCES,
	KIND_UNLOCK_OPTION,
	KIND_CHARGE_OPTION,
	KIND_CHART_SITE,
]

## One of the KIND_* values.
@export var kind: StringName = KIND_SCALE
## Entity type, field option or discovery id, depending on `kind`.
@export var target: StringName = &""
## Scale: a FactionPerks stat (&"vision_range", &"max_health", &"carry_capacity",
## &"mine_time", &"scan_rate", &"intel_cost", &"cooldown", &"eruption_damage",
## &"vent_cooldown").
@export var stat: StringName = &""
@export var factor: float = 1.0
## Units.
@export var unit: UnitDef
@export_range(0, 50, 1) var count: int = 1
## Resources.
@export var alloy: int = 0
@export var flux: int = 0
@export var intel: int = 0
## One line for the briefing and the tech web; empty = generated from the data.
@export var note: String = ""
