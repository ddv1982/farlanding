extends GutTest
## Phase 6 settings: every value the settings menu writes is saved and loaded back,
## values are clamped, unknown presets fall back, the hints seen persist and reset,
## and the panel writes straight through the Settings autoload.

const PATH: String = "user://test_settings_menu.cfg"

var _saved: Dictionary = {}


func before_each() -> void:
	for key: String in [
		"master_volume",
		"music_volume",
		"sfx_volume",
		"ui_volume",
		"control_scheme",
		"edge_pan",
		"pan_speed",
		"fullscreen",
		"quality",
		"render_scale",
		"hints_seen",
		"path",
	]:
		_saved[key] = Settings.get(key)
	Settings.path = PATH


func after_each() -> void:
	for key: String in _saved:
		Settings.set(key, _saved[key])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_every_setting_is_saved_and_loaded_back() -> void:
	Settings.set_volume(&"master_volume", 0.4)
	Settings.set_volume(&"music_volume", 0.3)
	Settings.set_volume(&"sfx_volume", 0.2)
	Settings.set_volume(&"ui_volume", 0.1)
	Settings.set_control_scheme(Settings.SCHEME_MODERN)
	Settings.set_edge_pan(false)
	Settings.set_pan_speed(1.6)
	Settings.set_quality(Settings.QUALITY_LOW)
	Settings.set_render_scale(0.75)
	Settings.mark_hint_seen(&"storm")
	var script: GDScript = load("res://core/settings.gd")
	var fresh: Node = script.new()
	fresh.call(&"load_from", PATH)
	var master: float = fresh.get("master_volume")
	var ui: float = fresh.get("ui_volume")
	var scheme: StringName = fresh.get("control_scheme")
	var edge: bool = fresh.get("edge_pan")
	var speed: float = fresh.get("pan_speed")
	var preset: StringName = fresh.get("quality")
	var scale: float = fresh.get("render_scale")
	var seen: PackedStringArray = fresh.get("hints_seen")
	fresh.free()
	assert_almost_eq(master, 0.4, 0.001)
	assert_almost_eq(ui, 0.1, 0.001)
	assert_eq(scheme, Settings.SCHEME_MODERN)
	assert_false(edge)
	assert_almost_eq(speed, 1.6, 0.001)
	assert_eq(preset, Settings.QUALITY_LOW)
	assert_almost_eq(scale, 0.75, 0.001)
	assert_true(seen.has("storm"))


func test_values_are_clamped_and_unknown_presets_fall_back() -> void:
	Settings.set_volume(&"music_volume", 3.0)
	assert_eq(Settings.music_volume, 1.0)
	Settings.set_volume(&"nonsense", 0.5)
	Settings.set_pan_speed(10.0)
	assert_eq(Settings.pan_speed, Settings.MAX_PAN_SPEED)
	Settings.set_render_scale(0.1)
	assert_eq(Settings.render_scale, Settings.MIN_RENDER_SCALE)
	Settings.set_quality(&"ultra")
	assert_ne(Settings.quality, &"ultra")
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "quality", "ultra")
	config.set_value("controls", "pan_speed", -4.0)
	config.save(PATH)
	Settings.load_from(PATH)
	assert_eq(Settings.quality, Settings.QUALITY_HIGH)
	assert_eq(Settings.pan_speed, Settings.MIN_PAN_SPEED)


func test_hints_seen_reset() -> void:
	Settings.hints_seen = PackedStringArray()
	Settings.mark_hint_seen(&"select_move")
	Settings.mark_hint_seen(&"select_move")
	assert_eq(Settings.hints_seen.size(), 1, "remembered once")
	assert_true(Settings.has_seen_hint(&"select_move"))
	Settings.reset_hints()
	assert_false(Settings.has_seen_hint(&"select_move"))
	Settings.load_from(PATH)
	assert_false(Settings.has_seen_hint(&"select_move"), "the reset was saved")


func test_the_settings_panel_writes_through() -> void:
	var panel: SettingsPanel = SettingsPanel.new()
	add_child_autofree(panel)
	panel.open()
	assert_true(panel.visible)
	panel._volume_sliders[&"music_volume"].value = 0.25
	assert_almost_eq(Settings.music_volume, 0.25, 0.001)
	panel._edge_pan.button_pressed = not Settings.edge_pan
	var edge: bool = panel._edge_pan.button_pressed
	assert_eq(Settings.edge_pan, edge)
	panel._on_quality_selected(0)
	assert_eq(Settings.quality, Settings.QUALITY_LOW)
	Settings.mark_hint_seen(&"storm")
	panel._on_reset_hints()
	assert_false(Settings.has_seen_hint(&"storm"))
	watch_signals(panel)
	panel.close()
	assert_signal_emitted(panel, "closed")
	assert_false(panel.visible)


func test_quality_turns_shadows_and_glow_off_and_back() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.shadow_enabled = true
	root.add_child(light)
	var env_node: WorldEnvironment = WorldEnvironment.new()
	env_node.environment = Environment.new()
	env_node.environment.glow_enabled = true
	root.add_child(env_node)
	GraphicsSettings.apply(root, Settings.QUALITY_LOW)
	assert_false(light.shadow_enabled)
	assert_false(env_node.environment.glow_enabled)
	GraphicsSettings.apply(root, Settings.QUALITY_HIGH)
	assert_true(light.shadow_enabled, "the map's own choice comes back")
	assert_true(env_node.environment.glow_enabled)
