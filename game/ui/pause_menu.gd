class_name PauseMenu
extends Control
## The in-mission menu (Esc or the HUD's MENU button): Resume, Settings, Restart and
## Quit to missions over a dimmed map. It takes every click and key while open (the
## map behind it cannot be ordered about); Main pauses the sim clock and the camera.
## Esc closes it (or, with the settings open, the settings).

signal resume_pressed
signal settings_pressed
signal restart_pressed
signal quit_pressed

const DIM := Color(0.02, 0.025, 0.035, 0.6)
const MENU_ACTIONS: Array[StringName] = [
	&"ui_left",
	&"ui_right",
	&"ui_up",
	&"ui_down",
	&"ui_accept",
	&"ui_focus_next",
	&"ui_focus_prev",
]

var _title: Label
var _quit: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = HudStyle.make_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(300, 0)
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)
	column.add_child(HudStyle.make_label(11, HudStyle.ACCENT_COLOR, "PAUSED"))
	_title = HudStyle.make_label(22, HudStyle.TEXT_COLOR, "")
	column.add_child(_title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)
	column.add_child(_button("RESUME  (Esc)", resume_pressed))
	column.add_child(_button("SETTINGS", settings_pressed))
	column.add_child(_button("RESTART MISSION", restart_pressed))
	_quit = _button("QUIT TO MISSIONS", quit_pressed)
	column.add_child(_quit)
	visible = false


## Opens over the mission titled `title`; `quit_text` names where Quit goes.
func open(title: String, quit_text: String = "QUIT TO MISSIONS") -> void:
	_title.text = title
	_quit.text = quit_text
	visible = true


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return
	# Nothing reaches the map while paused; Esc resumes (the settings close first).
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE and _settings_hidden():
		resume_pressed.emit()
		get_viewport().set_input_as_handled()
	elif _settings_hidden() or not _is_menu_key(key):
		get_viewport().set_input_as_handled()


## Keys the settings panel itself needs: Esc (it closes) and moving through its
## controls. Every other key would be a gameplay shortcut reaching the paused map.
static func _is_menu_key(key: InputEventKey) -> bool:
	if key.keycode == KEY_ESCAPE:
		return true
	for action: StringName in MENU_ACTIONS:
		if key.is_action(action):
			return true
	return false


func _settings_hidden() -> bool:
	for sibling: Node in get_parent().get_children():
		var settings: SettingsPanel = sibling as SettingsPanel
		if settings != null and settings.visible:
			return false
	return true


func _button(caption: String, pressed: Signal) -> Button:
	var button: Button = HudStyle.make_small_button(caption)
	button.custom_minimum_size = Vector2(300, 38)
	button.add_theme_font_size_override(&"font_size", 13)
	button.pressed.connect(func() -> void: pressed.emit())
	return button
