class_name BrowserPersistence
extends Node

signal confirmed(slot: StringName, success: bool)

var _callback: JavaScriptObject


func _ready() -> void:
	_callback = JavaScriptBridge.create_callback(_on_confirmed)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.set("farlandingSaveResult", _callback)


func confirm(path: String, slot: StringName) -> void:
	JavaScriptBridge.force_fs_sync()
	var absolute: String = ProjectSettings.globalize_path(path)
	var digest: String = FileAccess.get_file_as_string(path).sha256_text()
	JavaScriptBridge.eval(
		(
			"confirmFile(%s, %s, %s)"
			% [JSON.stringify(absolute), JSON.stringify(digest), JSON.stringify(String(slot))]
		)
	)


func _on_confirmed(arguments: Array) -> void:
	var slot: StringName = StringName(str(arguments[0]))
	var success: bool = arguments[1]
	confirmed.emit(slot, success)
