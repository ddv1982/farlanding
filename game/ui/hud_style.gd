class_name HudStyle
extends RefCounted
## The HUD's shared look: one small set of colours, panels, labels and buttons, so
## every panel reads as the same survey-instrument family.

const PANEL_COLOR := Color(0.055, 0.07, 0.09, 0.84)
const ACCENT_COLOR := Color(0.93, 0.36, 0.05)
const TEXT_COLOR := Color(0.90, 0.92, 0.94)
const MUTED_COLOR := Color(0.62, 0.68, 0.74)
const WARNING_COLOR := Color(1.0, 0.42, 0.25)
const ALLOY_COLOR := Color(0.80, 0.84, 0.90)
const FLUX_COLOR := Color(0.45, 0.85, 1.0)
const POWER_COLOR := Color(1.0, 0.82, 0.35)
const BUTTON_COLOR := Color(0.10, 0.125, 0.15, 0.95)
const BUTTON_HOVER_COLOR := Color(0.15, 0.19, 0.23, 0.98)
const MARGIN := 14
const ICON_SIZE := 52


## A dark panel with the orange accent along its top edge.
static func make_panel() -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = ACCENT_COLOR
	style.border_width_top = 2
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


static func make_label(font_size: int, color: Color, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A square command button: icon on top, caption lines below.
static func make_button(icon: Texture2D, caption: String) -> Button:
	var button := Button.new()
	button.icon = icon
	button.text = caption
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.custom_minimum_size = Vector2(96, 104)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 11)
	button.add_theme_color_override(&"font_color", TEXT_COLOR)
	button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	button.add_theme_color_override(&"font_disabled_color", MUTED_COLOR)
	button.add_theme_constant_override(&"icon_max_width", ICON_SIZE)
	for state: StringName in [&"normal", &"pressed", &"disabled", &"focus"]:
		button.add_theme_stylebox_override(state, _button_style(BUTTON_COLOR))
	button.add_theme_stylebox_override(&"hover", _button_style(BUTTON_HOVER_COLOR))
	return button


## A thin progress bar in the accent colour.
static func make_progress_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)
	bar.min_value = 0.0
	bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT_COLOR
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	bar.add_theme_stylebox_override(&"fill", fill)
	bar.add_theme_stylebox_override(&"background", back)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## "120 Alloy", "300 Alloy · 50 Flux", or "Free".
static func cost_text(def: EntityDef) -> String:
	var parts: PackedStringArray = []
	if def.cost_alloy > 0:
		parts.append("%d Alloy" % def.cost_alloy)
	if def.cost_flux > 0:
		parts.append("%d Flux" % def.cost_flux)
	return " · ".join(parts) if not parts.is_empty() else "Free"


static func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style
