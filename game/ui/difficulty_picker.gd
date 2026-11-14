class_name DifficultyPicker
extends VBoxContainer
## Easy / Normal / Hard as three buttons (the chosen one marked in the accent colour
## and with a "»" in front, so it does not rest on colour alone) and a line saying what
## the level changes. Used by the title's New campaign, the mission select and the
## Meridian. `chosen` reports a pick; `set_level` shows a level without reporting.

signal chosen(level: StringName)

var level: StringName = Difficulty.NORMAL

var _buttons: Dictionary[StringName, Button] = {}
var _description: Label


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	add_child(row)
	row.add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, "DIFFICULTY"))
	for id: StringName in Difficulty.LEVELS:
		var button: Button = HudStyle.make_small_button(Difficulty.label(id).to_upper())
		button.custom_minimum_size = Vector2(96, 30)
		button.pressed.connect(_on_pressed.bind(id))
		row.add_child(button)
		_buttons[id] = button
	_description = HudStyle.make_label(11, HudStyle.MUTED_COLOR)
	add_child(_description)
	set_level(level)


## Shows `p_level` as the chosen one (without emitting `chosen`).
func set_level(p_level: StringName) -> void:
	level = Difficulty.sanitize(p_level)
	for id: StringName in _buttons:
		var button: Button = _buttons[id]
		var picked: bool = id == level
		button.text = ("» " if picked else "") + Difficulty.label(id).to_upper()
		button.add_theme_color_override(
			&"font_color", HudStyle.ACCENT_COLOR if picked else HudStyle.TEXT_COLOR
		)
	_description.text = Difficulty.DESCRIPTIONS.get(level, "")


## The button for `id` (tests).
func button_for(id: StringName) -> Button:
	return _buttons.get(id)


func _on_pressed(id: StringName) -> void:
	Events.ui_feedback.emit(&"toggle")
	set_level(id)
	chosen.emit(id)
