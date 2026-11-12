class_name State
extends RefCounted
## One state of a StateMachine. Override the hooks you need. States hold no
## reference to their machine (avoids a reference cycle); they request transitions
## by returning the next state's name from `tick()`.


## Called when the machine enters this state.
func enter(_previous: StringName) -> void:
	pass


## Called when the machine leaves this state.
func exit(_next: StringName) -> void:
	pass


## Called once per sim tick while active. Return the next state's name, or &"" to stay.
func tick(_sim_tick: int) -> StringName:
	return &""
