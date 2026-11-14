class_name KeyBindingsPage
extends VBoxContainer
## The settings' KEYS page: every rebindable action (KeyBindings.ACTIONS) by
## category, with its key under the mouse scheme in use. Click a key, then press the
## new one (Esc cancels). A key another action uses is not taken silently: the line
## below says which action has it, and pressing the same key again swaps the two.
## RESET restores this scheme's defaults. Everything goes through `Settings`, which
## saves the bindings in the user settings file.

## Shown while nothing is being rebound.
const IDLE_NOTE: String = "Click a key to change it. Esc always pauses and cancels."

## The action waiting for its new key, or &"".
var listening: StringName = &""

var _buttons: Dictionary[StringName, Button] = {}
var _scheme_note: Label
var _status: Label
## The key that clashed last (pressing it again swaps), or "".
var _clash_code: String = ""


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 10)
	add_child(top)
	_scheme_note = HudStyle.make_label(12, HudStyle.TEXT_COLOR)
	_scheme_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_scheme_note)
	var reset: Button = HudStyle.make_small_button("RESET TO DEFAULTS")
	reset.pressed.connect(reset_to_defaults)
	top.add_child(reset)
	_status = HudStyle.make_label(12, HudStyle.MUTED_COLOR, IDLE_NOTE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 34)
	add_child(_status)
	var category: String = ""
	for entry: Array in KeyBindings.ACTIONS:
		var action: StringName = entry[0]
		var group: String = entry[2]
		if group != category:
			category = group
			add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, category))
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		var title: String = entry[1]
		var label: Label = HudStyle.make_label(13, HudStyle.TEXT_COLOR, title)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button: Button = HudStyle.make_small_button("")
		button.custom_minimum_size = Vector2(150, 26)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(listen.bind(action))
		row.add_child(button)
		add_child(row)
		_buttons[action] = button
	refresh()


func _input(event: InputEvent) -> void:
	if listening == &"" or not is_visible_in_tree():
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.keycode == KEY_ESCAPE:
		cancel()
		return
	press_key(key)


## Waits for the new key of `action`.
func listen(action: StringName) -> void:
	listening = action
	_clash_code = ""
	_say("%s: press the new key (Esc cancels)." % KeyBindings.title_of(action), false)
	refresh()
	Events.ui_feedback.emit(&"rebind_listen")


## Stops waiting for a key; nothing changes.
func cancel() -> void:
	listening = &""
	_clash_code = ""
	_say(IDLE_NOTE, false)
	refresh()


## The key `key` was pressed while listening: bound, refused, or (taken by another
## action) explained, and bound with a swap when it is pressed again.
func press_key(key: InputEventKey) -> void:
	if listening == &"":
		return
	var code: String = KeyBindings.code_of(key)
	var swap: bool = code != "" and code == _clash_code
	var action: StringName = listening
	var taken_by: StringName = Settings.rebind(action, key, swap)
	if taken_by == &"":
		listening = &""
		_clash_code = ""
		_say("%s is now %s." % [KeyBindings.title_of(action), KeyBindings.code_label(code)], false)
		Events.ui_feedback.emit(&"rebind_done")
	elif taken_by == KeyBindings.INVALID:
		_say("That key cannot be bound. Press another (Esc cancels).", true)
		Events.ui_feedback.emit(&"rebind_conflict")
	else:
		_clash_code = code
		_say(
			(
				(
					'%s is already used by "%s". Press %s again to swap the two keys, or'
					+ " press another key (Esc cancels)."
				)
				% [
					KeyBindings.code_label(code),
					KeyBindings.title_of(taken_by),
					KeyBindings.code_label(code)
				]
			),
			true
		)
		Events.ui_feedback.emit(&"rebind_conflict")
	refresh()


## Every key of the scheme in use back on its default.
func reset_to_defaults() -> void:
	listening = &""
	_clash_code = ""
	Settings.reset_bindings()
	_say("The %s scheme's keys are back on their defaults." % _scheme_name(), false)
	refresh()
	Events.ui_feedback.emit(&"rebind_done")


## Shows the current keys.
func refresh() -> void:
	_scheme_note.text = "Keys for the %s mouse scheme (changed under GENERAL)" % _scheme_name()
	for action: StringName in _buttons:
		var button: Button = _buttons[action]
		if action == listening:
			button.text = "PRESS A KEY…"
			button.add_theme_color_override(&"font_color", HudStyle.ACCENT_COLOR)
		else:
			button.text = KeyBindings.code_label(
				Settings.bindings.binding(Settings.control_scheme, action)
			)
			button.add_theme_color_override(&"font_color", HudStyle.TEXT_COLOR)


## The button of `action` (tests).
func button_for(action: StringName) -> Button:
	return _buttons.get(action)


## The message line now (tests).
func status_text() -> String:
	return _status.text


func _say(text: String, problem: bool) -> void:
	_status.text = ("⚠ " if problem else "") + text
	_status.add_theme_color_override(
		&"font_color", HudStyle.WARNING_COLOR if problem else HudStyle.MUTED_COLOR
	)


static func _scheme_name() -> String:
	return "classic" if Settings.control_scheme == Settings.SCHEME_CLASSIC else "modern"
