class_name EndingScreen
extends MenuScreen
## The end of the campaign (ADR 0017), shown over the star backdrop once the Beacon
## Core is awake and the debrief is closed, and again when Continue picks a finished
## campaign: what the Core showed the expedition, then the campaign's numbers
## (difficulty, landings, Intel, discoveries, techs), the credits and a way back to
## the title.

signal title_pressed
signal credits_pressed

const HEADING: String = "THE END OF THE TRAIL"
const STORY: PackedStringArray = [
	(
		"The Core did not open. It lit. For a moment every screen aboard the Meridian"
		+ " showed the same thing: a map, drawn in the marks of the beacons. Kessel was on"
		+ " it, and Thalassa, Emberfall and Verdance, each with a beacon burning beside it."
	),
	(
		"Then the map kept going. Past Verdance it ran on through hundreds of worlds,"
		+ " each one surveyed, each one with its listening stones and its engines left"
		+ " running. The Antecedents had not built a monument. They had been surveyors,"
		+ " and the trail was their survey, kept open for whoever came after."
	),
	(
		"The last thing the Core showed was a small light at the edge of the map, moving"
		+ " outward. It took the bridge crew a while to understand that it was the Meridian,"
		+ " and that the beacons ahead had already begun to answer."
	),
	(
		"The Combine left the deck within the week. The Concord Survey stayed to listen."
		+ " There are more beacons. There always were."
	),
]

var _stats: Label
var _back_button: Button


func _build() -> void:
	var frame: MarginContainer = _make_frame(48)
	var centre := CenterContainer.new()
	frame.add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	column.custom_minimum_size = Vector2(720, 0)
	centre.add_child(column)
	column.add_child(HudStyle.make_label(12, HudStyle.ACCENT_COLOR, "THE KESSEL TRAIL · COMPLETE"))
	column.add_child(HudStyle.make_label(34, HudStyle.TEXT_COLOR, HEADING))
	for paragraph: String in STORY:
		var text: Label = HudStyle.make_label(15, HudStyle.TEXT_COLOR, paragraph)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(720, 0)
		column.add_child(text)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	column.add_child(gap)
	_stats = HudStyle.make_label(14, HudStyle.INTEL_COLOR)
	column.add_child(_stats)
	_back_button = HudStyle.make_menu_button("BACK TO THE TITLE", 280.0)
	_back_button.pressed.connect(
		func() -> void:
			Events.ui_feedback.emit(&"click")
			title_pressed.emit()
	)
	var credits: Button = HudStyle.make_menu_button("CREDITS", 280.0)
	credits.pressed.connect(
		func() -> void:
			Events.ui_feedback.emit(&"click")
			credits_pressed.emit()
	)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	buttons.add_child(_back_button)
	buttons.add_child(credits)
	column.add_child(buttons)


## Shows the ending for the finished campaign `state`.
func open(state: CampaignState) -> void:
	_stats.text = stats_text(state)
	visible = true


## The campaign's numbers in one block of text.
static func stats_text(state: CampaignState) -> String:
	if state == null:
		return ""
	var stats: Dictionary[StringName, int] = state.statistics()
	return (
		"Difficulty  %s\nLandings  %d won of %d made\nIntel banked  %d\nDiscoveries  %d\nTechs  %d"
		% [
			Difficulty.label(state.difficulty),
			stats[&"landings_won"],
			stats[&"landings_made"],
			stats[&"intel_banked"],
			stats[&"discoveries"],
			stats[&"techs"],
		]
	)
