class_name CoreChargeObjective
extends Objective
## Wake the Beacon Core (the finale, ADR 0017): follows the side's charge of the Core as
## the mission's CoreScript counts it. The player's is achieved when it is full; the
## enemy's fails then (passive: the Combine woke the Core first). Its bar shows the
## charge, and the line says what holds it back.


func _start() -> void:
	if def.side != ObjectiveDef.SIDE_PLAYER:
		progress_side = ObjectiveDef.SIDE_ENEMY


func _evaluate() -> void:
	var script: CoreScript = mission.script_instance as CoreScript
	if script == null:
		return
	var faction: int = factions_of(def.side)[0]
	var charge: float = script.charge_of(faction)
	set_ratio(charge)
	set_progress(script.status_line(faction))
	if charge < 1.0:
		return
	if def.side == ObjectiveDef.SIDE_PLAYER:
		complete()
	else:
		fail()


func from_dict(data: Dictionary) -> void:
	super(data)
	if def != null and def.side != ObjectiveDef.SIDE_PLAYER:
		progress_side = ObjectiveDef.SIDE_ENEMY
