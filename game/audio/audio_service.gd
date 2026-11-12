## Autoload `Audio`: the only way sound gets played. Gameplay never calls this for
## its own events — `audio/` listens to `Events` and decides what is heard. The
## public surface below is a contract other systems rely on.
extends Node


## Plays a sound event by id. Leave `position` at Vector3.INF for non-positional
## sounds (interface, advisor).
func play(_event_id: StringName, _position: Vector3 = Vector3.INF) -> void:
	pass


## Called by the camera every frame. `focus` is the ground point the camera looks
## at; `zoom` runs from 0 (closest) to 1 (furthest) and shapes the mix.
func set_listener_focus(_focus: Vector3, _zoom: float) -> void:
	pass


## Requests a music state, e.g. &"explore", &"tension", &"combat".
func set_music_state(_state: StringName) -> void:
	pass
