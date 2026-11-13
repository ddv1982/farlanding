class_name HoldMachinesObjective
extends Objective
## Hold the deck's power (ADR 0017): the side must run at least `amount` Antecedent
## engines for `seconds` in all; the clock runs only while it holds that many and
## pauses (it does not reset) while it holds fewer. For the player it is achieved then;
## for the enemy side it fails instead (passive: the Combine out-holds the player). Its
## bar shows the clock.

## Sim ticks the side has held enough engines so far.
var held_ticks: int = 0


func _start() -> void:
	if def.side != ObjectiveDef.SIDE_PLAYER:
		progress_side = ObjectiveDef.SIDE_ENEMY


func _evaluate() -> void:
	var machinery: MachinerySystem = mission.world.planet as MachinerySystem
	if machinery == null:
		return
	var held: int = 0
	for faction: int in factions_of(def.side):
		held = maxi(held, machinery.held_by(faction).size())
	if held >= def.amount:
		held_ticks += 1
	var needed: int = maxi(CommanderDifficulty.ticks(def.seconds), 1)
	set_ratio(float(held_ticks) / needed)
	var who: String = "Held" if def.side == ObjectiveDef.SIDE_PLAYER else "Combine held"
	set_progress(
		(
			"%s %d+ engines %s / %s  ·  now %d"
			% [who, def.amount, _clock(held_ticks), _clock(needed), held]
		)
	)
	if held_ticks < needed:
		return
	if def.side == ObjectiveDef.SIDE_PLAYER:
		complete()
	else:
		fail()


static func _clock(ticks: int) -> String:
	var seconds: int = floori(float(ticks) / SimClock.TICK_RATE)
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	data["held_ticks"] = held_ticks
	return data


func from_dict(data: Dictionary) -> void:
	super(data)
	held_ticks = data.get("held_ticks", 0)
	if def != null and def.side != ObjectiveDef.SIDE_PLAYER:
		progress_side = ObjectiveDef.SIDE_ENEMY
