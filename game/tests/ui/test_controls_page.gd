extends GutTest
## The help that explains the controls: the F1 panel and How to play name the group
## keys, and the Controls page lists every control with the keys bound now.


func test_every_explanation_names_the_new_keys() -> void:
	for scheme: StringName in [Settings.SCHEME_CLASSIC, Settings.SCHEME_MODERN]:
		var hud: String = Hud.controls_text(scheme)
		assert_string_contains(hud, "Alt/Ctrl+1-9 store")
		assert_string_contains(hud, "Shift+1-9 add or start")
		var how: String = InfoPanel.how_to_play_text(scheme)
		assert_string_contains(how, "Alt (Option on a Mac)")
		assert_string_contains(how, "Shift + the key adds")


func test_the_controls_page_lists_every_bound_key() -> void:
	for scheme: StringName in [Settings.SCHEME_CLASSIC, Settings.SCHEME_MODERN]:
		var text: String = InfoPanel.controls_text(scheme)
		for heading: String in ["MOUSE", "CAMERA", "ORDERS", "CONTROL GROUPS", "GAME"]:
			assert_string_contains(text, heading)
		for entry: Array in KeyBindings.ACTIONS:
			var action: StringName = entry[0]
			if String(action).begins_with("control_group_"):
				continue
			assert_string_contains(text, KeyBindings.label(action), String(action))
		assert_string_contains(text, "Alt + 1-9")
		assert_string_contains(text, "Shift + 1-9")
	assert_string_contains(InfoPanel.controls_text(Settings.SCHEME_MODERN), "Right click ground")
	assert_string_contains(InfoPanel.controls_text(Settings.SCHEME_CLASSIC), "Left click ground")


func test_the_controls_page_opens() -> void:
	var info := InfoPanel.new()
	add_child_autofree(info)
	info.open_controls()
	assert_true(info.visible)
	assert_eq(info.page, InfoPanel.PAGE_CONTROLS)
	assert_string_contains(info.body_text(), "CONTROL GROUPS")
