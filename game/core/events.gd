## Global, typed event bus (autoload `Events`).
##
## The simulation emits; presentation, UI and audio listen. Signals are named in the
## past tense. Mission-scoped data never lives here, only notifications.
extends Node

@warning_ignore_start("unused_signal")

## The player's selection changed. Empty array means nothing is selected.
signal selection_changed(entities: Array[Node3D])

## A command was accepted by the command queue. It executes on the next sim tick.
signal command_issued(command: Command)

## A UI-level feedback cue, e.g. &"invalid_target" or &"not_enough_resources".
signal ui_feedback(kind: StringName)

## An entity entered the simulation.
signal entity_spawned(entity: Node3D)

## An entity died. It may be freed after the frame ends.
signal entity_died(entity: Node3D)

## The mission's sim clock advanced to `tick`.
signal sim_ticked(tick: int)

@warning_ignore_restore("unused_signal")
