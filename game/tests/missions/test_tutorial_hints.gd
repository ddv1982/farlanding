extends GutTest
## First-time tutorial hints (ADR 0011): each fires once per profile on its trigger,
## only during a mission and only in its mission types, is remembered across runs
## (Settings), shows again after "Reset hints", and its card never blocks the map.

const PATH: String = "user://test_tutorial_hints.cfg"
const CATALOG: String = "res://data/hints/catalog.tres"

var _director: HintDirector
var _catalog: HintCatalog
var _saved_path: String
var _saved_seen: PackedStringArray


func before_each() -> void:
	_saved_path = Settings.path
	_saved_seen = Settings.hints_seen
	Settings.path = PATH
	Settings.hints_seen = PackedStringArray()
	_catalog = HintCatalog.new()
	_catalog.hints = [
		_hint(&"start", HintDef.TRIGGER_MISSION_STARTED),
		_hint(&"builder", HintDef.TRIGGER_SELECTED, HintDef.SUBJECT_BUILDER),
		_hint(&"storm", HintDef.TRIGGER_STORM_INCOMING),
		_hint(&"lab", HintDef.TRIGGER_CONSTRUCTION_COMPLETED, &"lab_def"),
	]
	var only_stealth: HintDef = _hint(&"stealth", HintDef.TRIGGER_ALERT_METER)
	only_stealth.mission_types = [&"infiltration"]
	_catalog.hints.append(only_stealth)
	_director = HintDirector.new()
	_director.setup(_catalog)


func after_each() -> void:
	_director.dispose()
	Settings.path = _saved_path
	Settings.hints_seen = _saved_seen
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _hint(id: StringName, trigger: StringName, subject: StringName = &"") -> HintDef:
	var hint: HintDef = HintDef.new()
	hint.id = id
	hint.title = String(id)
	hint.text = "{command} it"
	hint.trigger = trigger
	hint.subject = subject
	return hint


func _due_ids() -> Array[StringName]:
	_director.advance(HintDirector.SETTLE_SECONDS + 0.1)
	var ids: Array[StringName] = []
	var next: HintDef = _director.next_due()
	while next != null:
		ids.append(next.id)
		next = _director.next_due()
	return ids


func test_a_hint_fires_once_on_its_trigger() -> void:
	_director.begin(&"conquest")
	assert_eq(_due_ids(), [&"start"] as Array[StringName], "the mission-start hint")
	Events.storm_incoming.emit(30.0)
	assert_eq(_due_ids(), [&"storm"] as Array[StringName])
	Events.storm_incoming.emit(30.0)
	assert_eq(_due_ids(), [] as Array[StringName], "never twice")
	_director.end()
	_director.begin(&"conquest")
	assert_eq(_due_ids(), [] as Array[StringName], "not in the next mission either")


func test_subjects_and_mission_types_must_match() -> void:
	_director.begin(&"conquest")
	_due_ids()
	Events.alert_level_changed.emit(1, &"unaware", &"unaware")
	assert_eq(_due_ids(), [] as Array[StringName], "the stealth hint is for infiltration")
	_director.fire(HintDef.TRIGGER_SELECTED, [&"harvester"] as Array[StringName])
	assert_eq(_due_ids(), [] as Array[StringName], "a Hauler is not a builder")
	_director.fire(
		HintDef.TRIGGER_SELECTED, [&"builder", &"concord_fabricator"] as Array[StringName]
	)
	assert_eq(_due_ids(), [&"builder"] as Array[StringName])
	_director.fire(HintDef.TRIGGER_CONSTRUCTION_COMPLETED, [&"lab_def"] as Array[StringName])
	assert_eq(_due_ids(), [&"lab"] as Array[StringName])
	_director.end()
	_director.begin(&"infiltration")
	Events.alert_level_changed.emit(1, &"unaware", &"unaware")
	assert_true(_due_ids().has(&"stealth"))


func test_nothing_fires_outside_a_mission() -> void:
	Events.storm_incoming.emit(30.0)
	assert_eq(_director.queued(), 0)
	_director.begin(&"conquest")
	_director.end()
	Events.storm_incoming.emit(30.0)
	assert_eq(_director.queued(), 0)


func test_seen_hints_persist_and_reset_brings_them_back() -> void:
	_director.begin(&"survey")
	_due_ids()
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(PATH), OK, "saved as soon as shown")
	var seen: PackedStringArray = config.get_value("hints", "seen", PackedStringArray())
	assert_true(seen.has("start"))
	Settings.hints_seen = PackedStringArray()
	Settings.load_from(PATH)
	assert_true(Settings.has_seen_hint(&"start"), "loaded back")
	Settings.reset_hints()
	_director.end()
	_director.begin(&"survey")
	assert_eq(_due_ids(), [&"start"] as Array[StringName], "shows again after a reset")


func test_the_card_shows_then_dismisses_without_taking_clicks() -> void:
	var hints: TutorialHints = TutorialHints.new()
	add_child_autofree(hints)
	hints.setup(_catalog)
	var mission: MissionDef = MissionDef.new()
	mission.mission_type = &"conquest"
	hints.begin_mission(mission)
	hints._process(HintDirector.SETTLE_SECONDS + 0.1)
	hints._process(0.01)
	assert_not_null(hints.shown, "the card is up")
	assert_eq(hints.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the layer lets clicks through")
	assert_eq(hints._card.mouse_filter, Control.MOUSE_FILTER_IGNORE, "so does the card")
	assert_true(hints._text.text.ends_with("it"))
	hints.dismiss_card()
	assert_null(hints.shown)
	hints.end_mission()


func test_a_paused_mission_holds_its_hints() -> void:
	var hints: TutorialHints = TutorialHints.new()
	add_child_autofree(hints)
	hints.setup(_catalog)
	var mission: MissionDef = MissionDef.new()
	mission.mission_type = &"conquest"
	hints.begin_mission(mission)
	hints.suspended = true
	hints._process(HintDirector.SETTLE_SECONDS + 0.1)
	hints._process(0.01)
	assert_null(hints.shown, "nothing comes due while paused")
	hints.suspended = false
	hints._process(HintDirector.SETTLE_SECONDS + 0.1)
	hints._process(0.01)
	assert_not_null(hints.shown)
	hints.suspended = true
	hints._process(TutorialHints.AUTO_HIDE_SECONDS + 1.0)
	assert_not_null(hints.shown, "the card does not time out under the pause menu")
	hints.end_mission()


func test_settings_over_the_pause_menu_only_pass_menu_keys() -> void:
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	assert_true(PauseMenu._is_menu_key(escape))
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	assert_true(PauseMenu._is_menu_key(tab), "moving through the controls")
	var group := InputEventKey.new()
	group.keycode = KEY_1
	assert_false(PauseMenu._is_menu_key(group), "a control group stays with the paused map")
	var stop := InputEventKey.new()
	stop.keycode = KEY_S
	assert_false(PauseMenu._is_menu_key(stop))


func test_the_real_catalog_loads() -> void:
	var real: HintCatalog = load(CATALOG)
	assert_gte(real.hints.size(), 9)
	var ids: Array[StringName] = []
	for hint: HintDef in real.hints:
		assert_false(ids.has(hint.id), "ids are unique")
		ids.append(hint.id)
	for wanted: StringName in [&"select_move", &"build_reactor", &"storm", &"sabotage"]:
		assert_true(ids.has(wanted), "has %s" % wanted)


func test_going_under_a_crown_fires_the_canopy_hint_for_own_units_only() -> void:
	var canopy: HintDef = _hint(&"canopy", HintDef.TRIGGER_CANOPY_COVER)
	_catalog.hints.append(canopy)
	_director.begin(&"conquest")
	_due_ids()
	var fixture: EconomyFixture = EconomyFixture.new(self)
	var enemy: Unit = fixture.world.spawn_unit(fixture.ranger, 1, Vector3.ZERO)
	var own: Unit = fixture.world.spawn_unit(fixture.ranger, 0, Vector3(5, 0, 0))
	Events.canopy_cover_changed.emit(enemy, true)
	assert_eq(_due_ids(), [] as Array[StringName], "not for the enemy's units")
	Events.canopy_cover_changed.emit(own, false)
	assert_eq(_due_ids(), [] as Array[StringName], "not on coming out")
	Events.canopy_cover_changed.emit(own, true)
	assert_eq(_due_ids(), [&"canopy"] as Array[StringName], "the player's unit went under")
	fixture.dispose()
	var real: HintCatalog = load(CATALOG)
	var triggers: Dictionary[StringName, StringName] = {}
	for hint: HintDef in real.hints:
		triggers[hint.id] = hint.trigger
	var canopy_trigger: StringName = triggers.get(&"canopy", &"")
	var air_trigger: StringName = triggers.get(&"air_units", &"")
	assert_eq(canopy_trigger, HintDef.TRIGGER_CANOPY_COVER, "Verdance's hint")
	assert_eq(air_trigger, HintDef.TRIGGER_SELECTED, "and the Talon's")
