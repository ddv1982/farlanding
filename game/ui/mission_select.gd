class_name MissionSelect
extends Control
## Single missions (from the title screen): the expedition's name, the difficulty
## (remembered in the settings; the mission is played at it), one card per mission
## of the catalog (type, title, summary), the settings and Back (or Esc). Choosing
## one emits `mission_chosen`. The missions open in catalog order: a locked card says
## which mission to win first and cannot be chosen; a won one is marked COMPLETED.
## Only the cards scroll, when the window is too short for all of them; the heading
## and the buttons stay in view. With the menu backdrop behind it the background
## lets it through.

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
## A card's width, px: wide enough that a summary takes at most two lines.
const CARD_WIDTH: float = 560.0
## A card's least height, px (it grows with a longer summary).
const CARD_HEIGHT: float = 84.0
## Space inside a card around its text, px.
const CARD_PADDING: int = 14
## Space kept free above and below the column, px.
const SCREEN_MARGIN: int = 24
## A card's state (`card_state`).
const CARD_OPEN: StringName = &"open"
const CARD_LOCKED: StringName = &"locked"
const CARD_COMPLETED: StringName = &"completed"

var _catalog: MissionCatalog = null
var _cards: VBoxContainer
## Each mission shown -> its card.
var _card_of: Dictionary[MissionDef, Button] = {}
## Each mission shown -> its labels: the type line, the mark, the title, the summary.
var _labels_of: Dictionary[MissionDef, Array] = {}
var _scroll: ScrollContainer
var _footer: HBoxContainer
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
	var column := FitColumn.new(10)
	column.outer_margin = SCREEN_MARGIN * 2
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
	_scroll = column.add_scroll(_cards)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override(&"separation", 10)
	var back: Button = HudStyle.make_small_button("BACK")
	back.custom_minimum_size = Vector2(120, 34)
	back.pressed.connect(go_back)
	_footer.add_child(back)
	var settings: Button = HudStyle.make_small_button("SETTINGS")
	settings.custom_minimum_size = Vector2(140, 34)
	settings.pressed.connect(func() -> void: settings_pressed.emit())
	_footer.add_child(settings)
	column.add_child(_footer)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	# The settings (or How to play) over this screen close on Esc themselves.
	if _overlay_open():
		return
	go_back()
	get_viewport().set_input_as_handled()


## Back to the title screen (BACK or Esc).
func go_back() -> void:
	Events.ui_feedback.emit(&"click")
	back_pressed.emit()


## Lets the menu backdrop show through (or not).
func set_see_through(enabled: bool) -> void:
	if _back != null:
		_back.visible = not enabled
		_vignette.visible = enabled


## The difficulty choice (tests).
func picker() -> DifficultyPicker:
	return _picker


## The scroll area of the cards (tests).
func card_scroll() -> ScrollContainer:
	return _scroll


## The row of BACK and SETTINGS (tests).
func footer() -> HBoxContainer:
	return _footer


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and _picker != null:
		_picker.set_level(Settings.difficulty)
		refresh()


## Shows one card per mission in `catalog`, each open, locked or completed by the
## missions this profile has won.
func show_catalog(catalog: MissionCatalog) -> void:
	for child: Node in _cards.get_children():
		child.queue_free()
	_catalog = catalog
	_card_of.clear()
	_labels_of.clear()
	if catalog == null:
		return
	for mission: MissionDef in catalog.missions:
		if mission != null:
			var card: Button = _make_card(mission)
			_card_of[mission] = card
			_cards.add_child(card)
	refresh()


## Re-reads which missions are won, open and locked (after a win, on showing again).
func refresh() -> void:
	for mission: MissionDef in _card_of:
		_show_state(mission, card_state(mission))


## CARD_OPEN, CARD_LOCKED or CARD_COMPLETED for `mission` (open when no catalog).
func card_state(mission: MissionDef) -> StringName:
	if mission != null and Settings.has_won_mission(mission.id):
		return CARD_COMPLETED
	if _catalog == null or _catalog.is_open(mission, Settings.missions_won):
		return CARD_OPEN
	return CARD_LOCKED


## The card of `mission`, or null (tests).
func card_of(mission: MissionDef) -> Button:
	return _card_of.get(mission, null)


## The type line of `mission`'s card ("LOCKED · win ... first" while locked), or "".
func card_line(mission: MissionDef) -> String:
	var labels: Array = _labels_of.get(mission, [])
	if labels.is_empty():
		return ""
	var line: Label = labels[0]
	return line.text


## The mark of `mission`'s card ("COMPLETED" once won), or "".
func card_mark(mission: MissionDef) -> String:
	var labels: Array = _labels_of.get(mission, [])
	if labels.is_empty():
		return ""
	var mark: Label = labels[1]
	return mark.text


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
	button.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_card_pressed.bind(mission))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, CARD_PADDING)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override(&"separation", 2)
	margin.add_child(text)
	# A locked card keeps its own look (its text greyed) instead of the theme's disabled one.
	button.add_theme_stylebox_override(&"disabled", button.get_theme_stylebox(&"normal"))
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(top)
	var line: Label = HudStyle.make_label(11, HudStyle.ACCENT_COLOR, type_name(mission))
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(line)
	var mark: Label = HudStyle.make_label(11, ObjectivesPanel.DONE_COLOR)
	top.add_child(mark)
	var title: Label = HudStyle.make_label(20, HudStyle.TEXT_COLOR, mission.title)
	text.add_child(title)
	var summary: Label = HudStyle.make_label(12, HudStyle.MUTED_COLOR, mission.summary)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wrapped at the card's inner width from the start, so its height is right at once.
	summary.custom_minimum_size = Vector2(CARD_WIDTH - CARD_PADDING * 2, 0)
	text.add_child(summary)
	_labels_of[mission] = [line, mark, title, summary]
	# A Button does not grow with its children: follow the text's height by hand.
	margin.minimum_size_changed.connect(_fit_card.bind(button, margin))
	_fit_card(button, margin)
	return button


## Makes `button` as tall as its text (`margin`) needs, and never less than a card.
static func _fit_card(button: Button, margin: MarginContainer) -> void:
	var height: float = maxf(CARD_HEIGHT, margin.get_combined_minimum_size().y)
	button.custom_minimum_size = Vector2(CARD_WIDTH, height)


func _show_state(mission: MissionDef, state: StringName) -> void:
	var card: Button = _card_of[mission]
	var labels: Array = _labels_of[mission]
	var line: Label = labels[0]
	var mark: Label = labels[1]
	var locked: bool = state == CARD_LOCKED
	card.disabled = locked
	line.text = type_name(mission)
	if locked:
		var previous: MissionDef = _catalog.previous_of(mission)
		line.text = "LOCKED  ·  win %s first" % (previous.title if previous != null else "")
	# The line saying what to win first stays readable; the rest of the card greys.
	line.add_theme_color_override(
		&"font_color", HudStyle.MUTED_COLOR if locked else HudStyle.ACCENT_COLOR
	)
	mark.text = "COMPLETED" if state == CARD_COMPLETED else ""
	var title: Label = labels[2]
	title.add_theme_color_override(
		&"font_color", HudStyle.LOCKED_COLOR if locked else HudStyle.TEXT_COLOR
	)
	var summary: Label = labels[3]
	summary.add_theme_color_override(
		&"font_color", HudStyle.LOCKED_COLOR if locked else HudStyle.MUTED_COLOR
	)


func _overlay_open() -> bool:
	if get_parent() == null:
		return false
	for sibling: Node in get_parent().get_children():
		if (sibling is SettingsPanel or sibling is InfoPanel) and (sibling as Control).visible:
			return true
	return false


func _on_card_pressed(mission: MissionDef) -> void:
	if card_state(mission) == CARD_LOCKED:
		Events.ui_feedback.emit(&"invalid")
		return
	Events.ui_feedback.emit(&"mission_select")
	mission_chosen.emit(mission)
