extends GutTest
## Single missions open in catalog order: the first always, each other once the one
## before it was won. The wins belong to the profile (Settings), the mission select
## shows locked, open and completed cards, and a mission won through Main is recorded.

const CATALOG: String = "res://data/missions/catalog.tres"
const OLD_FILE: String = "user://test_mission_unlock_old.cfg"
const SAVES: String = "user://test_mission_unlock_saves/"

var _guard: SettingsGuard = SettingsGuard.new()
var _catalog: MissionCatalog
var _saved_won: PackedStringArray


func before_each() -> void:
	_guard.take()
	_saved_won = Settings.missions_won.duplicate()
	Settings.missions_won = PackedStringArray()
	_catalog = load(CATALOG)


func after_each() -> void:
	Settings.missions_won = _saved_won
	_guard.restore()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OLD_FILE))


func test_the_first_is_open_and_each_next_waits_for_the_one_before() -> void:
	var catalog: MissionCatalog = _made_catalog([&"a", &"b", &"c"])
	var a: MissionDef = catalog.missions[0]
	var b: MissionDef = catalog.missions[1]
	var c: MissionDef = catalog.missions[2]
	var none := PackedStringArray()
	assert_true(catalog.is_open(a, none), "the first is always open")
	assert_false(catalog.is_open(b, none))
	assert_false(catalog.is_open(c, none))
	assert_true(catalog.is_open(b, PackedStringArray(["a"])))
	assert_false(catalog.is_open(c, PackedStringArray(["a"])), "one at a time")
	assert_true(catalog.is_open(c, PackedStringArray(["a", "b"])))
	assert_true(catalog.is_open(c, PackedStringArray(["c"])), "a won mission stays open")
	assert_eq(catalog.previous_of(c), b)
	assert_null(catalog.previous_of(a))


func test_the_order_is_the_catalogs() -> void:
	var catalog: MissionCatalog = _made_catalog([&"a", &"b", &"c"])
	var a: MissionDef = catalog.missions[0]
	var c: MissionDef = catalog.missions[2]
	var order: Array[MissionDef] = [c, catalog.missions[1], a]
	catalog.missions = order
	assert_true(catalog.is_open(c, PackedStringArray()), "c comes first now")
	assert_false(catalog.is_open(a, PackedStringArray(["c"])))
	assert_true(catalog.is_open(a, PackedStringArray(["b"])))


func test_unknown_ids_and_missions_change_nothing() -> void:
	var catalog: MissionCatalog = _made_catalog([&"a", &"b"])
	var b: MissionDef = catalog.missions[1]
	assert_false(catalog.is_open(b, PackedStringArray(["nothing", "elsewhere"])))
	var stranger: MissionDef = _made_catalog([&"x"]).missions[0]
	assert_false(catalog.is_open(stranger, PackedStringArray(["a", "x"])), "not in the catalog")
	assert_false(catalog.is_open(null, PackedStringArray(["a"])))


func test_the_real_catalog_opens_only_its_first_mission_at_first() -> void:
	var none := PackedStringArray()
	assert_true(_catalog.is_open(_catalog.missions[0], none))
	for i: int in range(1, _catalog.missions.size()):
		assert_false(_catalog.is_open(_catalog.missions[i], none), String(_catalog.missions[i].id))


func test_the_wins_are_saved_with_the_settings() -> void:
	Settings.mark_mission_won(&"conquest")
	Settings.mark_mission_won(&"survey")
	Settings.mark_mission_won(&"conquest")
	assert_eq(Settings.missions_won, PackedStringArray(["conquest", "survey"]), "once each")
	Settings.missions_won = PackedStringArray()
	Settings.load_from()
	assert_true(Settings.has_won_mission(&"conquest"))
	assert_true(Settings.has_won_mission(&"survey"))
	assert_false(Settings.has_won_mission(&"infiltration"))


func test_an_older_settings_file_means_nothing_won() -> void:
	var config := ConfigFile.new()
	config.set_value(Settings.SECTION_GAME, "difficulty", "hard")
	config.set_value(Settings.SECTION_HINTS, "seen", PackedStringArray(["storm"]))
	assert_eq(config.save(OLD_FILE), OK)
	Settings.missions_won = PackedStringArray(["conquest"])
	Settings.load_from(OLD_FILE)
	assert_true(Settings.missions_won.is_empty())


func test_the_select_shows_locked_open_and_completed_cards() -> void:
	var first: MissionDef = _catalog.missions[0]
	var second: MissionDef = _catalog.missions[1]
	var third: MissionDef = _catalog.missions[2]
	Settings.missions_won = PackedStringArray([String(first.id)])
	var select := MissionSelect.new()
	add_child_autofree(select)
	select.show_catalog(_catalog)
	assert_eq(select.card_state(first), MissionSelect.CARD_COMPLETED)
	assert_eq(select.card_mark(first), "COMPLETED")
	assert_false(select.card_of(first).disabled, "a won mission can be played again")
	assert_eq(select.card_state(second), MissionSelect.CARD_OPEN)
	assert_eq(select.card_mark(second), "")
	assert_false(select.card_of(second).disabled)
	assert_eq(select.card_line(second), MissionSelect.type_name(second))
	assert_eq(select.card_state(third), MissionSelect.CARD_LOCKED)
	assert_true(select.card_of(third).disabled)
	assert_string_contains(select.card_line(third), "LOCKED")
	assert_string_contains(select.card_line(third), second.title)


func test_a_locked_card_does_nothing() -> void:
	var select := MissionSelect.new()
	add_child_autofree(select)
	select.show_catalog(_catalog)
	watch_signals(select)
	var locked: Button = select.card_of(_catalog.missions[1])
	locked.pressed.emit()
	select._on_card_pressed(_catalog.missions[1])
	assert_signal_not_emitted(select, "mission_chosen")
	select.card_of(_catalog.missions[0]).pressed.emit()
	assert_signal_emitted_with_parameters(select, "mission_chosen", [_catalog.missions[0]])


func test_the_list_follows_a_win_when_shown_again() -> void:
	var select := MissionSelect.new()
	add_child_autofree(select)
	select.show_catalog(_catalog)
	var second: MissionDef = _catalog.missions[1]
	assert_eq(select.card_state(second), MissionSelect.CARD_LOCKED)
	select.visible = false
	Settings.mark_mission_won(_catalog.missions[0].id)
	select.visible = true
	assert_eq(select.card_state(second), MissionSelect.CARD_OPEN)
	assert_false(select.card_of(second).disabled)
	assert_eq(select.card_mark(_catalog.missions[0]), "COMPLETED")


func test_a_mission_won_through_main_is_recorded() -> void:
	var saved_dir: String = SaveSlots.default_dir
	SaveSlots.default_dir = SAVES
	var main: Main = (load("res://main.tscn") as PackedScene).instantiate() as Main
	add_child(main)
	var first: MissionDef = main.catalog.missions[0]
	main.start_mission(first)
	await wait_frames(3)
	assert_not_null(main.runner)
	main.runner.finish(false)
	assert_false(Settings.has_won_mission(first.id), "a lost mission opens nothing")
	main.start_mission(first)
	await wait_frames(3)
	main.runner.finish(true)
	assert_true(Settings.has_won_mission(first.id))
	assert_true(main.catalog.is_open(main.catalog.missions[1], Settings.missions_won))
	main.queue_free()
	await wait_frames(2)
	for slot: StringName in SaveSlots.slots():
		SaveSlots.remove(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES))
	SaveSlots.default_dir = saved_dir


static func _made_catalog(ids: Array[StringName]) -> MissionCatalog:
	var catalog := MissionCatalog.new()
	for id: StringName in ids:
		var mission := MissionDef.new()
		mission.id = id
		mission.title = String(id).to_upper()
		catalog.missions.append(mission)
	return catalog
