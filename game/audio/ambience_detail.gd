class_name AmbienceDetail
extends Resource
## One kind of positional ambience one-shot (AmbienceSet). Its weight in the
## random pick comes from where the listener is:
##
##   (weight + vent * near_vent + base * near_base + flood * tide + ebb * (1 - tide))
##   * (1 - storm * storm_cover) * (1 - 0.75 * near_site)
##
## (AmbienceCues.detail_weights). `anchor` says where it plays.

const RING: StringName = &"ring"
const VENT: StringName = &"vent"
const BASE: StringName = &"base"

## SoundEvent to play.
@export var event: StringName = &""
@export var weight: float = 1.0
@export var vent: float = 0.0
@export var base: float = 0.0
## Added weight at high water, and at low water.
@export var flood: float = 0.0
@export var ebb: float = 0.0
## How much a storm silences it (1 = gone in a full storm).
@export_range(0.0, 1.0) var storm_cover: float = 0.0
## &"ring" (around the listener), &"vent" (at the nearest Flux vent when there
## is one, else the ring) or &"base" (at the seen enemy base, else not at all).
@export var anchor: StringName = RING
