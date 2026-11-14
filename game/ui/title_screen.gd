class_name TitleScreen
extends MenuScreen
## The first screen: Continue (when an autosave exists), New campaign, Single missions
## (the mission select), How to play, Settings, Credits and Quit. New campaign first
## asks for the difficulty (remembered in the settings for next time); START emits
## `new_campaign_pressed`.

signal new_campaign_pressed
signal continue_pressed
signal missions_pressed
signal settings_pressed
signal quit_pressed
signal how_to_play_pressed
signal credits_pressed

var _continue: Button
var _menu: VBoxContainer
var _new_campaign: VBoxContainer
var _picker: DifficultyPicker


func _build() -> void:
	var centre := CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	centre.add_child(column)
	column.add_child(HudStyle.make_label(12, HudStyle.ACCENT_COLOR, "THE CONCORD SURVEY"))
	column.add_child(HudStyle.make_label(52, HudStyle.TEXT_COLOR, "Farlanding"))
	column.add_child(
		HudStyle.make_label(14, HudStyle.MUTED_COLOR, "Follow the Antecedent trail, world by world")
	)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	column.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 10)
	column.add_child(_menu)
	_continue = _add_button(_menu, "CONTINUE", continue_pressed)
	var start: Button = HudStyle.make_menu_button("NEW CAMPAIGN", 280.0)
	start.pressed.connect(show_new_campaign)
	_menu.add_child(start)
	_add_button(_menu, "SINGLE MISSIONS", missions_pressed)
	_add_button(_menu, "HOW TO PLAY", how_to_play_pressed)
	_add_button(_menu, "SETTINGS", settings_pressed)
	_add_button(_menu, "CREDITS", credits_pressed)
	_add_button(_menu, "QUIT", quit_pressed)
	_new_campaign = VBoxContainer.new()
	_new_campaign.add_theme_constant_override(&"separation", 10)
	_new_campaign.visible = false
	column.add_child(_new_campaign)
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
	back.pressed.connect(_show_menu)
	buttons.add_child(back)
	_add_button(buttons, "START", new_campaign_pressed).custom_minimum_size = Vector2(135, 40)


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
	_menu.visible = false
	_new_campaign.visible = true


## The difficulty choice of New campaign (tests).
func picker() -> DifficultyPicker:
	return _picker


func _show_menu() -> void:
	_new_campaign.visible = false
	_menu.visible = true


func _add_button(column: BoxContainer, caption: String, pressed: Signal) -> Button:
	var button: Button = HudStyle.make_menu_button(caption, 280.0)
	button.pressed.connect(
		func() -> void:
			Events.ui_feedback.emit(&"click")
			pressed.emit()
	)
	column.add_child(button)
	return button
