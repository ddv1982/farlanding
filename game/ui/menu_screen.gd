class_name MenuScreen
extends Control
## A full-screen menu page (title, star map, Meridian): a plain background, or the
## vignette when a backdrop scene plays behind it. Subclasses build their content in
## `_build()`.

var _back: ColorRect
var _vignette: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back = ColorRect.new()
	_back.color = MissionSelect.BACKGROUND
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette = HudStyle.make_vignette()
	_vignette.visible = false
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


## Lets a backdrop scene show through (or not).
func set_see_through(enabled: bool) -> void:
	if _back != null:
		_back.visible = not enabled
		_vignette.visible = enabled


## Builds the page's controls (called once, from `_ready`).
func _build() -> void:
	pass


## A margin container filling the screen, `margin` px in from every edge.
func _make_frame(margin: int) -> MarginContainer:
	var frame := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, margin)
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return frame
