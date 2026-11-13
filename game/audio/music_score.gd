class_name MusicScore
extends Resource
## A planet's adaptive score and ambience. One `.tres` per planet in
## `res://data/sounds/music/`. The MusicDirector builds an
## AudioStreamInteractive from the clips (bar-synced crossfades between them)
## and drives the layer volumes of the clip that is playing.

@export var id: StringName = &""
@export var clips: Array[MusicClip] = []
@export var states: Array[MusicState] = []
@export var default_state: StringName = &"explore"
## Crossfade length between clips, in beats (transitions wait for the next bar).
@export_range(0.0, 32.0, 0.5) var transition_beats: float = 4.0
## Seconds a state is held before a less intense one may replace it.
@export_range(0.0, 60.0, 0.5, "suffix:s") var min_hold: float = 8.0
## Seconds for a layer to fade fully in or out.
@export_range(0.1, 30.0, 0.1, "suffix:s") var layer_fade: float = 3.0
## Tempo of the clips' grid. With `quantize_beats`, layer changes wait for the
## next boundary of that many beats, so they land on the beat.
@export_range(0.0, 300.0, 0.1) var bpm: float = 0.0
@export_range(0.0, 16.0, 0.5) var quantize_beats: float = 0.0
## SoundEvent id of the ambience bed that goes with this score.
@export var ambience: StringName = &""


func find_state(state_name: StringName) -> MusicState:
	for state: MusicState in states:
		if state.name == state_name:
			return state
	return null


func clip_index(clip_name: StringName) -> int:
	for i: int in clips.size():
		if clips[i].name == clip_name:
			return i
	return -1
