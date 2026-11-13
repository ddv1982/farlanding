class_name CoreCues
extends RefCounted
## Pure rules for the Beacon Core's finale (Phase 8d, Hollow Meridian). The
## CoreSound node feeds it `Events.core_charge_changed(fraction)` and asks what
## to hear; nothing here plays.
##
## - Charge -> layers: the Hollow Meridian score has three Core layers that come
##   in one by one as the charge passes RISE (a quarter, a half, three
##   quarters): `core_1` (the Core's heartbeat and the Meridian's dyad high
##   above), `core_2` (the Trail motif climbing on bells), `core_3` (the motif
##   spinning as a mechanism, a band of light rising for ever). A layer only
##   leaves again when the charge falls HYSTERESIS below its threshold, so a
##   charge that wavers around a threshold (a contested Core) does not flap.
## - Awakened: `mus_core_awakened` (the Trail motif stated in full and
##   answered, the campaign's peak, then a calm tail) plays once; the Core
##   layers go and the score dips PEAK_DIP_DB under it until its calm tail,
##   TAIL_SECONDS before the end, when the score may come back.

## Layer names in the Hollow Meridian score, in the order they come in.
const LAYERS: Array[StringName] = [&"core_1", &"core_2", &"core_3"]
## Charge at which each layer comes in.
const RISE: Array[float] = [0.25, 0.5, 0.75]
## How far below its threshold the charge must fall before a layer leaves.
const HYSTERESIS: float = 0.08
const AWAKENED: StringName = &"mus_core_awakened"
## The score under the awakening (dB).
const PEAK_DIP_DB: float = -24.0
## The awakening's calm tail: the score is let back this long before its end (s).
const TAIL_SECONDS: float = 8.0


## The number of Core layers sounding at `charge` (0..1), given `current` (the
## number sounding now): up at RISE, down only HYSTERESIS below it.
static func level_for(charge: float, current: int) -> int:
	if is_nan(charge):
		return current
	var amount: float = clampf(charge, 0.0, 1.0)
	var level: int = clampi(current, 0, LAYERS.size())
	while level < LAYERS.size() and amount >= RISE[level]:
		level += 1
	while level > 0 and amount < RISE[level - 1] - HYSTERESIS:
		level -= 1
	return level


## Gain (dB) of Core layer `index` (0-based) when `level` layers sound.
static func layer_gain_db(index: int, level: int) -> float:
	return 0.0 if index < level else AudioMix.SILENT_DB


## How long the score stays dipped under an awakening of `seconds`.
static func dip_seconds(seconds: float) -> float:
	return maxf(seconds - TAIL_SECONDS, 0.0)
