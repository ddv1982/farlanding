extends GutTest
## The flow screens and the HUD's objective list: mission select shows the catalog,
## the briefing lists the objectives, the objectives panel follows the events, and
## the debrief shows a result.

var _catalog: MissionCatalog


func before_each() -> void:
	_catalog = load("res://data/missions/catalog.tres")


func test_mission_select_shows_one_card_per_mission() -> void:
	var select: MissionSelect = MissionSelect.new()
	add_child_autofree(select)
	select.show_catalog(_catalog)
	assert_eq(select.card_count(), _catalog.missions.size())
	assert_eq(select.card_count(), 6)
	watch_signals(select)
	select._on_card_pressed(_catalog.missions[2])
	assert_signal_emitted_with_parameters(select, "mission_chosen", [_catalog.missions[2]])


func test_briefing_lists_known_objectives_primary_first() -> void:
	var briefing: BriefingPanel = BriefingPanel.new()
	add_child_autofree(briefing)
	var mission: MissionDef = _catalog.missions[2]
	briefing.show_mission(mission)
	assert_eq(briefing._title.text, mission.title)
	var known: int = 0
	for objective: ObjectiveDef in mission.starting_objectives():
		if objective.kind != &"hidden":
			known += 1
	assert_eq(briefing._objectives.get_child_count(), known)


func test_objectives_panel_follows_the_events() -> void:
	var panel: ObjectivesPanel = ObjectivesPanel.new()
	add_child_autofree(panel)
	var objective: Objective = Objective.new()
	objective.id = &"a"
	objective.title = "Do a thing"
	var hidden: Objective = Objective.new()
	hidden.kind = Objective.KIND_HIDDEN
	hidden.is_known = false
	Events.objective_added.emit(objective)
	Events.objective_added.emit(hidden)
	assert_eq(panel.row_count(), 1, "unknown objectives are not listed")
	assert_true(panel.visible)
	objective.state = Objective.STATE_DONE
	Events.objective_completed.emit(objective)
	assert_eq(panel.row_count(), 1)
	Events.mission_started.emit()
	assert_eq(panel.row_count(), 0, "a new mission starts clean")


func test_objectives_panel_shows_the_alert_meter() -> void:
	var panel: ObjectivesPanel = ObjectivesPanel.new()
	add_child_autofree(panel)
	panel.show_alert_meter(1)
	assert_eq(panel._alert_value.text, "UNAWARE")
	Events.alert_level_changed.emit(1, &"alerted", &"unaware")
	assert_eq(panel._alert_value.text, "ALERTED")
	Events.alert_level_changed.emit(2, &"suspicious", &"unaware")
	assert_eq(panel._alert_value.text, "ALERTED", "other factions are not shown")


func test_debrief_shows_the_result() -> void:
	var debrief: DebriefPanel = DebriefPanel.new()
	add_child_autofree(debrief)
	var result: MissionResult = MissionResult.new()
	result.title = "Quiet Uplink"
	result.won = false
	result.seconds = 61.0
	result.objectives = [
		{"title": "Sabotage", "kind": &"primary", "state": &"failed"},
		{"title": "Stay undetected", "kind": &"secondary", "state": &"active"},
	]
	debrief.show_result(result)
	assert_eq(debrief._title.text, "Mission failed")
	assert_eq(debrief._objectives.get_child_count(), 2)
	assert_eq(debrief._stats.get_child_count(), 10)
