class_name StateMachine
extends RefCounted
## Small typed finite state machine for unit behaviours. The owner registers states,
## calls `start()`, then `tick()` once per sim tick.

signal state_changed(from: StringName, to: StringName)

const SAVE_VERSION: int = 1

var _states: Dictionary[StringName, State] = {}
var _current_name: StringName = &""
var _current: State = null


func add_state(state_name: StringName, state: State) -> void:
	assert(state_name != &"", "State name must not be empty")
	assert(not _states.has(state_name), "Duplicate state: %s" % state_name)
	_states[state_name] = state


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


## Name of the active state, or &"" before `start()`.
func get_current_state() -> StringName:
	return _current_name


## Enters the initial state.
func start(state_name: StringName) -> void:
	assert(_current == null, "StateMachine already started")
	transition_to(state_name)


## Leaves the active state (if any) and enters `state_name`.
func transition_to(state_name: StringName) -> void:
	assert(_states.has(state_name), "Unknown state: %s" % state_name)
	var previous: StringName = _current_name
	if _current != null:
		_current.exit(state_name)
	_current_name = state_name
	_current = _states[state_name]
	_current.enter(previous)
	state_changed.emit(previous, state_name)


## Runs the active state for one sim tick and applies the transition it requests.
func tick(sim_tick: int) -> void:
	if _current == null:
		return
	var next: StringName = _current.tick(sim_tick)
	if next != &"" and next != _current_name:
		transition_to(next)


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "state": _current_name}


## Restores the active state. Calls `enter()` on it, so states must rebuild their own
## transient data there.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported StateMachine save version")
	var state_name: StringName = data.get("state", &"")
	if state_name == &"":
		return
	transition_to(state_name)
