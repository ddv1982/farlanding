class_name TitleScreen
extends MenuScreen
## The first screen offers Continue, New campaign, Single missions and Load game,
## followed by help, controls, settings, credits and native Quit. New campaign first
## asks for the difficulty (remembered in the settings for next time); START emits
## `new_campaign_pressed`. Primary actions stay stacked; secondary actions share
## a compact grid. Short windows use tighter spacing before scrolling is needed.

signal new_campaign_pressed
signal load_pressed
signal continue_pressed
signal missions_pressed
signal settings_pressed
signal quit_pressed
signal how_to_play_pressed
signal controls_pressed
signal credits_pressed

## Space kept free above and below the column, px.
const SCREEN_MARGIN: int = 24

var _column: FitColumn
var _heading: Label
var _tagline: Label
var _gap: Control
var _utilities: GridContainer
var _utility_buttons: Array[Button] = []
var _quit: Button
var _load: Button
var _continue: Button
var _menu: VBoxContainer
var _menu_scroll: ScrollContainer
var _new_campaign: VBoxContainer
var _picker: DifficultyPicker


func _build() -> void:
	var centre := CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column = FitColumn.new(10)
	_column.outer_margin = SCREEN_MARGIN * 2
	centre.add_child(_column)
	_column.add_child(HudStyle.make_label(12, HudStyle.ACCENT_COLOR, "THE CONCORD SURVEY"))
	_heading = HudStyle.make_label(52, HudStyle.TEXT_COLOR, "Farlanding")
	_column.add_child(_heading)
	_tagline = HudStyle.make_label(
		14, HudStyle.MUTED_COLOR, "Follow the Antecedent trail, world by world"
	)
	_column.add_child(_tagline)
	_gap = Control.new()
	_gap.custom_minimum_size = Vector2(0, 24)
	_column.add_child(_gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 10)
	_menu_scroll = _column.add_scroll(_menu)
	_continue = _add_button(_menu, "CONTINUE", continue_pressed)
	var start: Button = HudStyle.make_menu_button("NEW CAMPAIGN", 280.0)
	_keyboard_button(start)
	start.pressed.connect(show_new_campaign)
	_menu.add_child(start)
	_add_button(_menu, "SINGLE MISSIONS", missions_pressed)
	_load = _add_button(_menu, "LOAD GAME", load_pressed)
	_load.name = &"LoadGame"
	_utilities = GridContainer.new()
	_utilities.columns = 2
	_utilities.add_theme_constant_override(&"h_separation", 10)
	_utilities.add_theme_constant_override(&"v_separation", 8)
	_menu.add_child(_utilities)
	for entry: Array in [
		["HOW TO PLAY", how_to_play_pressed],
		["CONTROLS", controls_pressed],
		["SETTINGS", settings_pressed],
		["CREDITS", credits_pressed]
	]:
		var caption: String = entry[0]
		var action: Signal = entry[1]
		var button: Button = _add_button(_utilities, caption, action)
		button.custom_minimum_size = Vector2(135, 34)
		button.add_theme_font_size_override(&"font_size", 12)
		_utility_buttons.append(button)
	if not OS.has_feature("web"):
		_quit = _add_button(_menu, "QUIT", quit_pressed)
	_new_campaign = VBoxContainer.new()
	_new_campaign.add_theme_constant_override(&"separation", 10)
	_new_campaign.visible = false
	_column.add_child(_new_campaign)
	_new_campaign.add_child(HudStyle.make_label(16, HudStyle.TEXT_COLOR, "New campaign"))
	_picker = DifficultyPicker.new()
	_picker.chosen.connect(
		func(level: StringName) -> void: Settings.set_option(&"difficulty", level)
	)
	_new_campaign.add_child(_picker)
	_new_campaign.add_child(
		HudStyle.make_label(
			11, HudStyle.MUTED_COLOR, "It can be changed aboard the Meridian between landings."
		)
	)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	_new_campaign.add_child(buttons)
	var back: Button = HudStyle.make_menu_button("BACK", 135.0)
	_keyboard_button(back)
	back.pressed.connect(_show_menu)
	buttons.add_child(back)
	_add_button(buttons, "START", new_campaign_pressed).custom_minimum_size = Vector2(135, 40)
	resized.connect(_fit_layout)
	_fit_layout()


## Shows the screen; Continue is offered only when `can_continue`.
func open(can_continue: bool) -> void:
	_continue.disabled = not can_continue
	_continue.visible = can_continue
	_show_menu()
	visible = true
	Events.ui_feedback.emit(&"title_open")


## New campaign: the difficulty choice, then START.
func show_new_campaign() -> void:
	Events.ui_feedback.emit(&"click")
	_picker.set_level(Settings.difficulty)
	_menu_scroll.visible = false
	_new_campaign.visible = true


## The difficulty choice of New campaign (tests).
func picker() -> DifficultyPicker:
	return _picker


func _show_menu() -> void:
	_new_campaign.visible = false
	_menu_scroll.visible = true


func _add_button(column: Container, caption: String, pressed: Signal) -> Button:
	var button: Button = HudStyle.make_menu_button(caption, 280.0)
	_keyboard_button(button)
	button.pressed.connect(
		func() -> void:
			Events.ui_feedback.emit(&"click")
			pressed.emit()
	)
	column.add_child(button)
	return button


func _keyboard_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override(&"focus", HudStyle.button_style(&"hover"))


## Keep the title airy on large displays and fully usable at 648px/130% UI.
## FitColumn retains an emergency scrolling fallback for unusually short windows.
func _fit_layout() -> void:
	if _heading == null:
		return
	var height: float = get_viewport_rect().size.y
	var compact: bool = height < 600.0
	_heading.add_theme_font_size_override(&"font_size", 40 if compact else 52)
	_tagline.visible = height >= 450.0
	_gap.custom_minimum_size.y = 12.0 if compact else 24.0
	_column.separation = 6 if compact else 10
	_menu.add_theme_constant_override(&"separation", 6 if compact else 10)
	for node: Node in _menu.get_children():
		var button: Button = node as Button
		if button != null:
			button.custom_minimum_size.y = 36.0 if compact else 40.0
	for button: Button in _utility_buttons:
		button.custom_minimum_size.y = 30.0 if compact else 34.0
	if _quit != null:
		_quit.custom_minimum_size.y = 30.0 if compact else 36.0
