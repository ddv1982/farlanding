extends GutTest
## The title's explicit Load game route shares the existing pause slot modal.

const SAVES: String = "user://test_save_menu_flow/"
const SETTINGS: String = "user://test_save_menu_flow_settings.cfg"

var _main: Main
var _saved_dir: String
var _saved_settings: String
var _saved_seen: PackedStringArray


func before_each() -> void:
	_saved_dir = SaveSlots.default_dir
	_saved_settings = Settings.path
	_saved_seen = Settings.hints_seen
	SaveSlots.default_dir = SAVES
	Settings.path = SETTINGS
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Main
	add_child(_main)


func after_each() -> void:
	_main.queue_free()
	await wait_physics_frames(2)
	for slot: StringName in SaveSlots.slots():
		SaveSlots.remove(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	SaveSlots.default_dir = _saved_dir
	Settings.path = _saved_settings
	Settings.hints_seen = _saved_seen


func test_load_game_is_available_on_the_initial_title_without_any_saves() -> void:
	assert_true(_main._title._load.is_visible_in_tree())
	assert_false(_main._title._load.disabled)
	assert_eq(_main._title._load.text, "LOAD GAME")
	_main._title._load.pressed.emit()
	assert_true(_main._slots.visible)
	assert_false(_main._slots.saving)
	assert_eq(_main._slots._heading.text, "Load")
	assert_null(_main.map)
	assert_eq(_main.screen, &"title")
	assert_true(_main._title.visible)
	for button: Button in _main._slots._buttons.values():
		assert_true(button.disabled, "empty slots cannot be loaded")


func test_slot_modal_keeps_keyboard_focus_above_the_title_and_back_returns_it() -> void:
	_main._title._load.grab_focus()
	_main._title._load.pressed.emit()
	assert_eq(_main._title.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	var focused: Control = _main.get_viewport().gui_get_focus_owner()
	assert_not_null(focused)
	assert_true(_main._slots.is_ancestor_of(focused))
	assert_true(_main._slots.is_ancestor_of(focused.find_next_valid_focus()))
	var back: Button = focused as Button
	assert_string_contains(back.text, "BACK")
	back.pressed.emit()
	assert_false(_main._slots.visible)
	assert_eq(_main._title.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_INHERITED)
	assert_eq(_main.get_viewport().gui_get_focus_owner(), _main._title._load)
	assert_null(_main.map)
	assert_null(_main.runner)
	assert_eq(_main.screen, &"title")


func test_escape_from_title_load_returns_to_title_without_starting_a_mission() -> void:
	_main._title._load.pressed.emit()
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	_main._slots._unhandled_input(key)
	assert_false(_main._slots.visible)
	assert_true(_main._title.is_visible_in_tree())
	assert_null(_main.map)
	assert_null(_main.runner)


func test_title_load_enters_the_restored_mission_and_hides_the_menu() -> void:
	_main.start_mission(SaveFixture.mission(&"conquest"))
	await wait_physics_frames(3)
	_main.runner.world.economy.add(0, 123, 0)
	var alloy: int = _main.runner.world.economy.stockpile(0).alloy
	assert_true(_main.save_game(SaveSlots.MANUAL[0]))
	_main.show_title()
	assert_null(_main.map)
	_main._title._load.pressed.emit()
	var slot: Button = _main._slots._buttons[SaveSlots.MANUAL[0]]
	assert_false(slot.disabled)
	slot.pressed.emit()
	assert_not_null(_main.map)
	assert_not_null(_main.runner)
	assert_eq(_main.runner.world.economy.stockpile(0).alloy, alloy)
	assert_false(_main._title.visible)
	assert_false(_main._slots.visible)
	assert_eq(_main.screen, &"")
	assert_false(_main.paused)
	assert_true(_main.map.is_inside_tree())


func test_pause_save_load_keeps_the_modal_and_restores_the_pause_menu() -> void:
	_main.start_mission(SaveFixture.mission(&"conquest"))
	await wait_physics_frames(3)
	_main.open_pause()
	_main._pause.save_pressed.emit()
	assert_true(_main._slots.visible)
	assert_true(_main._slots.saving)
	assert_true(_main.paused)
	assert_eq(_main._pause.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	_main._slots.close()
	assert_true(_main._pause.visible)
	assert_true(_main.paused)
	assert_eq(_main._pause.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_INHERITED)
	_main._pause.load_pressed.emit()
	assert_true(_main._slots.visible)
	assert_false(_main._slots.saving)


func test_starting_a_scene_without_a_landing_map_preserves_the_existing_map() -> void:
	_main.start_mission(SaveFixture.mission(&"conquest"))
	await wait_physics_frames(3)
	var map: LandingMap = _main.map
	var runner: Mission = _main.runner
	var root: Node = Node.new()
	var scene: PackedScene = PackedScene.new()
	assert_eq(scene.pack(root), OK)
	root.free()
	var mission: MissionDef = MissionDef.new()
	mission.map_scene = scene
	_main.start_mission(mission)
	assert_eq(_main.map, map)
	assert_eq(_main.runner, runner)
	assert_false(map.is_queued_for_deletion())
	assert_true(_main._message_failed)


func test_keyboard_activation_opens_load_and_escape_closes_only_the_modal() -> void:
	_main._title._load.grab_focus()
	var accept: InputEventAction = InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	await wait_physics_frames(2)
	accept.pressed = false
	Input.parse_input_event(accept)
	await wait_physics_frames(2)
	assert_true(_main._slots.visible)
	assert_null(_main.map)
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await wait_physics_frames(2)
	escape.pressed = false
	Input.parse_input_event(escape)
	assert_false(_main._slots.visible)
	assert_true(_main._title.visible)
	assert_null(_main.map)
	assert_eq(_main.screen, &"title")


func test_latest_written_slot_wins_within_the_same_second() -> void:
	_main.start_mission(SaveFixture.mission(&"conquest"))
	await wait_physics_frames(3)
	var game: SaveGame = SaveGame.capture(_main.current, _main.map.snapshot(), 0.0, null)
	assert_eq(SaveSlots.write(SaveSlots.QUICKSAVE, game), "")
	assert_eq(SaveSlots.write(SaveSlots.MANUAL[0], game), "")
	var newest: StringName = SaveSlots.newest()[0]
	assert_eq(newest, SaveSlots.MANUAL[0])
	assert_eq(SaveSlots.write(SaveSlots.MANUAL[2], game), "")
	assert_eq(SaveSlots.write(SaveSlots.MANUAL[0], game), "")
	newest = SaveSlots.newest()[0]
	assert_eq(newest, SaveSlots.MANUAL[0])


func test_load_game_sits_directly_below_single_missions() -> void:
	var buttons: Array[Node] = _main._title._menu.get_children()
	var index: int = buttons.find(_main._title._load)
	assert_gt(index, 0)
	var previous: Button = buttons[index - 1] as Button
	assert_not_null(previous)
	assert_eq(previous.text, "SINGLE MISSIONS")
