extends Node

var _gut: GutMain
var _scripts: Array[GDScript] = []
var _latency_mode: bool = false


func _ready() -> void:
	_latency_mode = OS.get_cmdline_user_args().has("--web-latency")
	if _latency_mode:
		for bus: int in AudioServer.bus_count:
			var bus_name: StringName = AudioServer.get_bus_name(bus)
			AudioServer.set_bus_mute(bus, bus_name != &"UI" and bus_name != &"Master")
		JavaScriptBridge.eval("window.farlanding.ready = true")
	else:
		_run.call_deferred()


func _run() -> void:
	_gut = GutMain.new()
	add_child(_gut)
	_gut.include_subdirectories = true
	_gut.log_level = 1
	_gut.end_run.connect(_finished)
	for entry: String in ResourceLoader.list_directory("res://tests/audio"):
		if entry.begins_with("test_") and entry.ends_with(".gd"):
			var path: String = "res://tests/audio/" + entry
			var script: GDScript = load(path)
			_scripts.append(script)
			_gut.add_script(path)
	JavaScriptBridge.eval("window.farlanding.ready = true")
	_gut.test_scripts()


func _finished() -> void:
	var tests: int = _gut.get_test_count()
	var failures: int = _gut.get_fail_count()
	var assertions: int = _gut.get_assert_count()
	var result: Dictionary = {"tests": tests, "failures": failures, "assertions": assertions}
	JavaScriptBridge.eval("window.farlanding.audioQa = " + JSON.stringify(result))


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if _latency_mode and key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		Audio.play(&"ui_select")
		JavaScriptBridge.eval(
			(
				"window.farlanding.audioDriverLatencyMs = "
				+ str(AudioServer.get_output_latency() * 1000.0)
			)
		)
		get_viewport().set_input_as_handled()
