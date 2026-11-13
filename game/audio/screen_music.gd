class_name ScreenMusic
extends Resource
## A campaign screen with a score of its own (Phase 8d: the ending). One file
## per screen in `res://data/sounds/screens/`, matched by its `screen` field, not
## by the file name: if the screen's id changes, `screen = &"..."` in its file is
## the one line to change. A screen without a file plays the ship score in that
## screen's state (CampaignCues.music_state), as before.
##
## The AudioService asks `find(screen)` on every `campaign_screen_changed`; the
## score switches like any other (`MusicDirector.switch_score`: one player, a fade
## out and in, never two scores together).

const DIR: String = "res://data/sounds/screens"

## The campaign screen id this music belongs to (`Events.campaign_screen_changed`).
@export var screen: StringName = &""
@export var score: MusicScore
## The score's state on this screen; empty plays its default state.
@export var state: StringName = &""


## The music of `screen_id`, or null if it has none (or no score).
static func find(screen_id: StringName) -> ScreenMusic:
	if screen_id == &"":
		return null
	for entry: String in ResourceLoader.list_directory(DIR):
		if not (entry.ends_with(".tres") or entry.ends_with(".res")):
			continue
		var music: ScreenMusic = load(DIR.path_join(entry)) as ScreenMusic
		if music != null and music.screen == screen_id and music.score != null:
			return music
	return null
