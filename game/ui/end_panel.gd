class_name EndPanel
extends CenterContainer
## Shown when the mission ends: "Victory" or "Defeat", one line on why, and a
## "Play again" button that reloads the map. Listens to `Events.mission_ended`.

const VICTORY_TEXT: String = "Every Combine unit and structure here is destroyed."
const DEFEAT_TEXT: String = "The Lander is lost."

var _title: Label
var _reason: Label
var _button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: PanelContainer = HudStyle.make_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	_title = HudStyle.make_label(40, HudStyle.TEXT_COLOR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_reason = HudStyle.make_label(14, HudStyle.MUTED_COLOR)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_reason)
	_button = HudStyle.make_button(null, "Play again")
	_button.custom_minimum_size = Vector2(180, 44)
	_button.add_theme_font_size_override(&"font_size", 16)
	_button.pressed.connect(_on_play_again)
	column.add_child(_button)
	visible = false
	Events.mission_ended.connect(show_result)


## Shows the panel for a won (`true`) or lost mission.
func show_result(won: bool) -> void:
	_title.text = "Victory" if won else "Defeat"
	_title.add_theme_color_override(
		&"font_color", HudStyle.ACCENT_COLOR if won else HudStyle.WARNING_COLOR
	)
	_reason.text = VICTORY_TEXT if won else DEFEAT_TEXT
	visible = true


func _on_play_again() -> void:
	Events.ui_feedback.emit(&"click")
	get_tree().reload_current_scene()
