extends GutTest


## Logs its hooks and requests `next_state` on tick when set.
class LoggingState:
	extends State

	var label: String
	var log: Array[String]
	var next_state: StringName = &""

	func _init(p_label: String, p_log: Array[String]) -> void:
		label = p_label
		log = p_log

	func enter(previous: StringName) -> void:
		log.append("enter %s from '%s'" % [label, previous])

	func exit(next: StringName) -> void:
		log.append("exit %s to '%s'" % [label, next])

	func tick(_sim_tick: int) -> StringName:
		log.append("tick %s" % label)
		return next_state


var _machine: StateMachine
var _log: Array[String]
var _idle: LoggingState
var _moving: LoggingState


func before_each() -> void:
	_log = []
	_machine = StateMachine.new()
	_idle = LoggingState.new("idle", _log)
	_moving = LoggingState.new("moving", _log)
	_machine.add_state(&"idle", _idle)
	_machine.add_state(&"moving", _moving)


func test_no_state_before_start() -> void:
	assert_eq(_machine.get_current_state(), &"")
	_machine.tick(1)
	assert_eq(_log.size(), 0)


func test_start_enters_initial_state() -> void:
	_machine.start(&"idle")
	assert_eq(_machine.get_current_state(), &"idle")
	assert_eq(_log, ["enter idle from ''"] as Array[String])


func test_transition_calls_exit_then_enter_and_signals() -> void:
	_machine.start(&"idle")
	watch_signals(_machine)
	_machine.transition_to(&"moving")
	assert_eq(_machine.get_current_state(), &"moving")
	assert_eq(
		_log,
		["enter idle from ''", "exit idle to 'moving'", "enter moving from 'idle'"] as Array[String]
	)
	assert_signal_emitted_with_parameters(_machine, "state_changed", [&"idle", &"moving"])


func test_tick_runs_only_active_state() -> void:
	_machine.start(&"idle")
	_machine.tick(1)
	var last: String = _log.back()
	assert_eq(last, "tick idle")
	assert_false(_log.has("tick moving"))


func test_state_requested_transition_is_applied() -> void:
	_idle.next_state = &"moving"
	_machine.start(&"idle")
	_machine.tick(1)
	assert_eq(_machine.get_current_state(), &"moving")


func test_requesting_current_state_does_not_reenter() -> void:
	_idle.next_state = &"idle"
	_machine.start(&"idle")
	_machine.tick(1)
	assert_eq(_log, ["enter idle from ''", "tick idle"] as Array[String])


func test_save_round_trip() -> void:
	_machine.start(&"idle")
	_machine.transition_to(&"moving")
	var data: Dictionary = _machine.to_dict()
	var version: int = data["version"]
	assert_eq(version, StateMachine.SAVE_VERSION)

	var restored: StateMachine = StateMachine.new()
	restored.add_state(&"idle", State.new())
	restored.add_state(&"moving", State.new())
	restored.from_dict(data)
	assert_eq(restored.get_current_state(), &"moving")
