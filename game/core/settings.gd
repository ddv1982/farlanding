extends Node
## Player settings (autoload `Settings`), persisted to `user://settings.cfg`:
## audio volumes (the Audio service applies them to buses), the mouse control scheme
## (the SelectionController reads it), camera edge-pan and pan speed (the RtsCamera),
## the window and the render quality (applied here and, for the map's lights and
## environment, by the flow when a map loads), and which tutorial hints this profile
## has already seen. Every setter announces `changed` and saves.

signal changed

const PATH: String = "user://settings.cfg"
const SECTION_AUDIO: String = "audio"
const SECTION_CONTROLS: String = "controls"
const SECTION_DISPLAY: String = "display"
const SECTION_HINTS: String = "hints"
## One-button mouse: left click selects and commands by context, right click
## deselects (the Command & Conquer way). The default.
const SCHEME_CLASSIC: StringName = &"classic"
## Left click selects (and attacks an enemy), right click commands.
const SCHEME_MODERN: StringName = &"modern"
const SCHEMES: Array[StringName] = [SCHEME_CLASSIC, SCHEME_MODERN]
## Render quality presets: shadows and glow (see GraphicsSettings).
const QUALITY_LOW: StringName = &"low"
const QUALITY_MEDIUM: StringName = &"medium"
const QUALITY_HIGH: StringName = &"high"
const QUALITIES: Array[StringName] = [QUALITY_LOW, QUALITY_MEDIUM, QUALITY_HIGH]
## The volume settings, by name.
const VOLUMES: Array[StringName] = [&"master_volume", &"music_volume", &"sfx_volume", &"ui_volume"]
const MIN_PAN_SPEED: float = 0.5
const MAX_PAN_SPEED: float = 2.0
const MIN_RENDER_SCALE: float = 0.5

## Linear volumes in [0, 1].
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 1.0
## SCHEME_CLASSIC or SCHEME_MODERN.
var control_scheme: StringName = SCHEME_CLASSIC
## The camera pans when the mouse rests at a screen edge.
var edge_pan: bool = true
## Camera pan speed multiplier, MIN_PAN_SPEED..MAX_PAN_SPEED.
var pan_speed: float = 1.0
var fullscreen: bool = false
## QUALITY_LOW, QUALITY_MEDIUM or QUALITY_HIGH.
var quality: StringName = QUALITY_HIGH
## 3D resolution scale, MIN_RENDER_SCALE..1.
var render_scale: float = 1.0
## Tutorial hints this profile has seen (each shows once).
var hints_seen: PackedStringArray = PackedStringArray()
## Where settings are saved (tests point it elsewhere).
var path: String = PATH


func _ready() -> void:
	load_from(path)
	apply_display()


func save_to(target: String = "") -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(SECTION_AUDIO, "music_volume", music_volume)
	config.set_value(SECTION_AUDIO, "sfx_volume", sfx_volume)
	config.set_value(SECTION_AUDIO, "ui_volume", ui_volume)
	config.set_value(SECTION_CONTROLS, "control_scheme", String(control_scheme))
	config.set_value(SECTION_CONTROLS, "edge_pan", edge_pan)
	config.set_value(SECTION_CONTROLS, "pan_speed", pan_speed)
	config.set_value(SECTION_DISPLAY, "fullscreen", fullscreen)
	config.set_value(SECTION_DISPLAY, "quality", String(quality))
	config.set_value(SECTION_DISPLAY, "render_scale", render_scale)
	config.set_value(SECTION_HINTS, "seen", hints_seen)
	return config.save(target if target != "" else path)


## Loads settings; a missing file keeps the defaults.
func load_from(source: String = "") -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(source if source != "" else path) != OK:
		return
	master_volume = _volume(config, "master_volume", master_volume)
	music_volume = _volume(config, "music_volume", music_volume)
	sfx_volume = _volume(config, "sfx_volume", sfx_volume)
	ui_volume = _volume(config, "ui_volume", ui_volume)
	var scheme: String = config.get_value(
		SECTION_CONTROLS, "control_scheme", String(control_scheme)
	)
	control_scheme = StringName(scheme) if SCHEMES.has(StringName(scheme)) else SCHEME_CLASSIC
	var edge: bool = config.get_value(SECTION_CONTROLS, "edge_pan", edge_pan)
	edge_pan = edge
	var speed: float = config.get_value(SECTION_CONTROLS, "pan_speed", pan_speed)
	pan_speed = clampf(speed, MIN_PAN_SPEED, MAX_PAN_SPEED)
	var full: bool = config.get_value(SECTION_DISPLAY, "fullscreen", fullscreen)
	fullscreen = full
	var preset: String = config.get_value(SECTION_DISPLAY, "quality", String(quality))
	quality = StringName(preset) if QUALITIES.has(StringName(preset)) else QUALITY_HIGH
	var scale: float = config.get_value(SECTION_DISPLAY, "render_scale", render_scale)
	render_scale = clampf(scale, MIN_RENDER_SCALE, 1.0)
	var seen: PackedStringArray = config.get_value(SECTION_HINTS, "seen", PackedStringArray())
	hints_seen = seen
	changed.emit()


## Switches the control scheme, announces it and saves the settings to `target`.
func set_control_scheme(scheme: StringName, target: String = "") -> void:
	if not SCHEMES.has(scheme) or scheme == control_scheme:
		return
	control_scheme = scheme
	_changed(target)


## Sets one of VOLUMES (`key`) to `value` in [0, 1].
func set_volume(key: StringName, value: float) -> void:
	if not VOLUMES.has(key):
		return
	var clamped: float = clampf(value, 0.0, 1.0)
	var current: float = get(key)
	if is_equal_approx(current, clamped):
		return
	set(key, clamped)
	_changed()


func set_edge_pan(enabled: bool) -> void:
	if enabled == edge_pan:
		return
	edge_pan = enabled
	_changed()


func set_pan_speed(value: float) -> void:
	var clamped: float = clampf(value, MIN_PAN_SPEED, MAX_PAN_SPEED)
	if is_equal_approx(clamped, pan_speed):
		return
	pan_speed = clamped
	_changed()


func set_fullscreen(enabled: bool) -> void:
	if enabled == fullscreen:
		return
	fullscreen = enabled
	apply_display()
	_changed()


func set_quality(preset: StringName) -> void:
	if not QUALITIES.has(preset) or preset == quality:
		return
	quality = preset
	_changed()


func set_render_scale(value: float) -> void:
	var clamped: float = clampf(value, MIN_RENDER_SCALE, 1.0)
	if is_equal_approx(clamped, render_scale):
		return
	render_scale = clamped
	apply_display()
	_changed()


## True once the hint `id` was shown to this profile.
func has_seen_hint(id: StringName) -> bool:
	return hints_seen.has(String(id))


## Remembers that the hint `id` was shown (saved at once).
func mark_hint_seen(id: StringName) -> void:
	if has_seen_hint(id):
		return
	hints_seen.append(String(id))
	_changed()


## Every hint shows again (the settings' "Reset hints").
func reset_hints() -> void:
	if hints_seen.is_empty():
		return
	hints_seen = PackedStringArray()
	_changed()


## Applies the window mode and the 3D resolution scale (not in headless runs).
func apply_display() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var mode: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	get_tree().root.scaling_3d_scale = render_scale


func _changed(target: String = "") -> void:
	changed.emit()
	save_to(target)


static func _volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: float = config.get_value(SECTION_AUDIO, key, fallback)
	return clampf(value, 0.0, 1.0)
