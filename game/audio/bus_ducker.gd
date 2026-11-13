class_name BusDucker
extends RefCounted
## Pure envelope for a brief duck of other buses while a discovery resolves:
## the phrase is the one thing the player should hear. The AudioService adds
## `offset_db(bus, now)` to each bus while `is_active(now)`.
##
## Shape: falls to the bus's depth over ATTACK, holds, then recovers over
## RELEASE. A new duck while one is running extends it (never shortens it).

## Bus -> depth in dB at full duck. Buses not listed are left alone (the
## Discovery bus itself, the Advisor, the interface).
const DEPTH_DB: Dictionary[StringName, float] = {
	&"Music": -8.0,
	&"Ambience": -6.0,
	&"SFX": -5.0,
}
const ATTACK: float = 0.08
const RELEASE: float = 1.0

var _start: float = -INF
var _hold_until: float = -INF


## Ducks from `now` for `hold` seconds (plus the release).
func duck(now: float, hold: float) -> void:
	if not is_active(now):
		_start = now
	_hold_until = maxf(_hold_until, now + maxf(hold, 0.0))


func is_active(now: float) -> bool:
	return now >= _start and now < _hold_until + RELEASE


## Amount (0..1) of the duck at `now`.
func amount(now: float) -> float:
	if not is_active(now):
		return 0.0
	var rise: float = clampf((now - _start) / ATTACK, 0.0, 1.0)
	if now <= _hold_until:
		return rise
	return rise * clampf(1.0 - (now - _hold_until) / RELEASE, 0.0, 1.0)


## dB offset for `bus` at `now` (0 when not ducked).
func offset_db(bus: StringName, now: float) -> float:
	var depth: float = DEPTH_DB.get(bus, 0.0)
	return depth * amount(now)
