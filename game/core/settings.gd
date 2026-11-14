extends Node
## Player settings (autoload `Settings`), persisted to `user://settings.cfg`:
## audio volumes (the Audio service applies them to buses), the mouse control scheme
## (the SelectionController reads it) and the key bindings of each scheme
## (KeyBindings, put into the InputMap here), camera edge-pan and pan speed (the
## RtsCamera), the window, UI scale and render quality (applied here and, for the
## map's lights and environment, by the flow when a map loads), the accessibility
## options (team colour palette, subtitles, fewer flashes, sticky Shift), the game
## speed of single missions, the difficulty last chosen, and which tutorial hints
## this profile has already seen. Every setter announces `changed` and saves. A
## missing, older or damaged file keeps the defaults for whatever it lacks.

signal changed

const PATH: String = "user://settings.cfg"
const SECTION_AUDIO: String = "audio"
const SECTION_CONTROLS: String = "controls"
const SECTION_DISPLAY: String = "display"
const SECTION_HINTS: String = "hints"
const SECTION_ACCESS: String = "accessibility"
const SECTION_GAME: String = "game"
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
const VOLUMES: Array[StringName] = [
	&"master_volume",
	&"music_volume",
	&"sfx_volume",
	&"ambience_volume",
	&"voice_volume",
	&"ui_volume",
]
## Team colour palettes (TeamColors): the default, one safe for red-green colour
## blindness (deuteranopia, protanopia) and one for blue-yellow (tritanopia).
const PALETTE_DEFAULT: StringName = &"default"
const PALETTE_RED_GREEN: StringName = &"red_green"
const PALETTE_BLUE_YELLOW: StringName = &"blue_yellow"
const PALETTES: Array[StringName] = [PALETTE_DEFAULT, PALETTE_RED_GREEN, PALETTE_BLUE_YELLOW]
const SUBTITLE_SIZES: Array[StringName] = [&"normal", &"large"]
const UI_SCALES: Array[float] = [1.0, 1.15, 1.3]
## Sim speed of single missions (a campaign landing always plays at 1).
const GAME_SPEEDS: Array[float] = [0.5, 0.75, 1.0, 1.5, 2.0]
## The options `set_option()` takes, with the section each is saved in.
const OPTIONS: Dictionary[StringName, String] = {
	&"colour_palette": SECTION_ACCESS,
	&"subtitles": SECTION_ACCESS,
	&"subtitle_size": SECTION_ACCESS,
	&"ui_scale": SECTION_ACCESS,
	&"reduce_flashes": SECTION_ACCESS,
	&"sticky_shift": SECTION_ACCESS,
	&"game_speed": SECTION_GAME,
	&"difficulty": SECTION_GAME,
}
const MIN_PAN_SPEED: float = 0.5
const MAX_PAN_SPEED: float = 2.0
const MIN_RENDER_SCALE: float = 0.5

## Linear volumes in [0, 1].
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ambience_volume: float = 1.0
## The Advisor's tones (its bus).
var voice_volume: float = 1.0
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
## One of PALETTES.
var colour_palette: StringName = PALETTE_DEFAULT
## The Advisor's lines are written on screen.
var subtitles: bool = true
## One of SUBTITLE_SIZES.
var subtitle_size: StringName = &"normal"
## One of UI_SCALES: the size of every menu and HUD panel.
var ui_scale: float = 1.0
## Muzzle flashes and blasts are smaller and dimmer.
var reduce_flashes: bool = false
## Shift latches: one press holds it until the next (queueing, adding to a selection).
var sticky_shift: bool = false
## One of GAME_SPEEDS (single missions only).
var game_speed: float = 1.0
## The difficulty last chosen (Difficulty.LEVELS): what new campaigns and single
## missions start with.
var difficulty: StringName = Difficulty.NORMAL
## The key bindings of both mouse schemes.
var bindings: KeyBindings = KeyBindings.new()
## Tutorial hints this profile has seen (each shows once).
var hints_seen: PackedStringArray = PackedStringArray()
## Where settings are saved (tests point it elsewhere).
var path: String = PATH


func _ready() -> void:
	KeyBindings.install()
	load_from(path)
	apply_display()


func save_to(target: String = "") -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(SECTION_AUDIO, "music_volume", music_volume)
	config.set_value(SECTION_AUDIO, "sfx_volume", sfx_volume)
	config.set_value(SECTION_AUDIO, "ambience_volume", ambience_volume)
	config.set_value(SECTION_AUDIO, "voice_volume", voice_volume)
	config.set_value(SECTION_AUDIO, "ui_volume", ui_volume)
	config.set_value(SECTION_CONTROLS, "control_scheme", String(control_scheme))
	config.set_value(SECTION_CONTROLS, "edge_pan", edge_pan)
	config.set_value(SECTION_CONTROLS, "pan_speed", pan_speed)
	config.set_value(SECTION_DISPLAY, "fullscreen", fullscreen)
	config.set_value(SECTION_DISPLAY, "quality", String(quality))
	config.set_value(SECTION_DISPLAY, "render_scale", render_scale)
	config.set_value(SECTION_HINTS, "seen", hints_seen)
	for key: StringName in OPTIONS:
		var value: Variant = get(key)
		config.set_value(OPTIONS[key], String(key), str(value) if value is StringName else value)
	bindings.save_into(config)
	return config.save(target if target != "" else path)


## Loads settings; a missing file keeps the defaults.
func load_from(source: String = "") -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(source if source != "" else path) != OK:
		_apply_bindings()
		return
	master_volume = _volume(config, "master_volume", master_volume)
	music_volume = _volume(config, "music_volume", music_volume)
	sfx_volume = _volume(config, "sfx_volume", sfx_volume)
	# Older files had one effects volume for ambience and the Advisor as well.
	ambience_volume = _volume(config, "ambience_volume", sfx_volume)
	voice_volume = _volume(config, "voice_volume", sfx_volume)
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
	for key: StringName in OPTIONS:
		var fallback: Variant = get(key)
		var stored: Variant = config.get_value(OPTIONS[key], String(key), fallback)
		set(key, _sanitized(key, stored, fallback))
	bindings.load_from(config, SCHEMES)
	_apply_bindings()
	changed.emit()


## Switches the control scheme, announces it and saves the settings to `target`.
func set_control_scheme(scheme: StringName, target: String = "") -> void:
	if not SCHEMES.has(scheme) or scheme == control_scheme:
		return
	control_scheme = scheme
	_apply_bindings()
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


## Sets one of OPTIONS (`key`) to `value`; a value it cannot take is refused.
## Returns true when the option changed.
func set_option(key: StringName, value: Variant) -> bool:
	if not OPTIONS.has(key):
		return false
	var current: Variant = get(key)
	var next: Variant = _sanitized(key, value, null)
	if next == null or next == current:
		return false
	set(key, next)
	if key == &"ui_scale":
		apply_display()
	_changed()
	return true


## Binds `action` to the key of `event` under the current mouse scheme. Returns &""
## when it is bound, KeyBindings.INVALID for a key that cannot be bound, or the
## action already on that key (nothing changes then unless `swap`: the two trade).
func rebind(action: StringName, event: InputEventKey, swap: bool = false) -> StringName:
	var code: String = KeyBindings.code_of(event)
	var taken_by: StringName = bindings.conflict(control_scheme, action, code)
	if taken_by == KeyBindings.INVALID or (taken_by != &"" and not swap):
		return taken_by
	if not bindings.bind(control_scheme, action, code):
		return KeyBindings.INVALID
	_apply_bindings()
	_changed()
	return &""


## Every key of the current mouse scheme back on its default.
func reset_bindings() -> void:
	bindings.reset(control_scheme)
	_apply_bindings()
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
	if not is_inside_tree():
		return
	get_tree().root.content_scale_factor = ui_scale
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	get_tree().root.scaling_3d_scale = render_scale


## The InputMap follows the bindings of the current scheme (the autoload only: a
## Settings node made by a test leaves the game's keys alone).
func _apply_bindings() -> void:
	if is_inside_tree():
		bindings.apply(control_scheme)


func _changed(target: String = "") -> void:
	changed.emit()
	save_to(target)


static func _volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: float = config.get_value(SECTION_AUDIO, key, fallback)
	return clampf(value, 0.0, 1.0)


## `value` as option `key` takes it, or `fallback` when it cannot.
static func _sanitized(key: StringName, value: Variant, fallback: Variant) -> Variant:
	match key:
		&"colour_palette":
			var palette: StringName = StringName(str(value))
			return palette if PALETTES.has(palette) else fallback
		&"subtitle_size":
			var size: StringName = StringName(str(value))
			return size if SUBTITLE_SIZES.has(size) else fallback
		&"difficulty":
			var level: StringName = StringName(str(value))
			return level if Difficulty.LEVELS.has(level) else fallback
		&"ui_scale":
			return _nearest(value, UI_SCALES, fallback)
		&"game_speed":
			return _nearest(value, GAME_SPEEDS, fallback)
		&"subtitles", &"reduce_flashes", &"sticky_shift":
			return value if value is bool else fallback
	return fallback


## The entry of `choices` equal to `value` (a number), or `fallback`.
static func _nearest(value: Variant, choices: Array[float], fallback: Variant) -> Variant:
	if not (value is float or value is int):
		return fallback
	var number: float = value
	for choice: float in choices:
		if is_equal_approx(choice, number):
			return choice
	return fallback
