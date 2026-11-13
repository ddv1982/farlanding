class_name MissionScript
extends RefCounted
## Per-mission rules beyond objectives (PLAN 3.6): a MissionDef names a subclass in
## `mission_script`. The Mission calls the hooks; a script acts through the Mission
## (add objectives and triggers, spawn units) and the CommandQueue.

var mission: Mission = null


func setup(p_mission: Mission) -> void:
	mission = p_mission


## The mission's forces are in place and its objectives started.
func on_started() -> void:
	pass


## One sim tick, after the objectives were evaluated.
func on_tick(_tick: int) -> void:
	pass


## An objective was achieved or failed.
func on_objective_finished(_objective: Objective) -> void:
	pass


## A faction's alert level changed.
func on_alert_changed(_faction: int, _level: StringName, _previous: StringName) -> void:
	pass


## The mission is over or being freed: let go of everything.
func stop() -> void:
	pass
