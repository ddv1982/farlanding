extends GutTest
## Settings: the control scheme is saved under [controls] and loaded back.

const PATH: String = "user://test_settings_controls.cfg"
const SETTINGS_SCRIPT = preload("res://core/settings.gd")

var _scheme: StringName


func before_each() -> void:
	_scheme = Settings.control_scheme


func after_each() -> void:
	Settings.control_scheme = _scheme
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_classic_is_the_default() -> void:
	var script: GDScript = SETTINGS_SCRIPT
	var fresh: Node = script.new()
	var scheme: StringName = fresh.get("control_scheme")
	assert_eq(scheme, &"classic")
	fresh.free()


func test_browser_fullscreen_confirmation_saves_only_actual_changes() -> void:
	var fresh := SETTINGS_SCRIPT.new()
	fresh.path = PATH
	watch_signals(fresh)
	fresh._on_web_fullscreen_changed([true])
	assert_true(fresh.fullscreen)
	assert_signal_emit_count(fresh, "changed", 1)
	fresh._on_web_fullscreen_changed([true])
	assert_signal_emit_count(fresh, "changed", 1, "duplicate browser events do not write again")
	fresh._on_web_fullscreen_changed([false])
	assert_false(fresh.fullscreen, "browser Escape updates the setting")
	assert_signal_emit_count(fresh, "changed", 2)
	fresh.free()


func test_the_scheme_persists() -> void:
	Settings.control_scheme = Settings.SCHEME_CLASSIC
	Settings.set_control_scheme(Settings.SCHEME_MODERN, PATH)
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(PATH), OK)
	var saved: String = config.get_value("controls", "control_scheme", "")
	assert_eq(saved, "modern")
	Settings.control_scheme = Settings.SCHEME_CLASSIC
	Settings.load_from(PATH)
	assert_eq(Settings.control_scheme, Settings.SCHEME_MODERN)


func test_rejected_browser_fullscreen_request_refreshes_without_saving() -> void:
	var fresh := SETTINGS_SCRIPT.new()
	fresh.path = PATH
	fresh._web_fullscreen_pending = true
	watch_signals(fresh)
	fresh._on_web_fullscreen_changed([false])
	assert_false(fresh.fullscreen)
	assert_false(fresh._web_fullscreen_pending)
	assert_signal_emit_count(fresh, "changed", 1, "the checkbox must refresh on rejection")
	assert_false(FileAccess.file_exists(PATH), "unchanged settings must not be written")
	fresh._on_web_fullscreen_changed([false])
	assert_signal_emit_count(fresh, "changed", 1, "duplicate events stay silent")
	fresh.free()


func test_an_unknown_scheme_falls_back_to_classic() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("controls", "control_scheme", "telepathy")
	config.save(PATH)
	Settings.control_scheme = Settings.SCHEME_MODERN
	Settings.load_from(PATH)
	assert_eq(Settings.control_scheme, Settings.SCHEME_CLASSIC)
	Settings.set_control_scheme(&"telepathy", PATH)
	assert_eq(Settings.control_scheme, Settings.SCHEME_CLASSIC)
