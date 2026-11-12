extends GutTest


## Records how often and in which order it was executed.
class RecordingCommand:
	extends Command

	var log: Array[StringName]

	func _init(p_kind: StringName, p_entities: Array[Node3D], p_log: Array[StringName]) -> void:
		super(p_kind, 1, p_entities)
		log = p_log

	func execute() -> void:
		log.append(kind)


var _queue: CommandQueue
var _unit: Node3D
var _log: Array[StringName]


func before_each() -> void:
	_queue = CommandQueue.new()
	_unit = Node3D.new()
	add_child_autofree(_unit)
	_log = []


func _command(kind: StringName) -> RecordingCommand:
	return RecordingCommand.new(kind, [_unit], _log)


func test_push_does_not_execute_before_tick() -> void:
	_queue.push(_command(&"move"))
	assert_eq(_log.size(), 0)
	assert_eq(_queue.pending_count(), 1)


func test_flush_executes_in_push_order() -> void:
	_queue.push(_command(&"move"))
	_queue.push(_command(&"stop"))
	_queue.flush()
	assert_eq(_log, [&"move", &"stop"] as Array[StringName])
	assert_eq(_queue.pending_count(), 0)


func test_each_command_executes_once() -> void:
	_queue.push(_command(&"move"))
	_queue.flush()
	_queue.flush()
	assert_eq(_log.size(), 1)


func test_push_emits_command_issued() -> void:
	watch_signals(Events)
	var command: RecordingCommand = _command(&"move")
	_queue.push(command)
	assert_signal_emitted_with_parameters(Events, "command_issued", [command])


func test_command_with_freed_entities_is_dropped() -> void:
	var doomed: Node3D = Node3D.new()
	add_child(doomed)
	_queue.push(RecordingCommand.new(&"move", [doomed], _log))
	doomed.free()
	_queue.flush()
	assert_eq(_log.size(), 0)


func test_freed_entities_are_pruned_from_command() -> void:
	var doomed: Node3D = Node3D.new()
	add_child(doomed)
	var command: RecordingCommand = RecordingCommand.new(&"move", [_unit, doomed], _log)
	_queue.push(command)
	doomed.free()
	_queue.flush()
	assert_eq(command.entities, [_unit] as Array[Node3D])


func test_commands_pushed_during_flush_wait_for_next_tick() -> void:
	_queue.command_executed.connect(
		func(command: Command) -> void:
			if command.kind == &"move":
				_queue.push(_command(&"follow_up"))
	)
	_queue.push(_command(&"move"))
	_queue.flush()
	assert_eq(_log, [&"move"] as Array[StringName])
	_queue.flush()
	assert_eq(_log, [&"move", &"follow_up"] as Array[StringName])


func test_mission_context_runs_queue_on_sim_tick() -> void:
	var context: MissionContext = MissionContext.new()
	add_child_autofree(context)
	context.sim_clock.set_physics_process(false)
	context.command_queue.push(_command(&"move"))
	context.sim_clock.advance(SimClock.TICK_DELTA * 0.5)
	assert_eq(_log.size(), 0)
	context.sim_clock.advance(SimClock.TICK_DELTA * 0.5)
	assert_eq(_log, [&"move"] as Array[StringName])
