extends GutTest
## AudioCueSelector: one reply per group, fallbacks, throttling.


func test_dominant_sound_set_is_the_most_common() -> void:
	var sets: Array[StringName] = [&"ranger", &"bulwark", &"bulwark", &"ranger", &"bulwark"]
	assert_eq(AudioCueSelector.dominant_sound_set(sets), &"bulwark")


func test_dominant_sound_set_tie_goes_to_first_seen() -> void:
	var sets: Array[StringName] = [&"kite", &"ranger", &"ranger", &"kite"]
	assert_eq(AudioCueSelector.dominant_sound_set(sets), &"kite")


func test_dominant_sound_set_ignores_units_without_a_set() -> void:
	var sets: Array[StringName] = [&"", &"", &"surveyor"]
	assert_eq(AudioCueSelector.dominant_sound_set(sets), &"surveyor")
	var none: Array[StringName] = [&"", &""]
	assert_eq(AudioCueSelector.dominant_sound_set(none), &"")


func test_selecting_a_group_gives_one_reply() -> void:
	var selector: AudioCueSelector = AudioCueSelector.new()
	var sets: Array[StringName] = []
	for i: int in 40:
		sets.append(&"ranger" if i % 3 else &"kite")
	var cues: Array[StringName] = selector.on_selection(sets, 10.0)
	assert_eq(cues, [&"unit_ranger_select", &"ui_select"] as Array[StringName])


func test_deselect_only_after_a_selection() -> void:
	var selector: AudioCueSelector = AudioCueSelector.new()
	var empty: Array[StringName] = []
	assert_true(selector.on_selection(empty, 1.0).is_empty())
	var sets: Array[StringName] = [&"ranger"]
	selector.on_selection(sets, 2.0)
	assert_eq(selector.on_selection(empty, 3.0), [&"ui_deselect"] as Array[StringName])
	assert_true(selector.on_selection(empty, 4.0).is_empty())


func test_repeated_selection_is_throttled() -> void:
	var selector: AudioCueSelector = AudioCueSelector.new()
	var sets: Array[StringName] = [&"bulwark"]
	assert_eq(selector.on_selection(sets, 1.0)[0], &"unit_bulwark_select")
	assert_eq(selector.on_selection(sets, 1.3), [&"ui_select"] as Array[StringName])
	assert_eq(selector.on_selection(sets, 1.7)[0], &"unit_bulwark_select")


func test_command_replies_by_kind() -> void:
	var selector: AudioCueSelector = AudioCueSelector.new()
	var sets: Array[StringName] = [&"kite", &"kite"]
	assert_eq(selector.on_command(sets, &"move", 1.0)[0], &"unit_kite_move")
	assert_eq(selector.on_command(sets, &"attack_move", 2.0)[0], &"unit_kite_attack")
	assert_eq(selector.on_command(sets, &"stop", 3.0), [&"ui_order"] as Array[StringName])


func test_rapid_orders_reply_once() -> void:
	var selector: AudioCueSelector = AudioCueSelector.new()
	var sets: Array[StringName] = [&"ranger"]
	assert_false(selector.on_command(sets, &"move", 1.0).is_empty())
	assert_true(selector.on_command(sets, &"move", 1.2).is_empty(), "same order spammed")
	assert_true(selector.on_command(sets, &"attack", 1.05).is_empty(), "inside the minimum gap")
	assert_false(selector.on_command(sets, &"attack", 1.5).is_empty())


func test_orders_for_units_without_a_set_fall_back_to_the_ui_sound() -> void:
	var selector: AudioCueSelector = AudioCueSelector.new()
	var sets: Array[StringName] = [&""]
	assert_eq(selector.on_command(sets, &"move", 1.0), [&"ui_order"] as Array[StringName])


func test_feedback_event_names() -> void:
	assert_eq(
		AudioCueSelector.feedback_event(&"group_assign"), [&"ui_group_assign"] as Array[StringName]
	)
	assert_eq(AudioCueSelector.feedback_event(&"ui_click"), [&"ui_click"] as Array[StringName])
	assert_eq(
		AudioCueSelector.feedback_event(&"invalid_target"),
		[&"ui_invalid_target", &"ui_invalid"] as Array[StringName]
	)
	assert_eq(
		AudioCueSelector.feedback_event(&"not_enough_resources"),
		[&"ui_not_enough_resources", &"ui_invalid"] as Array[StringName]
	)
