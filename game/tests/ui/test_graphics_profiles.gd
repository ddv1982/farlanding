extends GutTest

const SETTINGS_SCRIPT = preload("res://core/settings.gd")
const PATH: String = "user://test_graphics_profiles.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_fresh_profiles_start_high_at_full_resolution_with_msaa() -> void:
	var prefs := SETTINGS_SCRIPT.new()
	autofree(prefs)
	assert_eq(prefs.quality, Settings.QUALITY_HIGH)
	assert_eq(prefs.render_scale, 1.0)
	assert_eq(prefs.msaa_3d, Viewport.MSAA_2X)


func test_switching_profiles_preserves_non_graphics_preferences() -> void:
	var prefs := SETTINGS_SCRIPT.new()
	autofree(prefs)
	prefs.path = PATH
	prefs.music_volume = 0.27
	prefs.control_scheme = Settings.SCHEME_MODERN
	prefs.hints_seen = PackedStringArray(["select_move"])
	prefs.missions_won = PackedStringArray(["conquest"])
	assert_true(prefs.set_option(&"graphics_profile", &"low"))
	assert_eq(prefs.render_scale, 0.5)
	assert_eq(prefs.msaa_3d, Viewport.MSAA_DISABLED)
	assert_true(prefs.set_option(&"graphics_profile", &"high"))
	assert_eq(prefs.render_scale, 1.0)
	assert_eq(prefs.msaa_3d, Viewport.MSAA_2X)
	assert_eq(prefs.music_volume, 0.27)
	assert_eq(prefs.control_scheme, Settings.SCHEME_MODERN)
	assert_eq(prefs.hints_seen, PackedStringArray(["select_move"]))
	assert_eq(prefs.missions_won, PackedStringArray(["conquest"]))


func test_custom_resolution_and_antialiasing_survive_reload() -> void:
	var prefs := SETTINGS_SCRIPT.new()
	autofree(prefs)
	prefs.path = PATH
	prefs.render_scale = 0.85
	assert_true(prefs.set_option(&"msaa_3d", Viewport.MSAA_4X))
	var loaded := SETTINGS_SCRIPT.new()
	autofree(loaded)
	loaded.load_from(PATH)
	assert_eq(loaded.render_scale, 0.85)
	assert_eq(loaded.msaa_3d, Viewport.MSAA_4X)
	assert_eq(loaded.graphics_defaults_version, Settings.GRAPHICS_DEFAULTS_VERSION)


func test_keeping_legacy_graphics_acknowledges_without_overwriting_them() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "quality", "low")
	config.set_value("display", "render_scale", 0.5)
	config.set_value("audio", "music_volume", 0.42)
	config.save(PATH)
	var prefs := SETTINGS_SCRIPT.new()
	autofree(prefs)
	prefs.path = PATH
	prefs.load_from(PATH)
	assert_eq(prefs.msaa_3d, Viewport.MSAA_DISABLED, "old files keep their prior AA")
	assert_eq(prefs.graphics_defaults_version, 0)
	assert_true(prefs.set_option(&"graphics_profile", &"saved"))
	assert_eq(prefs.quality, Settings.QUALITY_LOW)
	assert_eq(prefs.render_scale, 0.5)
	assert_eq(prefs.music_volume, 0.42)
	assert_eq(prefs.graphics_defaults_version, Settings.GRAPHICS_DEFAULTS_VERSION)


func test_invalid_graphics_options_are_refused() -> void:
	var prefs := SETTINGS_SCRIPT.new()
	autofree(prefs)
	prefs.path = PATH
	assert_false(prefs.set_option(&"msaa_3d", -1))
	assert_false(prefs.set_option(&"msaa_3d", 3))
	assert_false(prefs.set_option(&"graphics_profile", &"ultra"))
	assert_false(prefs.set_option(&"graphics_profile", 123))
	assert_eq(prefs.msaa_3d, Viewport.MSAA_2X)


func test_quality_restores_authored_ambient_occlusion() -> void:
	var root: Node3D = Node3D.new()
	autofree(root)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ssao_enabled = true
	root.add_child(world)
	GraphicsSettings.apply(root, Settings.QUALITY_LOW)
	assert_false(world.environment.ssao_enabled)
	GraphicsSettings.apply(root, Settings.QUALITY_HIGH)
	assert_true(world.environment.ssao_enabled)


func test_low_quality_does_not_change_a_new_scene_authored_environment() -> void:
	var scene: PackedScene = load("res://presentation/campaign/star_backdrop.tscn") as PackedScene
	var first: Node3D = scene.instantiate() as Node3D
	autofree(first)
	GraphicsSettings.apply(first, Settings.QUALITY_LOW)
	var second: Node3D = scene.instantiate() as Node3D
	autofree(second)
	GraphicsSettings.apply(second, Settings.QUALITY_HIGH)
	var environment: Environment = (
		(second.get_node(^"WorldEnvironment") as WorldEnvironment).environment
	)
	assert_true(environment.glow_enabled, "High restores the authored glow in a fresh scene")
