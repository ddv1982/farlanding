class_name MissionContext
extends Node
## Owns every mission-scoped service. Created with a mission and freed with it, so
## nothing leaks between landings. Nothing mission-scoped may be an autoload.

var sim_clock: SimClock
var command_queue: CommandQueue

var _services: Dictionary[StringName, Object] = {}


func _init() -> void:
	sim_clock = SimClock.new()
	sim_clock.name = &"SimClock"
	add_child(sim_clock)
	command_queue = CommandQueue.new()
	# Commands run first on each tick, before any system reacts to it.
	sim_clock.ticked.connect(command_queue.flush)


## Registers a mission-scoped service (e.g. &"world") so others can find it without
## node paths. Replaces any service registered under the same key.
func set_service(key: StringName, service: Object) -> void:
	_services[key] = service


## Returns the service registered under `key`, or null. Cast it at the call site.
func get_service(key: StringName) -> Object:
	return _services.get(key, null)
