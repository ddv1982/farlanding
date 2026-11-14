class_name MissionSelect
extends Control
## Single missions (from the title screen): the expedition's name, the difficulty
## (remembered in the settings; the mission is played at it), one card per mission
## of the catalog (type, title, one-line summary), the settings and Back. Choosing
## one emits `mission_chosen`. With the menu backdrop behind it the background lets
## it through.

## The player picked `mission`.
signal mission_chosen(mission: MissionDef)
## The player asked for the settings.
signal settings_pressed
## Back to the title screen.
signal back_pressed

const BACKGROUND := Color(0.035, 0.045, 0.06)
const TYPE_NAMES: Dictionary[StringName, String] = {
	&"conquest": "CONQUEST",
	&"survey": "SURVEY",
	&"infiltration": "INFILTRATION",
	&"power": "POWER",
	&"finale": "FINALE",
}

var _cards: VBoxContainer
var _picker: DifficultyPicker
var _back: ColorRect
var _vignette: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back = ColorRect.new()
	_back.color = BACKGROUND
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette = HudStyle.make_vignette()
	_vignette.visible = false
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_picker = DifficultyPicker.new()
	_picker.chosen.connect(
		func(level: StringName) -> void: Settings.set_option(&"difficulty", level)
	)
	column.add_child(_picker)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 10)
	column.add_child(_cards)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override(&"separation", 10)
	var back: Button = HudStyle.make_small_button("BACK")
	back.custom_minimum_size = Vector2(120, 34)
	back.pressed.connect(
		func() -> void:
			Events.ui_feedback.emit(&"click")
			back_pressed.emit()
	)
	footer.add_child(back)
	var settings: Button = HudStyle.make_small_button("SETTINGS")
	settings.custom_minimum_size = Vector2(140, 34)
	settings.pressed.connect(func() -> void: settings_pressed.emit())
	footer.add_child(settings)
	column.add_child(footer)


## Lets the menu backdrop show through (or not).
func set_see_through(enabled: bool) -> void:
	if _back != null:
		_back.visible = not enabled
		_vignette.visible = enabled


## The difficulty choice (tests).
func picker() -> DifficultyPicker:
	return _picker


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and _picker != null:
		_picker.set_level(Settings.difficulty)


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
