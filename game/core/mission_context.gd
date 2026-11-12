class_name MissionContext
extends Node
## Owns every mission-scoped service. Created with a mission and freed with it, so
## nothing leaks between landings. Nothing mission-scoped may be an autoload.

var sim_clock: SimClock
var command_queue: CommandQueue


func _init() -> void:
	sim_clock = SimClock.new()
	sim_clock.name = &"SimClock"
	add_child(sim_clock)
	command_queue = CommandQueue.new()
	# Commands run first on each tick, before any system reacts to it.
	sim_clock.ticked.connect(command_queue.flush)
