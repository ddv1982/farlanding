class_name SettingsGuard
extends RefCounted
## Keeps the Settings autoload as it was around a test: `take()` saves every value a
## Phase 9 test may change (and points saving at a test file), `restore()` puts them
## back, the key bindings and the InputMap included, and deletes the test file.

const PATH: String = "user://test_phase9_settings.cfg"
const KEYS: Array[String] = [
	"master_volume",
	"music_volume",
	"sfx_volume",
	"ambience_volume",
	"voice_volume",
	"ui_volume",
	"control_scheme",
	"edge_pan",
	"pan_speed",
	"fullscreen",
	"quality",
	"render_scale",
	"colour_palette",
	"subtitles",
	"subtitle_size",
	"ui_scale",
	"reduce_flashes",
	"sticky_shift",
	"game_speed",
	"difficulty",
	"hints_seen",
	"path",
]

var _saved: Dictionary = {}
var _overrides: Dictionary = {}


func take() -> void:
	for key: String in KEYS:
		_saved[key] = Settings.get(key)
	_overrides = Settings.bindings.overrides.duplicate(true)
	Settings.path = PATH


func restore() -> void:
	for key: String in _saved:
		Settings.set(key, _saved[key])
	Settings.bindings.overrides.clear()
	for scheme: StringName in _overrides:
		var scheme_overrides: Dictionary = _overrides[scheme]
		Settings.bindings.overrides[scheme] = scheme_overrides
	Settings.bindings.apply(Settings.control_scheme)
	Settings.get_tree().root.content_scale_factor = Settings.ui_scale
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
