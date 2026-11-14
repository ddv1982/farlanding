extends GutTest
## Phase 9 options in the Settings autoload: the new options save and load, an older
## file keeps the defaults, values it cannot take are refused, and the key bindings
## (per scheme, in the user file, never in project.godot) rebind, detect conflicts,
## swap, reset, and reach the InputMap and every text that names a key.

const OLD_FILE: String = "user://test_phase9_old.cfg"

var _guard: SettingsGuard = SettingsGuard.new()


func before_each() -> void:
	_guard.take()


func after_each() -> void:
	_guard.restore()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OLD_FILE))


func test_new_options_are_saved_and_loaded_back() -> void:
	assert_true(Settings.set_option(&"colour_palette", Settings.PALETTE_RED_GREEN))
	assert_true(Settings.set_option(&"subtitles", false))
	assert_true(Settings.set_option(&"subtitle_size", &"large"))
	assert_true(Settings.set_option(&"ui_scale", 1.15))
	assert_true(Settings.set_option(&"reduce_flashes", true))
	assert_true(Settings.set_option(&"game_speed", 1.5))
	assert_true(Settings.set_option(&"difficulty", Difficulty.HARD))
	Settings.set_volume(&"ambience_volume", 0.3)
	Settings.set_volume(&"voice_volume", 0.6)
	Settings.colour_palette = Settings.PALETTE_DEFAULT
	Settings.subtitles = true
	Settings.difficulty = Difficulty.NORMAL
	Settings.ambience_volume = 1.0
	Settings.load_from(SettingsGuard.PATH)
	assert_eq(Settings.colour_palette, Settings.PALETTE_RED_GREEN)
	assert_false(Settings.subtitles)
	assert_eq(Settings.subtitle_size, &"large")
	assert_almost_eq(Settings.ui_scale, 1.15, 0.001)
	assert_true(Settings.reduce_flashes)
	assert_almost_eq(Settings.game_speed, 1.5, 0.001)
	assert_eq(Settings.difficulty, Difficulty.HARD)
	assert_almost_eq(Settings.ambience_volume, 0.3, 0.001)
	assert_almost_eq(Settings.voice_volume, 0.6, 0.001)


func test_an_older_file_keeps_the_defaults_of_what_it_lacks() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "sfx_volume", 0.4)
	config.set_value("controls", "control_scheme", "modern")
	config.save(OLD_FILE)
	Settings.subtitles = true
	Settings.colour_palette = Settings.PALETTE_DEFAULT
	Settings.load_from(OLD_FILE)
	assert_eq(Settings.control_scheme, Settings.SCHEME_MODERN)
	assert_almost_eq(Settings.ambience_volume, 0.4, 0.001, "follows the old effects volume")
	assert_almost_eq(Settings.voice_volume, 0.4, 0.001)
	assert_true(Settings.subtitles)
	assert_eq(Settings.colour_palette, Settings.PALETTE_DEFAULT)
	assert_eq(Settings.bindings.binding(Settings.SCHEME_MODERN, &"quicksave"), "k%d" % KEY_F5)


func test_damaged_values_fall_back() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("accessibility", "colour_palette", "purple")
	config.set_value("accessibility", "ui_scale", 7.0)
	config.set_value("accessibility", "subtitles", "yes")
	config.set_value("game", "difficulty", 3)
	config.set_value("keys_classic", "order_stop", "k%d" % KEY_ESCAPE)
	config.set_value("keys_classic", "no_such_action", "k%d" % KEY_K)
	config.save(OLD_FILE)
	Settings.colour_palette = Settings.PALETTE_DEFAULT
	Settings.ui_scale = 1.0
	Settings.subtitles = true
	Settings.difficulty = Difficulty.NORMAL
	Settings.load_from(OLD_FILE)
	assert_eq(Settings.colour_palette, Settings.PALETTE_DEFAULT)
	assert_almost_eq(Settings.ui_scale, 1.0, 0.001)
	assert_true(Settings.subtitles)
	assert_eq(Settings.difficulty, Difficulty.NORMAL)
	assert_eq(Settings.bindings.binding(Settings.SCHEME_CLASSIC, &"order_stop"), "p%d" % KEY_X)
	assert_false(Settings.set_option(&"game_speed", 9.0))
	assert_false(Settings.set_option(&"nonsense", true))


func test_two_actions_on_one_key_in_a_file_are_undone() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("keys_classic", "codex", "k%d" % KEY_F5)
	config.save(OLD_FILE)
	Settings.load_from(OLD_FILE)
	var codex: String = Settings.bindings.binding(Settings.SCHEME_CLASSIC, &"codex")
	var quicksave: String = Settings.bindings.binding(Settings.SCHEME_CLASSIC, &"quicksave")
	assert_false(KeyBindings.same_key(codex, quicksave))


func test_rebinding_reports_conflicts_swaps_and_resets() -> void:
	Settings.set_control_scheme(Settings.SCHEME_CLASSIC)
	var free: StringName = Settings.rebind(&"codex", _key(KEY_K))
	assert_eq(free, &"")
	assert_eq(KeyBindings.label(&"codex"), "K", "the InputMap follows")
	var clash: StringName = Settings.rebind(&"codex", _key(KEY_F5))
	assert_eq(clash, &"quicksave", "the action holding the key is named")
	assert_eq(KeyBindings.label(&"codex"), "K", "nothing changed")
	assert_eq(Settings.rebind(&"codex", _key(KEY_F5), true), &"")
	assert_eq(KeyBindings.label(&"codex"), "F5")
	assert_eq(KeyBindings.label(&"quicksave"), "K", "the two swapped")
	assert_eq(Settings.rebind(&"codex", _key(KEY_ESCAPE)), KeyBindings.INVALID)
	Settings.reset_bindings()
	assert_eq(KeyBindings.label(&"codex"), "C")
	assert_eq(KeyBindings.label(&"quicksave"), "F5")


func test_each_scheme_keeps_its_own_keys_in_the_user_file() -> void:
	Settings.set_control_scheme(Settings.SCHEME_CLASSIC)
	Settings.rebind(&"order_stop", _key(KEY_V))
	Settings.set_control_scheme(Settings.SCHEME_MODERN)
	assert_eq(KeyBindings.label(&"order_stop"), "X", "the modern scheme kept its default")
	Settings.set_control_scheme(Settings.SCHEME_CLASSIC)
	assert_eq(KeyBindings.label(&"order_stop"), "V")
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(SettingsGuard.PATH), OK)
	var stored: String = str(config.get_value("keys_classic", "order_stop", ""))
	assert_eq(stored, "k%d" % KEY_V)
	var project: String = FileAccess.get_file_as_string("res://project.godot")
	assert_false(project.contains("keys_classic"), "project.godot is left alone")


func test_quicksave_quickload_and_pause_are_named_actions() -> void:
	for action: StringName in [
		&"quicksave", &"quickload", &"pause_menu", &"codex", &"controls_help"
	]:
		assert_true(InputMap.has_action(action), String(action))
	assert_true(_key(KEY_F5).is_action_pressed(&"quicksave"))
	assert_true(_key(KEY_F9).is_action_pressed(&"quickload"))


func test_texts_name_the_current_keys() -> void:
	Settings.set_control_scheme(Settings.SCHEME_CLASSIC)
	Settings.rebind(&"order_stop", _key(KEY_V))
	Settings.rebind(&"quicksave", _key(KEY_F6))
	var controls: String = Hud.controls_text(Settings.control_scheme)
	assert_string_contains(controls, "V stop")
	assert_string_contains(controls, "F6 quicksave")
	assert_false(controls.contains("{"), "every placeholder is filled")
	assert_string_contains(TutorialHints.fill("{key_order_stop} stops"), "V stops")
	assert_string_contains(InfoPanel.how_to_play_text(Settings.control_scheme), "F6 quicksave")


func test_hints_naming_keys_use_placeholders() -> void:
	var catalog: HintCatalog = load("res://data/hints/catalog.tres")
	for hint: HintDef in catalog.hints:
		var filled: String = TutorialHints.fill(hint.text)
		assert_false(filled.contains("{"), "%s: every placeholder is known" % hint.id)
		assert_false(hint.text.contains(" X stops"), "%s names the stop key's binding" % hint.id)


func test_the_sim_clock_runs_at_the_game_speed() -> void:
	var clock: SimClock = autofree(SimClock.new())
	clock.speed = 2.0
	var ran: int = clock.advance(SimClock.TICK_DELTA)
	assert_eq(ran, 2)
	clock.speed = 0.5
	ran = clock.advance(SimClock.TICK_DELTA)
	assert_eq(ran, 0)
	ran = clock.advance(SimClock.TICK_DELTA)
	assert_eq(ran, 1)


func test_ui_scale_applies_to_the_window() -> void:
	Settings.set_option(&"ui_scale", 1.3)
	assert_almost_eq(get_tree().root.content_scale_factor, 1.3, 0.001)


static func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event
