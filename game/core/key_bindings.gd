class_name KeyBindings
extends RefCounted
## The rebindable keyboard actions and the player's bindings for them, kept per
## mouse scheme (Settings owns one and saves it in `user://settings.cfg`, never in
## project.godot). Every action has one key. `install()` makes sure each action
## exists in the InputMap (some are not in project.godot: the editor rewrites that
## file, so it is left alone); `apply()` puts the bindings of one scheme into it.
##
## A binding is a short code: "k<keycode>" (the key with that label) or
## "p<physical keycode>" (the key in that place, whatever the layout). Defaults use
## physical keys for WASD, Q/E, X and the number row, labels elsewhere. Esc is never
## bindable (it always backs out, cancels and pauses), nor are modifier keys alone.

const CAMERA: String = "CAMERA"
const ORDERS: String = "ORDERS AND SELECTION"
const GROUPS: String = "CONTROL GROUPS"
const GAME: String = "GAME"
## Every rebindable action: id, label, category, default binding.
const ACTIONS: Array[Array] = [
	[&"camera_pan_forward", "Pan forward", CAMERA, "k4194320"],
	[&"camera_pan_back", "Pan back", CAMERA, "k4194322"],
	[&"camera_pan_left", "Pan left", CAMERA, "k4194319"],
	[&"camera_pan_right", "Pan right", CAMERA, "k4194321"],
	[&"camera_pan_forward_alt", "Pan forward (second key)", CAMERA, "p87"],
	[&"camera_pan_back_alt", "Pan back (second key)", CAMERA, "p83"],
	[&"camera_pan_left_alt", "Pan left (second key)", CAMERA, "p65"],
	[&"camera_pan_right_alt", "Pan right (second key)", CAMERA, "p68"],
	[&"camera_rotate_left", "Turn left", CAMERA, "p81"],
	[&"camera_rotate_right", "Turn right", CAMERA, "p69"],
	[&"order_stop", "Stop", ORDERS, "p88"],
	[&"control_group_1", "Group 1", GROUPS, "p49"],
	[&"control_group_2", "Group 2", GROUPS, "p50"],
	[&"control_group_3", "Group 3", GROUPS, "p51"],
	[&"control_group_4", "Group 4", GROUPS, "p52"],
	[&"control_group_5", "Group 5", GROUPS, "p53"],
	[&"control_group_6", "Group 6", GROUPS, "p54"],
	[&"control_group_7", "Group 7", GROUPS, "p55"],
	[&"control_group_8", "Group 8", GROUPS, "p56"],
	[&"control_group_9", "Group 9", GROUPS, "p57"],
	[&"pause_menu", "Pause menu (Esc also works)", GAME, "k80"],
	[&"quicksave", "Quicksave", GAME, "k4194336"],
	[&"quickload", "Quickload", GAME, "k4194340"],
	[&"codex", "Codex", GAME, "k67"],
	[&"controls_help", "Controls panel", GAME, "k4194332"],
	[&"debug_overlay", "Debug overlay", GAME, "k4194334"],
]
## Number of control groups (control_group_1 ..).
const GROUP_COUNT: int = 9
const SECTION_PREFIX: String = "keys_"
## Returned by `conflict()` for a key that may not be bound at all.
const INVALID: StringName = &"<invalid>"

## Scheme -> action -> binding code; only bindings that differ from the default.
var overrides: Dictionary[StringName, Dictionary] = {}


## Makes sure every action exists in the InputMap.
static func install() -> void:
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)


## Puts the bindings of `scheme` into the InputMap.
func apply(scheme: StringName) -> void:
	install()
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		InputMap.action_erase_events(action)
		var event: InputEventKey = event_of(binding(scheme, action))
		if event != null:
			InputMap.action_add_event(action, event)


## The binding code of `action` under `scheme`.
func binding(scheme: StringName, action: StringName) -> String:
	var scheme_overrides: Dictionary = overrides.get(scheme, {})
	if scheme_overrides.has(action):
		return scheme_overrides[action]
	return default_of(action)


## The action other than `action` that already uses `code` under `scheme`, &"" when
## the key is free, or INVALID when it may not be bound.
func conflict(scheme: StringName, action: StringName, code: String) -> StringName:
	if event_of(code) == null:
		return INVALID
	for entry: Array in ACTIONS:
		var other: StringName = entry[0]
		if other != action and same_key(binding(scheme, other), code):
			return other
	return &""


## Binds `action` to `code` under `scheme`. An action that used that key gets the
## key `action` had (a swap). False (nothing changed) for an invalid key.
func bind(scheme: StringName, action: StringName, code: String) -> bool:
	if not has_action(action) or event_of(code) == null:
		return false
	var previous: String = binding(scheme, action)
	var taken_by: StringName = conflict(scheme, action, code)
	_put(scheme, action, code)
	if taken_by != &"" and taken_by != INVALID:
		_put(scheme, taken_by, previous)
	return true


## Every action of `scheme` back on its default key.
func reset(scheme: StringName) -> void:
	overrides.erase(scheme)


## Writes the overrides into `config` (one section per scheme).
func save_into(config: ConfigFile) -> void:
	for scheme: StringName in overrides:
		var scheme_overrides: Dictionary = overrides[scheme]
		for action: Variant in scheme_overrides:
			config.set_value(SECTION_PREFIX + String(scheme), str(action), scheme_overrides[action])


## Reads the overrides of `schemes` from `config`; unknown actions and unreadable
## keys are skipped, and when two actions end up on one key the overrides involved
## are dropped until every key is used once.
func load_from(config: ConfigFile, schemes: Array[StringName]) -> void:
	overrides.clear()
	for scheme: StringName in schemes:
		var section: String = SECTION_PREFIX + String(scheme)
		if not config.has_section(section):
			continue
		for key: String in config.get_section_keys(section):
			var value: Variant = config.get_value(section, key, "")
			var code: String = str(value)
			var action: StringName = StringName(key)
			if has_action(action) and event_of(code) != null:
				_put(scheme, action, code)
		_drop_clashes(scheme)


## The code for the key of `event`, or "" when it cannot be bound (Esc, a modifier
## alone, no key at all).
static func code_of(event: InputEventKey) -> String:
	if event == null:
		return ""
	var code: String = (
		"k%d" % event.keycode
		if event.keycode != KEY_NONE
		else ("p%d" % event.physical_keycode if event.physical_keycode != KEY_NONE else "")
	)
	return code if event_of(code) != null else ""


## A key event for `code`, or null when it is not a bindable key.
static func event_of(code: String) -> InputEventKey:
	if code.length() < 2 or not code.substr(1).is_valid_int():
		return null
	var value: int = code.substr(1).to_int()
	var key: Key = value as Key
	if value <= 0 or _reserved(key):
		return null
	# A number no keyboard has (a damaged settings file) is not a key: a key is a
	# character on the basic plane or one of the engine's special keys.
	var special: bool = value >= KEY_SPECIAL and value < KEY_SPECIAL + 0x10000
	if not special and (value < KEY_SPACE or value > 0xFFFF):
		return null
	var event: InputEventKey = InputEventKey.new()
	match code[0]:
		"k":
			event.keycode = key
		"p":
			event.physical_keycode = key
		_:
			return null
	return event


## True when two codes name the same key (a physical key and a label match when
## the layout puts that label there).
static func same_key(a: String, b: String) -> bool:
	return a == b or _keycode(a) == _keycode(b)


## "W", "F5", "Up" for a code.
static func code_label(code: String) -> String:
	var keycode: Key = _keycode(code)
	if keycode == KEY_NONE:
		return "—"
	return OS.get_keycode_string(keycode)


## The key `action` is bound to now (from the InputMap), e.g. "X".
static func label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			var code: String = (
				"k%d" % key.keycode if key.keycode != KEY_NONE else "p%d" % key.physical_keycode
			)
			return code_label(code)
	return "—"


## {"key_<action>": its key now} for every action, to fill text templates
## ("{key_order_stop} stops").
static func key_names() -> Dictionary:
	var values: Dictionary = {}
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		values["key_" + String(action)] = label(action)
	return values


## The default binding of `action`.
static func default_of(action: StringName) -> String:
	for entry: Array in ACTIONS:
		if entry[0] == action:
			return entry[3]
	return ""


## The label shown for `action` ("Stop").
static func title_of(action: StringName) -> String:
	for entry: Array in ACTIONS:
		if entry[0] == action:
			return entry[1]
	return String(action)


static func has_action(action: StringName) -> bool:
	return default_of(action) != ""


## The control group (1..9) whose key `event` is, or 0. Modifiers do not matter
## (Ctrl + the key stores the group).
static func group_of(event: InputEvent) -> int:
	for group: int in range(1, GROUP_COUNT + 1):
		var action: StringName = StringName("control_group_%d" % group)
		if InputMap.has_action(action) and event.is_action(action):
			return group
	return 0


func _put(scheme: StringName, action: StringName, code: String) -> void:
	var scheme_overrides: Dictionary = overrides.get(scheme, {})
	if code == default_of(action):
		scheme_overrides.erase(action)
	else:
		scheme_overrides[action] = code
	if scheme_overrides.is_empty():
		overrides.erase(scheme)
	else:
		overrides[scheme] = scheme_overrides


## Removes overrides that put two actions of `scheme` on one key.
func _drop_clashes(scheme: StringName) -> void:
	for _pass: int in ACTIONS.size():
		var clash: StringName = &""
		for entry: Array in ACTIONS:
			var action: StringName = entry[0]
			var other: StringName = conflict(scheme, action, binding(scheme, action))
			if other == &"":
				continue
			var scheme_overrides: Dictionary = overrides.get(scheme, {})
			clash = action if scheme_overrides.has(action) else other
			break
		if clash == &"":
			return
		_put(scheme, clash, default_of(clash))


static func _keycode(code: String) -> Key:
	var event: InputEventKey = event_of(code)
	if event == null:
		return KEY_NONE
	if event.keycode != KEY_NONE:
		return event.keycode
	if DisplayServer.get_name() == "headless":
		return event.physical_keycode
	var mapped: Key = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
	return mapped if mapped != KEY_NONE else event.physical_keycode


static func _reserved(key: Key) -> bool:
	return key in [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]
