class_name MusicMood
extends RefCounted
## Decides the combat music state from what the Events bus reports. Pure logic.
##
## Every combat notification that involves the player adds *heat*, weighted by
## what it was and how near the listener focus it happened (near = within
## NEAR_RADIUS); heat halves every HALF_LIFE seconds. States step up the moment
## heat crosses an entry threshold and step down only after heat has stayed
## below a lower exit threshold for CALM_SECONDS (hysteresis, so the score
## does not flap). Combat always resolves through aftermath, which returns to
## explore after AFTERMATH_SECONDS of quiet:
##
##   explore --heat>=TENSION_ENTER--> tension --heat>=COMBAT_ENTER--> combat
##   tension --heat<TENSION_EXIT for CALM_SECONDS--> explore
##   combat  --heat<COMBAT_EXIT for CALM_SECONDS--> aftermath --AFTERMATH_SECONDS--> explore
##   aftermath --heat rises--> tension or combat
##
## Once the mission ends the mood is fixed at &"victory" or &"defeat".

const EXPLORE: StringName = &"explore"
const TENSION: StringName = &"tension"
const COMBAT: StringName = &"combat"
const AFTERMATH: StringName = &"aftermath"
const VICTORY: StringName = &"victory"
const DEFEAT: StringName = &"defeat"

const HALF_LIFE: float = 6.0
const NEAR_RADIUS: float = 45.0
const TENSION_ENTER: float = 2.5
const TENSION_EXIT: float = 1.0
const COMBAT_ENTER: float = 12.0
const COMBAT_EXIT: float = 4.0
const CALM_SECONDS: float = 6.0
const AFTERMATH_SECONDS: float = 20.0

## Heat per notification: [near, far].
const FIRE: Vector2 = Vector2(0.5, 0.2)
const HURT: Vector2 = Vector2(1.0, 0.6)
const HIT: Vector2 = Vector2(0.5, 0.25)
const LOSS: Vector2 = Vector2(2.5, 2.0)
const KILL: Vector2 = Vector2(1.5, 1.0)

var state: StringName = EXPLORE

var _heat: float = 0.0
var _heat_time: float = 0.0
var _calm_since: float = INF
var _entered: float = 0.0
var _over: bool = false


## A shot was fired by the player's side, or by anyone the player can see.
func note_fire(distance: float, now: float) -> void:
	_add(_pick(FIRE, distance), now)


## Something took damage. Only counts if the player's side is involved.
func note_damage(
	victim_is_player: bool, attacker_is_player: bool, distance: float, now: float
) -> void:
	if victim_is_player:
		_add(_pick(HURT, distance), now)
	elif attacker_is_player:
		_add(_pick(HIT, distance), now)


## Something died: the player's loss weighs more than a kill.
func note_death(is_player: bool, distance: float, now: float) -> void:
	_add(_pick(LOSS if is_player else KILL, distance), now)


func end_mission(won: bool) -> void:
	_over = true
	state = VICTORY if won else DEFEAT


func is_over() -> bool:
	return _over


func heat(now: float) -> float:
	return _heat * pow(0.5, maxf(now - _heat_time, 0.0) / HALF_LIFE)


## Advances the state machine; returns the state to play.
func update(now: float) -> StringName:
	if _over:
		return state
	var h: float = heat(now)
	match state:
		EXPLORE:
			if h >= COMBAT_ENTER:
				_enter(COMBAT, now)
			elif h >= TENSION_ENTER:
				_enter(TENSION, now)
		TENSION:
			if h >= COMBAT_ENTER:
				_enter(COMBAT, now)
			elif _calm_for(h < TENSION_EXIT, now) >= CALM_SECONDS:
				_enter(EXPLORE, now)
		COMBAT:
			if _calm_for(h < COMBAT_EXIT, now) >= CALM_SECONDS:
				_enter(AFTERMATH, now)
		AFTERMATH:
			if h >= COMBAT_ENTER:
				_enter(COMBAT, now)
			elif h >= TENSION_ENTER:
				_enter(TENSION, now)
			elif now - _entered >= AFTERMATH_SECONDS:
				_enter(EXPLORE, now)
	return state


static func _pick(weights: Vector2, distance: float) -> float:
	return weights.x if distance <= NEAR_RADIUS else weights.y


func _add(amount: float, now: float) -> void:
	if _over:
		return
	_heat = heat(now) + amount
	_heat_time = now


## Seconds the calm condition has held (0 when it does not hold now).
func _calm_for(calm: bool, now: float) -> float:
	if not calm:
		_calm_since = INF
		return 0.0
	if _calm_since == INF:
		_calm_since = now
	return now - _calm_since


func _enter(next: StringName, now: float) -> void:
	state = next
	_entered = now
	_calm_since = INF
