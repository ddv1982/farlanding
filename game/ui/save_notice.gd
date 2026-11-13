class_name SaveNotice
extends Label
## A short line at the top of the screen after a quicksave or quickload (F5 / F9):
## "Game saved", or why a save or load failed. Fades out after a few seconds.

const SECONDS: float = 2.5
const FADE: float = 0.5

var _left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_top = 64.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override(&"font_size", 16)
	add_theme_constant_override(&"outline_size", 6)
	add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	modulate.a = clampf(_left / FADE, 0.0, 1.0)
	if _left <= 0.0:
		visible = false


## Shows `text` (in the warning colour when `failed`).
func show_text(text: String, failed: bool = false) -> void:
	self.text = text
	add_theme_color_override(
		&"font_color", HudStyle.WARNING_COLOR if failed else HudStyle.TEXT_COLOR
	)
	_left = SECONDS
	modulate.a = 1.0
	visible = true
