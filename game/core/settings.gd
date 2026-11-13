extends Node
## Player settings (autoload `Settings`), persisted to `user://settings.cfg`.
## Audio volumes (the Audio service applies them to buses) and the mouse control
## scheme (the SelectionController reads it).

signal changed

const PATH: String = "user://settings.cfg"
const SECTION_AUDIO: String = "audio"
const SECTION_CONTROLS: String = "controls"
## One-button mouse: left click selects and commands by context, right click
## deselects (the Command & Conquer way). The default.
const SCHEME_CLASSIC: StringName = &"classic"
## Left click selects (and attacks an enemy), right click commands.
const SCHEME_MODERN: StringName = &"modern"
const SCHEMES: Array[StringName] = [SCHEME_CLASSIC, SCHEME_MODERN]

## Linear volumes in [0, 1].
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 1.0
## SCHEME_CLASSIC or SCHEME_MODERN.
var control_scheme: StringName = SCHEME_CLASSIC


func _ready() -> void:
	load_from(PATH)


func save_to(path: String = PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(SECTION_AUDIO, "music_volume", music_volume)
	config.set_value(SECTION_AUDIO, "sfx_volume", sfx_volume)
	config.set_value(SECTION_AUDIO, "ui_volume", ui_volume)
	config.set_value(SECTION_CONTROLS, "control_scheme", String(control_scheme))
	return config.save(path)


## Loads settings; a missing file keeps the defaults.
func load_from(path: String = PATH) -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return
	master_volume = _volume(config, "master_volume", master_volume)
	music_volume = _volume(config, "music_volume", music_volume)
	sfx_volume = _volume(config, "sfx_volume", sfx_volume)
	ui_volume = _volume(config, "ui_volume", ui_volume)
	var scheme: String = config.get_value(
		SECTION_CONTROLS, "control_scheme", String(control_scheme)
	)
	control_scheme = StringName(scheme) if SCHEMES.has(StringName(scheme)) else SCHEME_CLASSIC
	changed.emit()


## Switches the control scheme, announces it and saves the settings to `path`.
func set_control_scheme(scheme: StringName, path: String = PATH) -> void:
	if not SCHEMES.has(scheme) or scheme == control_scheme:
		return
	control_scheme = scheme
	changed.emit()
	save_to(path)


static func _volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: float = config.get_value(SECTION_AUDIO, key, fallback)
	return clampf(value, 0.0, 1.0)
