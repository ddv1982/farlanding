extends GutTest
## Control groups from the keyboard (Ctrl/Cmd or Alt/Option + N stores, Shift + N
## adds, N recalls) and the HUD's GroupBar (one badge per group with units).

var _f: DiscoveryFixture
var _guard: SettingsGuard = SettingsGuard.new()
var _controller: SelectionController
var _bar: GroupBar


func before_each() -> void:
	_guard.take()
	Settings.sticky_shift = false
	_f = DiscoveryFixture.new(self)
	_controller = SelectionController.new()
	_controller.world = _f.world
	add_child_autofree(_controller)
	_bar = GroupBar.new()
	add_child_autofree(_bar)
	_bar.setup(_controller)


func after_each() -> void:
	_f.dispose()
	_guard.restore()


func _soldier(x: float) -> Unit:
	return _f.spawn(_f.combat.soldier, 0, Vector3(x, 0, 0))


## A press of the number-row key `digit`; `typed` is the character the layout gives
## it (Option on macOS turns "1" into "¡").
func _key(digit: int, modifiers: Array[StringName] = [], typed: Key = KEY_NONE) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = (KEY_0 + digit) as Key
	event.keycode = typed if typed != KEY_NONE else event.physical_keycode
	event.pressed = true
	event.ctrl_pressed = modifiers.has(&"ctrl")
	event.meta_pressed = modifiers.has(&"meta")
	event.alt_pressed = modifiers.has(&"alt")
	event.shift_pressed = modifiers.has(&"shift")
	return event


func _press(event: InputEventKey) -> void:
	_controller._unhandled_input(event)


func _shift_key() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = true
	return event


func test_ctrl_number_stores_and_the_number_recalls() -> void:
	var a: Unit = _soldier(0)
	var b: Unit = _soldier(3)
	_controller.set_selection([a, b])
	_press(_key(1, [&"ctrl"]))
	_controller.set_selection([])
	_press(_key(1))
	assert_eq(_controller.selection, [a, b] as Array[Unit])


func test_alt_number_stores_even_when_option_types_another_character() -> void:
	var a: Unit = _soldier(0)
	var b: Unit = _soldier(3)
	_controller.set_selection([a, b])
	# macOS: Option+1 types "¡" (U+00A1); the key in that place still counts.
	_press(_key(1, [&"alt"], 0xA1 as Key))
	assert_eq(_controller.control_groups().count(1), 2, "Alt+1 stored the selection")
	_controller.set_selection([])
	_press(_key(1))
	assert_eq(_controller.selection, [a, b] as Array[Unit], "1 selects the group again")


func test_alt_matches_a_group_bound_by_label() -> void:
	InputMap.action_erase_events(&"control_group_4")
	var by_label := InputEventKey.new()
	by_label.keycode = KEY_4
	InputMap.action_add_event(&"control_group_4", by_label)
	assert_eq(KeyBindings.group_of(_key(4, [&"alt"], 0xA2 as Key)), 4)
	assert_eq(KeyBindings.group_of(_key(4, [], 0xA2 as Key)), 0, "without Alt: no match")


func test_meta_number_stores() -> void:
	var a: Unit = _soldier(0)
	_controller.set_selection([a])
	_press(_key(5, [&"meta"]))
	assert_eq(_controller.control_groups().count(5), 1)


func test_shift_number_adds_to_the_group() -> void:
	var a: Unit = _soldier(0)
	var b: Unit = _soldier(3)
	var c: Unit = _soldier(6)
	_controller.set_selection([a, b])
	_press(_key(2, [&"alt"]))
	_controller.set_selection([b, c])
	_press(_key(2, [&"shift"]))
	assert_eq(_controller.selection, [b, c] as Array[Unit], "adding keeps the selection")
	_controller.set_selection([])
	_press(_key(2))
	assert_eq(_controller.selection, [a, b, c] as Array[Unit], "each unit once, old ones first")


func test_sticky_shift_number_adds_to_the_group() -> void:
	Settings.sticky_shift = true
	var a: Unit = _soldier(0)
	var b: Unit = _soldier(3)
	_controller.set_selection([a])
	_press(_key(3, [&"alt"]))
	_press(_shift_key())
	_controller.set_selection([b])
	_press(_key(3))
	_press(_shift_key())
	_controller.set_selection([])
	_press(_key(3))
	assert_eq(_controller.selection, [a, b] as Array[Unit])


func test_shift_with_nothing_selected_leaves_the_group() -> void:
	var a: Unit = _soldier(0)
	_controller.set_selection([a])
	_press(_key(6, [&"alt"]))
	_controller.set_selection([])
	_press(_key(6, [&"shift"]))
	assert_eq(_controller.control_groups().count(6), 1)


func test_the_bar_is_hidden_until_a_group_exists() -> void:
	assert_false(_bar.visible)
	for group: int in range(1, ControlGroups.COUNT + 1):
		assert_false(_bar.badge(group).visible)


func test_badges_show_number_and_count_in_group_order() -> void:
	var a: Unit = _soldier(0)
	var b: Unit = _soldier(3)
	_controller.set_selection([a, b])
	_press(_key(3, [&"alt"]))
	_controller.set_selection([a])
	_press(_key(1, [&"alt"]))
	assert_true(_bar.visible)
	assert_true(_bar.badge(1).visible)
	assert_true(_bar.badge(3).visible)
	assert_false(_bar.badge(2).visible)
	assert_eq(_bar.badge(1).text, "1 · 1")
	assert_eq(_bar.badge(3).text, "3 · 2")
	assert_lt(_bar.badge(1).get_index(), _bar.badge(3).get_index())
	var c: Unit = _soldier(6)
	_controller.set_selection([c])
	_press(_key(3, [&"shift"]))
	assert_eq(_bar.badge(3).text, "3 · 3", "adding updates the count")


func test_a_badge_flashes_when_its_group_is_stored_or_added_to() -> void:
	var a: Unit = _soldier(0)
	_controller.set_selection([a])
	_press(_key(2, [&"alt"]))
	assert_true(_bar.is_flashing(2))
	assert_false(_bar.is_flashing(1))
	_bar._process(GroupBar.FLASH_SECONDS + 0.1)
	assert_false(_bar.is_flashing(2), "the light goes out")
	_press(_key(2, [&"shift"]))
	assert_true(_bar.is_flashing(2), "adding lights it again")


func test_a_badge_goes_when_its_units_die() -> void:
	var a: Unit = _soldier(0)
	_controller.set_selection([a])
	_press(_key(4, [&"alt"]))
	assert_true(_bar.badge(4).visible)
	a.health.take(1.0e6)
	Events.entity_died.emit(a)
	await wait_process_frames(2)
	assert_false(_bar.badge(4).visible)
	assert_false(_bar.visible, "no group left: the bar hides")


func test_clicking_a_badge_recalls_the_group() -> void:
	var a: Unit = _soldier(0)
	var b: Unit = _soldier(3)
	_controller.set_selection([a, b])
	_press(_key(7, [&"alt"]))
	_controller.set_selection([])
	_bar.badge(7).pressed.emit()
	assert_eq(_controller.selection, [a, b] as Array[Unit])


func test_loading_groups_refreshes_the_bar() -> void:
	var a: Unit = _soldier(0)
	var b: Unit = _soldier(3)
	_controller.set_selection([a, b])
	_press(_key(8, [&"alt"]))
	var saved: Dictionary = _controller.control_groups().to_dict()
	_controller.control_groups().from_dict({}, func(_id: int) -> Node3D: return null)
	assert_false(_bar.visible, "an empty save clears the bar")
	_controller.control_groups().from_dict(saved, _f.world.entity)
	assert_true(_bar.badge(8).visible)
	assert_eq(_bar.badge(8).text, "8 · 2")


func test_shift_number_starts_an_empty_group() -> void:
	var a: Unit = _soldier(0)
	var b: Unit = _soldier(3)
	_controller.set_selection([a, b])
	_press(_key(9, [&"shift"]))
	_controller.set_selection([])
	_press(_key(9))
	assert_eq(_controller.selection, [a, b] as Array[Unit], "Shift+9 made group 9")


func _right_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	return click


func test_right_clicking_a_badge_replaces_the_group() -> void:
	var a: Unit = _soldier(0)
	var b: Unit = _soldier(3)
	_controller.set_selection([a])
	_press(_key(2, [&"alt"]))
	_controller.set_selection([b])
	_bar.badge(2).gui_input.emit(_right_click())
	assert_eq(_bar.badge(2).text, "2 · 1")
	assert_true(_bar.is_flashing(2))
	_controller.set_selection([])
	_press(_key(2))
	assert_eq(_controller.selection, [b] as Array[Unit], "b replaced a")


func test_right_clicking_a_badge_with_nothing_selected_keeps_the_group() -> void:
	var a: Unit = _soldier(0)
	_controller.set_selection([a])
	_press(_key(2, [&"alt"]))
	_controller.set_selection([])
	_bar.badge(2).gui_input.emit(_right_click())
	assert_eq(_controller.control_groups().count(2), 1)
