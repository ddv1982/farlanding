extends SceneTree
## Loads every project script and scene outside `res://addons/` and exits non-zero if
## any fails to load. Run: godot --headless --path game -s res://tests/check_scripts.gd
## (`--check-only` is not used: it does not load autoloads and always exits 0.)

const SKIPPED_DIRS: PackedStringArray = ["res://addons", "res://.godot"]
const CHECKED_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]


func _initialize() -> void:
	var paths: PackedStringArray = []
	_collect("res://", paths)
	var failures: int = _check_warning_policy()
	for path: String in paths:
		var resource: Resource = load(path)
		var script: GDScript = resource as GDScript
		if resource == null or (script != null and not script.can_instantiate()):
			printerr("check_scripts: failed to load %s" % path)
			failures += 1
	print("check_scripts: %d files checked, %d failed" % [paths.size(), failures])
	quit(1 if failures > 0 else 0)


func _collect(dir_path: String, paths: PackedStringArray) -> void:
	for skipped: String in SKIPPED_DIRS:
		if dir_path.trim_suffix("/") == skipped:
			return
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() in CHECKED_EXTENSIONS:
			paths.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), paths)


## Runtime loading does not print every editor warning. Keep enabled categories at
## Error so fresh compilation makes CI observe the same diagnostics as the editor.
func _check_warning_policy() -> int:
	var enabled: bool = ProjectSettings.get_setting("debug/gdscript/warnings/enable", true)
	if not enabled:
		push_error("GDScript warnings must stay enabled")
		return 1
	var weak: PackedStringArray = []
	for property: Dictionary in ProjectSettings.get_property_list():
		var key: String = property.name
		if not key.begins_with("debug/gdscript/warnings/"):
			continue
		var severity: Variant = ProjectSettings.get_setting(key)
		if severity is int and severity == 1:
			weak.append(key.get_file())
	if not weak.is_empty():
		push_error("Enabled GDScript warnings must be errors: %s" % ", ".join(weak))
	return weak.size()
