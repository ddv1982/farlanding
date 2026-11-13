class_name FieldOptionDef
extends Resource
## Data definition of a Survey Lab field option (PLAN 1): a one-off effect paid for
## in Intel, aimed at a point on the map, with a cooldown per faction.

## Effects.
## Reveals a disc of `radius` around the point for `seconds` (the faction only).
const EFFECT_REVEAL: StringName = &"reveal"
## Lands `alloy` and `flux` in the stockpile and, if `node`, a resource cache at the point.
const EFFECT_SUPPLY_DROP: StringName = &"supply_drop"
## Deals `damage` (type `damage_type`) to everything not of the faction within `radius`.
const EFFECT_STRIKE: StringName = &"strike"

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## One of the EFFECT_* kinds.
@export var effect: StringName = EFFECT_REVEAL
@export_range(0, 10000, 1) var intel_cost: int = 50
@export_range(0.0, 3600.0, 1.0, "suffix:s") var cooldown: float = 60.0
## True if a discovery must unlock it before it can be used (DiscoveryDef.unlocks_option).
@export var requires_unlock: bool = false
@export_group("Effect")
@export_range(0.0, 200.0, 0.5, "suffix:m") var radius: float = 30.0
## Reveal: how long the area stays revealed.
@export_range(0.0, 600.0, 1.0, "suffix:s") var seconds: float = 30.0
## Supply drop.
@export_range(0, 100000, 1) var alloy: int = 0
@export_range(0, 100000, 1) var flux: int = 0
@export var node: ResourceNodeDef
## Strike.
@export_range(0.0, 100000.0, 1.0) var damage: float = 0.0
@export var damage_type: StringName = &"heavy"
@export_group("Presentation")
@export var sound_set: StringName = &""
