extends GutTest
## Settings: the control scheme is saved under [controls] and loaded back.

const PATH: String = "user://test_settings_controls.cfg"

var _scheme: StringName


func before_each() -> void:
	_scheme = Settings.control_scheme


func after_each() -> void:
	Settings.control_scheme = _scheme
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_classic_is_the_default() -> void:
	var script: GDScript = load("res://core/settings.gd")
	var fresh: Node = script.new()
	var scheme: StringName = fresh.get("control_scheme")
	assert_eq(scheme, &"classic")
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


func test_an_unknown_scheme_falls_back_to_classic() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("controls", "control_scheme", "telepathy")
	config.save(PATH)
	Settings.control_scheme = Settings.SCHEME_MODERN
	Settings.load_from(PATH)
	assert_eq(Settings.control_scheme, Settings.SCHEME_CLASSIC)
	Settings.set_control_scheme(&"telepathy", PATH)
	assert_eq(Settings.control_scheme, Settings.SCHEME_CLASSIC)
