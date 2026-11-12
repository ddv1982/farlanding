class_name SelectionBox
extends Control
## Draws the drag rectangle while box-selecting.

const FILL: Color = Color(0.45, 0.75, 1.0, 0.12)
const OUTLINE: Color = Color(0.6, 0.85, 1.0, 0.9)

var _rect: Rect2 = Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_rect(rect: Rect2) -> void:
	_rect = rect.abs()
	visible = true
	queue_redraw()


func hide_rect() -> void:
	visible = false


func _draw() -> void:
	draw_rect(_rect, FILL, true)
	draw_rect(_rect, OUTLINE, false, 1.5)
