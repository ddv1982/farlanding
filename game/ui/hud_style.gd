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
const INTEL_COLOR := Color(0.62, 1.0, 0.78)
const BUTTON_COLOR := Color(0.10, 0.125, 0.15, 0.95)
const BUTTON_HOVER_COLOR := Color(0.15, 0.19, 0.23, 0.98)
## Campaign screens: route node and tech states.
const LOCKED_COLOR := Color(0.36, 0.40, 0.45)
const OPEN_COLOR := Color(0.93, 0.36, 0.05)
const WON_COLOR := Color(0.55, 0.95, 0.65)
const CURRENT_COLOR := Color(1.0, 0.92, 0.55)
const AVAILABLE_COLOR := Color(0.70, 0.76, 0.82)
const LINK_COLOR := Color(0.62, 0.68, 0.74, 0.45)
const MARGIN := 14
const ICON_SIZE := 52


## A dark panel with the orange accent along its top edge.
static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## The panels' look: dark, the orange accent along the top edge.
static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = ACCENT_COLOR
	style.border_width_top = 2
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10)
	return style


## The same panel without see-through: for screens that open over other panels.
static func solid_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = panel_style()
	style.bg_color = Color(PANEL_COLOR, 1.0)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	return style


## A full-screen darkening that is light in the middle and heavy at the edges, so
## a 3D scene behind a menu stays visible without fighting the text.
static func make_vignette() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray(
		[
			Color(0.02, 0.03, 0.045, 0.5),
			Color(0.02, 0.03, 0.045, 0.62),
			Color(0.01, 0.015, 0.025, 0.94)
		]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


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


## A small text button for the HUD's corners (codex, control scheme).
static func make_small_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 11)
	button.add_theme_color_override(&"font_color", TEXT_COLOR)
	button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	for state: StringName in [&"normal", &"pressed", &"focus"]:
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


## Colour of a campaign route node or tech in `state` (CampaignState states).
static func campaign_state_color(state: StringName) -> Color:
	match state:
		&"open", &"affordable":
			return OPEN_COLOR
		&"won", &"owned":
			return WON_COLOR
		&"available":
			return AVAILABLE_COLOR
	return LOCKED_COLOR


## The icon at `path` when it exists (the lead draws them from the data), else null:
## callers then show a plain placeholder.
static func optional_icon(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## A square icon of `size`: the texture at `path`, or a plain placeholder swatch with
## `letter` in `color` when it does not exist yet.
static func make_icon(path: String, size: float, color: Color, letter: String) -> Control:
	var texture: Texture2D = optional_icon(path)
	if texture != null:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(size, size)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	var swatch := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.18)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(size / 2.0))
	swatch.add_theme_stylebox_override(&"panel", style)
	swatch.custom_minimum_size = Vector2(size, size)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = make_label(int(size * 0.4), color, letter)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	swatch.add_child(label)
	return swatch


## A wide text button for menus (title screen, campaign screens).
static func make_menu_button(caption: String, width: float = 240.0) -> Button:
	var button: Button = make_small_button(caption)
	button.custom_minimum_size = Vector2(width, 40)
	button.add_theme_font_size_override(&"font_size", 14)
	button.add_theme_color_override(&"font_disabled_color", Color(MUTED_COLOR, 0.5))
	button.add_theme_stylebox_override(&"disabled", _button_style(Color(BUTTON_COLOR, 0.5)))
	return button


static func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	# The border is the fill colour lightened, at the fill's own alpha. A see-through
	# white border stacks on the fill where the two meet in the rounded corners and
	# shows there as bright specks.
	style.border_color = color.lightened(0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style
