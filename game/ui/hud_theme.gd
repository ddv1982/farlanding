class_name HudTheme
extends RefCounted
## The theme every control starts from: the game's typeface and the field-kit look for
## the stock controls that HudStyle's helpers do not build (lists, sliders, switches,
## drop-downs, scroll bars, tooltips). The UiTheme autoload applies it everywhere.

const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.10)
const SWITCH_SIZE := Vector2i(38, 18)
const GRABBER_SIZE: int = 14


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = HudStyle.font(HudStyle.FONT_BODY)
	theme.set_color(&"font_color", &"Label", HudStyle.TEXT_COLOR)
	_buttons(theme, &"Button")
	_buttons(theme, &"OptionButton")
	_buttons(theme, &"CheckButton")
	theme.set_stylebox(&"normal", &"CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox(&"hover", &"CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox(&"pressed", &"CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox(&"hover_pressed", &"CheckButton", StyleBoxEmpty.new())
	theme.set_icon(&"checked", &"CheckButton", switch_icon(true))
	theme.set_icon(&"unchecked", &"CheckButton", switch_icon(false))
	_slider(theme)
	_scroll_bar(theme, &"VScrollBar")
	_scroll_bar(theme, &"HScrollBar")
	_list(theme)
	_popup(theme)
	var tip: PlateStyle = HudStyle.panel_style(8)
	tip.fill = Color(HudStyle.PANEL_COLOR, 0.97)
	tip.marker = Color.TRANSPARENT
	theme.set_stylebox(&"panel", &"TooltipPanel", tip)
	theme.set_color(&"font_color", &"TooltipLabel", HudStyle.TEXT_COLOR)
	theme.set_font_size(&"font_size", &"TooltipLabel", 12)
	return theme


## The on/off switch drawn for a CheckButton: a cut track with a square knob.
static func switch_icon(on: bool) -> ImageTexture:
	var image := Image.create(SWITCH_SIZE.x, SWITCH_SIZE.y, false, Image.FORMAT_RGBA8)
	var track: Color = Color(HudStyle.ACCENT_COLOR, 0.35) if on else TRACK_COLOR
	image.fill_rect(Rect2i(0, 3, SWITCH_SIZE.x, SWITCH_SIZE.y - 6), track)
	var knob: Color = HudStyle.ACCENT_COLOR if on else HudStyle.MUTED_COLOR
	var left: int = SWITCH_SIZE.x - SWITCH_SIZE.y if on else 0
	image.fill_rect(Rect2i(left + 2, 0, SWITCH_SIZE.y - 4, SWITCH_SIZE.y), knob)
	return ImageTexture.create_from_image(image)


## The slider's handle: a small diamond.
static func grabber_icon(color: Color) -> ImageTexture:
	var image := Image.create(GRABBER_SIZE, GRABBER_SIZE, false, Image.FORMAT_RGBA8)
	var half: float = (GRABBER_SIZE - 1) / 2.0
	for y: int in GRABBER_SIZE:
		for x: int in GRABBER_SIZE:
			if absf(x - half) + absf(y - half) <= half:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


static func _buttons(theme: Theme, type: StringName) -> void:
	theme.set_font(&"font", type, HudStyle.font(HudStyle.FONT_BUTTON))
	theme.set_color(&"font_color", type, HudStyle.TEXT_COLOR)
	theme.set_color(&"font_hover_color", type, Color.WHITE)
	theme.set_color(&"font_pressed_color", type, HudStyle.ACCENT_COLOR)
	theme.set_color(&"font_hover_pressed_color", type, HudStyle.ACCENT_COLOR)
	theme.set_color(&"font_focus_color", type, HudStyle.TEXT_COLOR)
	theme.set_color(&"font_disabled_color", type, Color(HudStyle.MUTED_COLOR, 0.5))
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		theme.set_stylebox(state, type, HudStyle.button_style(state))
	theme.set_stylebox(&"focus", type, StyleBoxEmpty.new())


static func _slider(theme: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK_COLOR
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var filled: StyleBoxFlat = track.duplicate()
	filled.bg_color = Color(HudStyle.ACCENT_COLOR, 0.7)
	theme.set_stylebox(&"slider", &"HSlider", track)
	theme.set_stylebox(&"grabber_area", &"HSlider", filled)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", filled)
	theme.set_icon(&"grabber", &"HSlider", grabber_icon(HudStyle.TEXT_COLOR))
	theme.set_icon(&"grabber_highlight", &"HSlider", grabber_icon(HudStyle.ACCENT_COLOR))
	theme.set_icon(&"grabber_disabled", &"HSlider", grabber_icon(HudStyle.LOCKED_COLOR))


static func _scroll_bar(theme: Theme, type: StringName) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.04)
	track.set_content_margin_all(3)
	theme.set_stylebox(&"scroll", type, track)
	for state: StringName in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = HudStyle.LINE_COLOR if state == &"grabber" else HudStyle.ACCENT_COLOR
		theme.set_stylebox(state, type, grabber)


static func _list(theme: Theme) -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.22)
	back.set_content_margin_all(4)
	theme.set_stylebox(&"panel", &"ItemList", back)
	theme.set_stylebox(&"focus", &"ItemList", StyleBoxEmpty.new())
	var chosen := StyleBoxFlat.new()
	chosen.bg_color = Color(HudStyle.ACCENT_COLOR, 0.16)
	chosen.border_color = HudStyle.ACCENT_COLOR
	chosen.border_width_left = 2
	theme.set_stylebox(&"selected", &"ItemList", chosen)
	theme.set_stylebox(&"selected_focus", &"ItemList", chosen)
	var hovered := StyleBoxFlat.new()
	hovered.bg_color = Color(1, 1, 1, 0.05)
	theme.set_stylebox(&"hovered", &"ItemList", hovered)
	theme.set_color(&"font_color", &"ItemList", HudStyle.MUTED_COLOR)
	theme.set_color(&"font_hovered_color", &"ItemList", HudStyle.TEXT_COLOR)
	theme.set_color(&"font_selected_color", &"ItemList", Color.WHITE)


static func _popup(theme: Theme) -> void:
	var panel: PlateStyle = HudStyle.panel_style(6)
	panel.fill = Color(HudStyle.PANEL_COLOR, 0.98)
	panel.marker = Color.TRANSPARENT
	theme.set_stylebox(&"panel", &"PopupMenu", panel)
	var hovered := StyleBoxFlat.new()
	hovered.bg_color = Color(HudStyle.ACCENT_COLOR, 0.16)
	theme.set_stylebox(&"hover", &"PopupMenu", hovered)
	theme.set_color(&"font_color", &"PopupMenu", HudStyle.TEXT_COLOR)
	theme.set_color(&"font_hover_color", &"PopupMenu", Color.WHITE)
	theme.set_font_size(&"font_size", &"PopupMenu", 12)
