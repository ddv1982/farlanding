class_name SoundEvent
extends Resource
## One playable sound and the rules for playing it. One `.tres` per event under
## `res://data/sounds/<group>/`; the AudioService finds them all at startup, so a
## new sound needs a rendered file and a `.tres`, never code.

## Name used by `Audio.play()` and the event router, e.g. &"unit_ranger_select".
@export var id: StringName = &""
## Variations; one is picked per play.
@export var streams: Array[AudioStream] = []
## Mixer bus, see `res://default_bus_layout.tres`.
@export var bus: StringName = &"SFX"
## Higher wins when the voice budget is full (0..100).
@export_range(0, 100, 1) var priority: int = 50
## Most copies of this event that may sound at once.
@export_range(1, 32, 1) var max_instances: int = 4
## Minimum time between two starts of this event.
@export_range(0.0, 10.0, 0.01, "suffix:s") var cooldown: float = 0.0
@export_range(-40.0, 12.0, 0.1, "suffix:dB") var volume_db: float = 0.0
## Random detune range, plus or minus. Keep 0 for tonal signatures (they are in key).
@export_range(0.0, 12.0, 0.1, "suffix:st") var pitch_variation: float = 0.0
## Plays in 3D at the given position; otherwise flat (interface, Advisor).
@export var positional: bool = false
## Beyond this distance from the listener a positional event is not started.
@export_range(0.0, 1000.0, 0.5, "suffix:m") var max_distance: float = 60.0
## Never pick the same variation twice in a row.
@export var avoid_repeat: bool = true
## A movement loop (`move_<set>`) that keeps sounding while its unit stands
## still, quieter and lower: an aircraft's engine never stops (Phase 8c).
@export var loops_at_rest: bool = false
## What a spoken line means, shown as a subtitle while it plays (Phase 9). Every
## Advisor event has one: the Advisor speaks in tones, so the subtitle carries
## the words. Empty for everything else.
@export var subtitle: String = ""


## Picks a variation index. `last` is the previous pick (-1 if none), `roll` a
## random number in [0, 1).
static func pick_index(count: int, last: int, roll: float, avoid: bool) -> int:
	if count <= 0:
		return -1
	if count == 1 or not avoid or last < 0 or last >= count:
		return mini(int(roll * count), count - 1)
	# Choose among the others, keeping the distribution uniform.
	var index: int = mini(int(roll * (count - 1)), count - 2)
	return index + 1 if index >= last else index


## Longest variation in seconds (0 for streams of unknown length).
func longest_seconds() -> float:
	var longest: float = 0.0
	for stream: AudioStream in streams:
		if stream != null:
			longest = maxf(longest, stream.get_length())
	return longest
