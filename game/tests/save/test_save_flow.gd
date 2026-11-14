extends GutTest
## Saving and loading through the game's flow (ADR 0013): F5 quicksaves and F9
## quickloads a mission, the pause menu's Save and Load use the slot screen, a
## campaign landing autosaves as it starts and loads back into its campaign, and
## Continue on the title picks the newest of the campaign autosave and the saved
## landings. A missing, damaged, newer or incomplete save is refused with a message
## and leaves the game in play as it was.

const SAVES: String = "user://test_save_flow_saves/"
const CAMPAIGN_SAVE: String = "user://test_save_flow_campaign.cfg"
const SETTINGS: String = "user://test_save_flow_settings.cfg"

var _main: Main
var _saved_dir: String
var _saved_campaign: String
var _saved_settings: String
var _saved_seen: PackedStringArray
var _saved_won: PackedStringArray
var _feedback: Array[StringName] = []
var _saved_slots: Array[StringName] = []
var _loaded_slots: Array[StringName] = []


func before_each() -> void:
	_saved_dir = SaveSlots.default_dir
	SaveSlots.default_dir = SAVES
	_saved_campaign = CampaignSession.default_path
	CampaignSession.default_path = CAMPAIGN_SAVE
	_saved_settings = Settings.path
	_saved_seen = Settings.hints_seen
	_saved_won = Settings.missions_won
	Settings.path = SETTINGS
	_clean()
	_feedback.clear()
	_saved_slots.clear()
	_loaded_slots.clear()
	Events.ui_feedback.connect(_on_feedback)
	Events.campaign_saved.connect(_on_saved)
	Events.campaign_loaded.connect(_on_loaded)
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Main
	add_child(_main)


func after_each() -> void:
	_main.queue_free()
	await wait_frames(2)
	Events.ui_feedback.disconnect(_on_feedback)
	Events.campaign_saved.disconnect(_on_saved)
	Events.campaign_loaded.disconnect(_on_loaded)
	_clean()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES))
	SaveSlots.default_dir = _saved_dir
	CampaignSession.default_path = _saved_campaign
	Settings.path = _saved_settings
	Settings.hints_seen = _saved_seen
	Settings.missions_won = _saved_won


func _clean() -> void:
	for slot: StringName in SaveSlots.slots():
		SaveSlots.remove(slot)
	for path: String in [CAMPAIGN_SAVE, SETTINGS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _on_feedback(kind: StringName) -> void:
	_feedback.append(kind)


func _on_saved(slot: StringName) -> void:
	_saved_slots.append(slot)


func _on_loaded(slot: StringName) -> void:
	_loaded_slots.append(slot)


func _key(code: Key) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.pressed = true
	_main._unhandled_input(key)


func _start(id: StringName) -> void:
	_main.start_mission(SaveFixture.mission(id))
	await wait_frames(3)
	assert_not_null(_main.runner, "landed")


func _world() -> SimWorld:
	return _main.runner.world


func test_f5_quicksaves_and_f9_quickloads() -> void:
	await _start(&"conquest")
	await wait_frames(20)
	var hauler: Unit = SaveFixture.unit_of(_world(), 0, &"concord_hauler")
	var hauler_id: int = hauler.entity_id
	var saved_at: Vector3 = hauler.sim_position()
	_world().economy.add(0, 123, 0)
	var alloy: int = _world().economy.stockpile(0).alloy
	var tick: int = _main.runner.now()
	_key(KEY_F5)
	assert_true(SaveSlots.exists(SaveSlots.QUICKSAVE), "quicksaved")
	assert_true(_feedback.has(&"save_done"))
	assert_eq(_saved_slots, [SaveSlots.QUICKSAVE] as Array[StringName])
	var first_map: Node = _main.map
	_world().economy.add(0, 500, 0)
	await wait_frames(20)
	_key(KEY_F9)
	await wait_frames(3)
	assert_ne(_main.map, first_map, "a fresh map")
	assert_true(_feedback.has(&"load_done"))
	assert_eq(_loaded_slots, [SaveSlots.QUICKSAVE] as Array[StringName])
	assert_eq(_world().economy.stockpile(0).alloy, alloy, "the Alloy as saved")
	var loaded: Unit = _world().entity(hauler_id) as Unit
	assert_not_null(loaded, "the hauler is back")
	assert_almost_eq(loaded.sim_position().x, saved_at.x, 1.0, "where it was")
	assert_gte(_main.runner.now(), tick, "the clock goes on from the save")
	assert_false(_main.paused)


func test_the_pause_menu_saves_and_loads_through_the_slot_screen() -> void:
	await _start(&"infiltration")
	_main.open_pause()
	_main._pause.save_pressed.emit()
	assert_true(_main._slots.visible, "the slot screen")
	assert_true(_main._slots.saving)
	var autosave: Button = _main._slots._buttons[SaveSlots.AUTOSAVE]
	assert_true(autosave.disabled, "the autosave is the game's")
	_main._slots._buttons[SaveSlots.MANUAL[1]].pressed.emit()
	assert_true(SaveSlots.exists(SaveSlots.MANUAL[1]), "saved in slot 2")
	var slot_text: String = _main._slots._buttons[SaveSlots.MANUAL[1]].text
	assert_string_contains(slot_text, "Quiet Uplink")
	assert_string_contains(slot_text, "played")
	_main._slots.close()
	_main._pause.load_pressed.emit()
	assert_false(_main._slots.saving)
	assert_true(_main._slots._buttons[SaveSlots.QUICKSAVE].disabled, "nothing to load there")
	var first_map: Node = _main.map
	_main._slots._buttons[SaveSlots.MANUAL[1]].pressed.emit()
	await wait_frames(3)
	assert_ne(_main.map, first_map, "loaded")
	assert_false(_main.paused, "and running")
	assert_false(_main._slots.visible)
	assert_eq(_main.runner.guards.patrols.size(), 5, "the patrols are back")


func test_a_campaign_landing_autosaves_and_loads_into_its_campaign() -> void:
	_main.new_campaign()
	_main.campaign.state.intel = 77
	_main.launch(&"kessel_proving")
	_main._briefing._on_start()
	await wait_frames(3)
	assert_true(SaveSlots.exists(SaveSlots.AUTOSAVE), "the landing autosaved")
	var game: SaveGame = SaveSlots.read(SaveSlots.AUTOSAVE)
	assert_eq(game.kind, SaveGame.KIND_CAMPAIGN)
	assert_eq(game.plan.node_id, &"kessel_proving")
	_main.campaign.state.intel = 5
	_main.show_title()
	assert_null(_main.campaign)
	assert_true(_main.load_game(SaveSlots.AUTOSAVE))
	await wait_frames(3)
	assert_not_null(_main.campaign, "back in the campaign")
	assert_eq(_main.campaign.state.intel, 77, "as it was when the landing began")
	assert_not_null(_main.campaign.landing, "with the landing in play")
	_main.runner.finish(true)
	assert_eq(_main.campaign.state.won, [&"kessel_proving"] as Array[StringName], "it counts")


func test_loading_a_landing_puts_the_campaign_file_back_too() -> void:
	_main.new_campaign()
	_main.campaign.state.intel = 77
	_main.launch(&"kessel_proving")
	_main._briefing._on_start()
	await wait_frames(3)
	assert_true(_main.save_game(SaveSlots.MANUAL[0]))
	# Later in the same campaign: more Intel, written to the campaign file.
	_main.campaign.state.intel = 300
	_main.campaign.save()
	assert_true(_main.load_game(SaveSlots.MANUAL[0]))
	await wait_frames(3)
	var on_disk: CampaignSession = CampaignSession.new(_main.campaign_def)
	assert_true(on_disk.load_quietly())
	assert_eq(on_disk.state.intel, 77, "memory and the campaign file are one timeline")
	assert_true(_message().contains("back where this save was made"))


func test_a_resolved_landing_drops_its_quicksave_and_autosave() -> void:
	_main.new_campaign()
	_main.launch(&"kessel_proving")
	_main._briefing._on_start()
	await wait_frames(3)
	assert_true(_main.save_game(SaveSlots.QUICKSAVE))
	assert_true(_main.save_game(SaveSlots.MANUAL[0]))
	_main.runner.finish(true)
	assert_false(SaveSlots.exists(SaveSlots.QUICKSAVE), "it would load back into a won landing")
	assert_false(SaveSlots.exists(SaveSlots.AUTOSAVE))
	assert_true(SaveSlots.exists(SaveSlots.MANUAL[0]), "the player's own way back stays")
	# The manual save is from the same second as the result: Continue takes the result.
	_main.show_title()
	_main._title.continue_pressed.emit()
	await wait_frames(2)
	assert_null(_main.map, "the star map, not the landing already won")
	assert_eq(_main.campaign.state.won, [&"kessel_proving"] as Array[StringName])


func test_a_campaign_that_cannot_be_saved_says_so() -> void:
	_main.new_campaign()
	_main.campaign.path = "user://no_such_folder_for_tests/deeper/campaign.cfg"
	_feedback.clear()
	assert_ne(_main.campaign.save(), OK)
	assert_true(_feedback.has(&"save_failed"))
	assert_true(_message().contains("could not be saved"))


func _message() -> String:
	return _main._message


func test_continue_picks_the_newest_of_campaign_and_landing() -> void:
	_main.new_campaign()
	_main.launch(&"kessel_proving")
	_main._briefing._on_start()
	await wait_frames(3)
	_main.show_title()
	assert_true(_main._title._continue.visible)
	_main._title.continue_pressed.emit()
	await wait_frames(3)
	assert_not_null(_main.map, "the landing autosave is newer: back into the mission")
	assert_not_null(_main.campaign)
	_main.show_title()
	# A newer campaign autosave (a purchase aboard the Meridian) wins.
	var data: Dictionary = SaveSlots.read_data(SaveSlots.AUTOSAVE)
	data["saved_at"] = 1000
	_write_raw(SaveSlots.AUTOSAVE, var_to_str(data))
	_main._title.continue_pressed.emit()
	await wait_frames(2)
	assert_null(_main.map, "the star map, not the old landing")
	assert_true(_main._star_map.visible)


func test_continue_falls_back_to_the_campaign_when_the_landing_cannot_load() -> void:
	_main.new_campaign()
	_main.launch(&"kessel_proving")
	_main._briefing._on_start()
	await wait_frames(3)
	_main.show_title()
	# The newest save names a campaign this build cannot read.
	var data: Dictionary = SaveSlots.read_data(SaveSlots.AUTOSAVE)
	data["campaign"] = {"version": 9999}
	_write_raw(SaveSlots.AUTOSAVE, var_to_str(data))
	_main._title.continue_pressed.emit()
	await wait_frames(2)
	assert_null(_main.map, "no landing")
	assert_not_null(_main.campaign, "the campaign itself still continues")
	assert_true(_main._star_map.visible)


func test_single_missions_continue_too() -> void:
	await _start(&"conquest")
	assert_true(_main.save_game(SaveSlots.MANUAL[0]))
	_main.show_title()
	assert_true(_main._title._continue.visible, "a saved landing can be continued")
	_main._title.continue_pressed.emit()
	await wait_frames(3)
	assert_not_null(_main.map)
	assert_null(_main.campaign, "a single mission")


func test_a_finished_landing_cannot_be_saved() -> void:
	await _start(&"conquest")
	_main.runner.finish(false)
	assert_false(_main.save_game(SaveSlots.MANUAL[0]))
	assert_true(_feedback.has(&"save_failed"))
	assert_false(SaveSlots.exists(SaveSlots.MANUAL[0]))


func test_a_missing_save_is_refused_and_the_game_goes_on() -> void:
	await _start(&"conquest")
	var map: Node = _main.map
	assert_false(_main.load_game(SaveSlots.MANUAL[2]))
	_expect_untouched(map)
	assert_string_contains(_main._message, "no save")


func test_a_damaged_save_is_refused_and_the_game_goes_on() -> void:
	await _start(&"conquest")
	assert_true(_main.save_game(SaveSlots.MANUAL[0]))
	var path: String = SaveSlots.path_of(SaveSlots.MANUAL[0])
	var text: String = FileAccess.get_file_as_string(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text.left(floori(text.length() * 0.5)))
	file.close()
	var map: Node = _main.map
	assert_false(_main.load_game(SaveSlots.MANUAL[0]))
	_expect_untouched(map)
	assert_string_contains(_main._message, "damaged")
	_write_raw(SaveSlots.MANUAL[1], "")
	assert_null(SaveSlots.read(SaveSlots.MANUAL[1]), "an empty file")
	var garbage: FileAccess = FileAccess.open(
		SaveSlots.path_of(SaveSlots.MANUAL[2]), FileAccess.WRITE
	)
	garbage.store_buffer(PackedByteArray([0, 255, 13, 10, 7, 1, 2, 3]))
	garbage.close()
	assert_null(SaveSlots.read(SaveSlots.MANUAL[2]), "garbage")


func test_a_save_from_a_newer_game_is_refused() -> void:
	await _start(&"conquest")
	assert_true(_main.save_game(SaveSlots.MANUAL[0]))
	var data: Dictionary = SaveSlots.read_data(SaveSlots.MANUAL[0])
	data["format"] = SaveGame.FORMAT_VERSION + 1
	_write_raw(SaveSlots.MANUAL[0], var_to_str(data))
	var map: Node = _main.map
	assert_false(_main.load_game(SaveSlots.MANUAL[0]))
	_expect_untouched(map)
	assert_string_contains(_main._message, "newer")
	# A newer file header is refused before its payload is even read.
	var header: String = "%s %d\nx\n{}" % [SaveSlots.MAGIC, SaveGame.FORMAT_VERSION + 1]
	assert_true(SaveSlots.parse(header).is_empty())
	assert_string_contains(SaveSlots.last_error, "newer")


func test_a_save_naming_a_missing_definition_is_refused() -> void:
	await _start(&"conquest")
	assert_true(_main.save_game(SaveSlots.MANUAL[0]))
	var data: Dictionary = SaveSlots.read_data(SaveSlots.MANUAL[0])
	var units: Array = data["landing"]["world"]["units"]
	var unit: Dictionary = units[0]
	unit["def"] = "res://data/units/not_a_unit.tres"
	_write_raw(SaveSlots.MANUAL[0], var_to_str(data))
	var map: Node = _main.map
	assert_false(_main.load_game(SaveSlots.MANUAL[0]))
	_expect_untouched(map)
	assert_string_contains(_main._message, "not_a_unit")
	data["mission"] = "res://data/missions/gone.tres"
	assert_string_contains(SaveGame.check(data), "mission")


## Writes `payload` into `slot` with a valid header (to test what is inside).
func _write_raw(slot: StringName, payload: String) -> void:
	DirAccess.make_dir_recursive_absolute(SAVES)
	var file: FileAccess = FileAccess.open(SaveSlots.path_of(slot), FileAccess.WRITE)
	file.store_string(
		"%s %d\n%s\n%s" % [SaveSlots.MAGIC, SaveGame.FORMAT_VERSION, payload.sha256_text(), payload]
	)
	file.close()


func _expect_untouched(map: Node) -> void:
	assert_eq(_main.map, map, "the landing in play is untouched")
	assert_not_null(_main.runner)
	assert_true(_feedback.has(&"invalid"), "the refusal is heard")
	assert_ne(_main._message, "", "and explained")
	assert_true(_main._message_failed)
