class_name GraphicsUpgradePrompt
extends Control
## A one-time choice for profiles that may have inherited the old Web downgrade.

signal use_high_pressed
signal keep_current_pressed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.88)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre: CenterContainer = CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = HudStyle.make_panel()
	centre.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 430
	column.add_theme_constant_override(&"separation", 14)
	panel.add_child(column)
	column.add_child(HudStyle.make_label(24, HudStyle.TEXT_COLOR, "Sharper graphics are available"))
	var text: Label = HudStyle.make_label(
		14,
		HudStyle.MUTED_COLOR,
		(
			"Try full-resolution rendering, clearer edges, shadows and glow.\n"
			+ "Your controls, audio and progress stay as they are."
		)
	)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 430
	column.add_child(text)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 12)
	column.add_child(buttons)
	var keep: Button = HudStyle.make_small_button("KEEP CURRENT")
	keep.pressed.connect(func() -> void: keep_current_pressed.emit())
	buttons.add_child(keep)
	var high: Button = HudStyle.make_small_button("USE HIGH GRAPHICS")
	high.pressed.connect(func() -> void: use_high_pressed.emit())
	buttons.add_child(high)
	high.grab_focus()
