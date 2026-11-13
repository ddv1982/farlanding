class_name WorldConditions
extends RefCounted
## The weather everyone plays under right now (ADR 0011): factors a planet rule sets
## each sim tick and the simulation reads. All 1 (and no storm) on a calm world, so
## code that reads them costs nothing when a planet has no rule. The vision factor is
## kept in steps of VISION_STEP so the vision grid sees only a few distinct radii.

const VISION_STEP: float = 0.05

## Every vision range (fog of war and targeting) is multiplied by this.
var vision_factor: float = 1.0
## Top speed of ground units / hovering units is multiplied by these.
var ground_speed_factor: float = 1.0
var hover_speed_factor: float = 1.0
## Watchers' sight-cone range (noticing intruders) is multiplied by this.
var sight_factor: float = 1.0
## Weapons reaching further than `long_range_from` are multiplied by `range_factor`,
## but never below `long_range_from`.
var long_range_from: float = INF
var range_factor: float = 1.0
## How bad the weather is, 0..1 (a dust storm's intensity). Public knowledge: any
## faction (and its AI) may read it.
var storm_intensity: float = 0.0
## Seconds until an announced storm starts building; INF when none is announced.
var storm_eta_seconds: float = INF
## True while the storm will not lift again (a mission's final storm).
var storm_is_final: bool = false
## Grows whenever a movement factor changes, so units re-apply their speed only then.
var speed_version: int = 0
## The sea on a tidal map (ADR 0014): its height in metres, -INF without a sea. Ground
## deeper than `wading_depth` under it is closed to ground units; units in such water
## wade at `wading_speed_factor` and take `wading_damage_per_second`. Public knowledge.
var sea_level: float = -INF
## The sea's height at low water: ground lower is never dry (the deep channel).
var low_water: float = -INF
## The sea's height at high water: ground lower floods at some point of the cycle.
var high_water: float = -INF
var wading_depth: float = 0.25
var wading_speed_factor: float = 1.0
var wading_damage_per_second: float = 0.0
## The tide, 0 = low water .. 1 = high water (public knowledge, like the storm).
var tide_level: float = 0.0
## True while the sea rises, or is announced to rise next.
var tide_rising: bool = false
## Seconds until the announced turn of the tide starts; INF when none is announced.
var tide_eta_seconds: float = INF
## Seconds until the shallows next close (the next rise starts); 0 while rising or
## high, INF without a sea.
var shallows_close_seconds: float = INF


## True on a map with a sea.
func has_sea() -> bool:
	return sea_level > -INF


## A unit's top-speed factor now (hovering units ride above the dust).
func speed_factor(hovers: bool) -> float:
	return hover_speed_factor if hovers else ground_speed_factor


## The range of a weapon whose dry-weather range is `max_range`.
func weapon_range(max_range: float) -> float:
	if max_range <= long_range_from or range_factor >= 1.0:
		return max_range
	return maxf(max_range * range_factor, long_range_from)


## Sets the movement factors; bumps `speed_version` when they changed.
func set_speed(ground: float, hover: float) -> void:
	if is_equal_approx(ground, ground_speed_factor) and is_equal_approx(hover, hover_speed_factor):
		return
	ground_speed_factor = ground
	hover_speed_factor = hover
	speed_version += 1


## Sets the vision factor, rounded to VISION_STEP.
func set_vision(factor: float) -> void:
	vision_factor = clampf(snappedf(factor, VISION_STEP), VISION_STEP, 1.0)


## Back to a calm sky.
func reset() -> void:
	set_vision(1.0)
	set_speed(1.0, 1.0)
	sight_factor = 1.0
	long_range_from = INF
	range_factor = 1.0
	storm_intensity = 0.0
	storm_eta_seconds = INF
	storm_is_final = false
	sea_level = -INF
	low_water = -INF
	high_water = -INF
	wading_speed_factor = 1.0
	wading_damage_per_second = 0.0
	tide_level = 0.0
	tide_rising = false
	tide_eta_seconds = INF
	shallows_close_seconds = INF
