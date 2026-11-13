class_name TitleScreen
extends MenuScreen
## The first screen: New campaign, Continue (when an autosave exists), Single missions
## (the mission select), Settings and Quit.

signal new_campaign_pressed
signal continue_pressed
signal missions_pressed
signal settings_pressed
signal quit_pressed

var _continue: Button


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
	_continue = _add_button(column, "CONTINUE", continue_pressed)
	_add_button(column, "NEW CAMPAIGN", new_campaign_pressed)
	_add_button(column, "SINGLE MISSIONS", missions_pressed)
	_add_button(column, "SETTINGS", settings_pressed)
	_add_button(column, "QUIT", quit_pressed)


## Shows the screen; Continue is offered only when `can_continue`.
func open(can_continue: bool) -> void:
	_continue.disabled = not can_continue
	_continue.visible = can_continue
	visible = true
	Events.ui_feedback.emit(&"title_open")


func _add_button(column: VBoxContainer, caption: String, pressed: Signal) -> Button:
	var button: Button = HudStyle.make_menu_button(caption, 280.0)
	button.pressed.connect(
		func() -> void:
			Events.ui_feedback.emit(&"click")
			pressed.emit()
	)
	column.add_child(button)
	return button
