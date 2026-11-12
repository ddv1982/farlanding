extends Node
## Player settings (autoload `Settings`), persisted to `user://settings.cfg`.
## Stub: audio volumes only. The Audio service applies them to buses.

signal changed

const PATH: String = "user://settings.cfg"
const SECTION_AUDIO: String = "audio"

## Linear volumes in [0, 1].
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 1.0


func _ready() -> void:
	load_from(PATH)


func save_to(path: String = PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(SECTION_AUDIO, "music_volume", music_volume)
	config.set_value(SECTION_AUDIO, "sfx_volume", sfx_volume)
	config.set_value(SECTION_AUDIO, "ui_volume", ui_volume)
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
	changed.emit()


static func _volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: float = config.get_value(SECTION_AUDIO, key, fallback)
	return clampf(value, 0.0, 1.0)
