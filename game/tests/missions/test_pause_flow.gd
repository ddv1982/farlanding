extends GutTest
## The Phase 6 flow: Esc in a mission opens the pause menu (sim clock and camera
## stop), Resume lets it run on, Settings opens from the pause menu and from the
## mission select, Restart lands the mission again and Quit goes back to the missions.

const PATH: String = "user://test_pause_flow.cfg"
const SAVES: String = "user://test_pause_flow_saves/"

var _main: Main
var _saved_dir: String
var _saved_path: String
var _saved_seen: PackedStringArray
var _saved_won: PackedStringArray


func before_each() -> void:
	# Landing autosaves and quicksaves must not land in the real profile either.
	_saved_dir = SaveSlots.default_dir
	SaveSlots.default_dir = SAVES
	# Hints shown in these landings must not be written into the real profile.
	_saved_path = Settings.path
	_saved_seen = Settings.hints_seen
	_saved_won = Settings.missions_won
	Settings.path = PATH
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Main
	add_child(_main)


func after_each() -> void:
	_main.queue_free()
	await wait_frames(2)
	for slot: StringName in SaveSlots.slots():
		SaveSlots.remove(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES))
	SaveSlots.default_dir = _saved_dir
	Settings.path = _saved_path
	Settings.hints_seen = _saved_seen
	Settings.missions_won = _saved_won
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _escape() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	_main._unhandled_input(key)


func test_pause_stops_the_sim_and_resume_lets_it_run() -> void:
	var catalog: MissionCatalog = _main.catalog
	_main.start_mission(catalog.missions[2])
	await wait_frames(3)
	assert_not_null(_main.runner)
	_escape()
	assert_true(_main.paused, "Esc pauses")
	assert_true(_main._pause.visible)
	assert_true(_main.runner.context.sim_clock.paused, "the sim clock stops")
	var camera: Node = _main.map.get(&"camera")
	assert_eq(camera.process_mode, Node.PROCESS_MODE_DISABLED, "the camera stops")
	var tick: int = _main.runner.context.sim_clock.get_tick()
	await wait_physics_frames(12)
	assert_eq(_main.runner.context.sim_clock.get_tick(), tick, "no ticks while paused")
	_main.open_settings()
	assert_true(_main._settings.visible, "settings from the pause menu")
	_main.resume()
	assert_false(_main.paused)
	assert_false(_main._settings.visible)
	assert_false(_main.runner.context.sim_clock.paused, "runs on")
	assert_eq(camera.process_mode, Node.PROCESS_MODE_INHERIT)


func test_restart_and_quit() -> void:
	var catalog: MissionCatalog = _main.catalog
	_main.start_mission(catalog.missions[2])
	await wait_frames(2)
	var first: Node = _main.map
	_main.open_pause()
	_main._on_restart()
	await wait_frames(2)
	assert_ne(_main.map, first, "a fresh landing")
	assert_false(_main.paused)
	_main.open_pause()
	_main.show_select()
	assert_null(_main.map, "back at the missions")
	assert_false(_main.paused)
	assert_true(_main._select.visible)


func test_settings_from_the_mission_select() -> void:
	_main._select.settings_pressed.emit()
	assert_true(_main._settings.visible)
	_main._settings.close()
	assert_false(_main._settings.visible)


func test_the_hud_menu_button_opens_the_pause_menu() -> void:
	var catalog: MissionCatalog = _main.catalog
	_main.start_mission(catalog.missions[0])
	await wait_frames(2)
	var hud: Hud = _main.map.get(&"hud")
	hud.request_menu()
	assert_true(_main.paused)
	_main.resume()
