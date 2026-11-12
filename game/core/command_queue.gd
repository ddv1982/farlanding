class_name CommandQueue
extends RefCounted
## The single path for every order. Commands are pushed at any time and executed,
## in push order, on the next sim tick (`flush()` is connected to SimClock.ticked by
## MissionContext). `Events.command_issued` fires on push so feedback is instant.

## Emitted after a command ran.
signal command_executed(command: Command)

var _pending: Array[Command] = []


## Accepts a command for execution on the next tick.
func push(command: Command) -> void:
	_pending.append(command)
	Events.command_issued.emit(command)


## Number of commands waiting for the next tick.
func pending_count() -> int:
	return _pending.size()


## Discards every waiting command.
func clear() -> void:
	_pending.clear()


## Executes all waiting commands in push order. Commands pushed while flushing
## run on the following tick. Commands whose receivers are all gone are dropped.
func flush(_tick: int = 0) -> void:
	var batch: Array[Command] = _pending
	_pending = []
	for command: Command in batch:
		if not command.prune_entities():
			continue
		command.execute()
		command_executed.emit(command)
