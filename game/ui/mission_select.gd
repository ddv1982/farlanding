class_name MissionSelect
extends Control
## The first screen: the expedition's name and one card per mission of the catalog
## (type, title, one-line summary). Choosing one emits `mission_chosen`.

## The player picked `mission`.
signal mission_chosen(mission: MissionDef)

const BACKGROUND := Color(0.035, 0.045, 0.06)
const TYPE_NAMES: Dictionary[StringName, String] = {
	&"conquest": "CONQUEST",
	&"survey": "SURVEY",
	&"infiltration": "INFILTRATION",
}

var _cards: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = BACKGROUND
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	centre.add_child(column)
	column.add_child(HudStyle.make_label(12, HudStyle.ACCENT_COLOR, "THE CONCORD SURVEY"))
	column.add_child(HudStyle.make_label(44, HudStyle.TEXT_COLOR, "Farlanding"))
	column.add_child(
		HudStyle.make_label(14, HudStyle.MUTED_COLOR, "Kessel Reach  ·  proving ground landings")
	)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 10)
	column.add_child(_cards)


## Shows one card per mission in `catalog`.
func show_catalog(catalog: MissionCatalog) -> void:
	for child: Node in _cards.get_children():
		child.queue_free()
	if catalog == null:
		return
	for mission: MissionDef in catalog.missions:
		if mission != null:
			_cards.add_child(_make_card(mission))


## Number of mission cards (tests).
func card_count() -> int:
	var count: int = 0
	for child: Node in _cards.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


static func type_name(mission: MissionDef) -> String:
	return TYPE_NAMES.get(mission.mission_type, String(mission.mission_type).to_upper())


func _make_card(mission: MissionDef) -> Button:
	var button: Button = HudStyle.make_small_button("")
	button.custom_minimum_size = Vector2(560, 84)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_card_pressed.bind(mission))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override(&"separation", 2)
	margin.add_child(text)
	text.add_child(HudStyle.make_label(11, HudStyle.ACCENT_COLOR, type_name(mission)))
	text.add_child(HudStyle.make_label(20, HudStyle.TEXT_COLOR, mission.title))
	text.add_child(HudStyle.make_label(12, HudStyle.MUTED_COLOR, mission.summary))
	return button


func _on_card_pressed(mission: MissionDef) -> void:
	Events.ui_feedback.emit(&"mission_select")
	mission_chosen.emit(mission)
