class_name DiscoveryDef
extends Resource
## Data definition of one discovery: what a site on the map turns out to be once a
## Surveyor has scanned it, what it pays out and what it writes into the codex
## (PLAN 2.4). One `.tres` per discovery; the site entity is a DiscoverySite.

## The four discovery types.
const GEOLOGICAL: StringName = &"geological"
const BIOLOGICAL: StringName = &"biological"
const ANTECEDENT: StringName = &"antecedent"
const ENEMY: StringName = &"enemy"

## Payoffs.
## Nothing beyond Intel and the codex entry.
const PAYOFF_NONE: StringName = &"none"
## A resource node (`payoff_node`) appears at the site, offset by `payoff_offset`.
const PAYOFF_DEPOSIT: StringName = &"deposit"
## For `payoff_seconds`, the faction's units within `payoff_radius` of the site heal
## `payoff_amount` health per second.
const PAYOFF_HEAL_FIELD: StringName = &"heal_field"
## Unlocks the field option `unlocks_option` for the faction.
const PAYOFF_UNLOCK_OPTION: StringName = &"unlock_option"
## For `payoff_seconds`, the faction sees a disc of `payoff_radius` around every
## building and unit of its enemies (Custodians excepted).
const PAYOFF_REVEAL_ENEMY: StringName = &"reveal_enemy"
## For `payoff_seconds`, the planet's rule tells the faction what it does next
## (Emberfall: which vent erupts next, ADR 0015).
const PAYOFF_FORECAST: StringName = &"forecast"

@export var id: StringName = &""
@export var display_name: String = ""
## &"geological", &"biological", &"antecedent" or &"enemy".
@export var discovery_type: StringName = GEOLOGICAL
## The site scene (a DiscoverySite with its model); null gives a bare site (tests).
@export var scene: PackedScene
@export_group("Scan")
## Intel paid to the faction that resolves it.
@export_range(0, 10000, 1) var intel_reward: int = 50
## Seconds one scanner needs at a scan rate of 1.
@export_range(0.5, 600.0, 0.5, "suffix:s") var scan_time: float = 8.0
## Radius of the site on the ground (picking, blocking, scan reach), in metres.
@export_range(0.5, 30.0, 0.1, "suffix:m") var radius: float = 3.0
## Height used for click picking.
@export_range(0.5, 30.0, 0.1, "suffix:m") var height: float = 4.0
## Units path around the site's middle (most sites have a solid model).
@export var blocks_movement: bool = true
## Id of the discovery whose site this one charts when it is resolved (a chain);
## that site stays hidden and cannot be scanned until then.
@export var leads_to: StringName = &""
@export_group("Codex")
@export var codex_title: String = ""
@export_multiline var codex_text: String = ""
@export_group("Payoff")
## One of the PAYOFF_* kinds.
@export var payoff: StringName = PAYOFF_NONE
## Deposit payoff: the node that appears.
@export var payoff_node: ResourceNodeDef
## Deposit payoff: where it appears relative to the site.
@export var payoff_offset: Vector3 = Vector3(0.0, 0.0, 8.0)
## Heal field and enemy reveal: radius in metres.
@export_range(0.0, 200.0, 0.5, "suffix:m") var payoff_radius: float = 14.0
## Heal field: health per second.
@export_range(0.0, 1000.0, 0.5) var payoff_amount: float = 8.0
## Heal field and enemy reveal: how long it lasts.
@export_range(0.0, 3600.0, 1.0, "suffix:s") var payoff_seconds: float = 60.0
## Unlock payoff: id of the FieldOptionDef it unlocks.
@export var unlocks_option: StringName = &""
@export_group("Presentation")
## Colour of the site's glow once resolved (and of its scan ring).
@export var color: Color = Color(0.35, 0.92, 1.0)
