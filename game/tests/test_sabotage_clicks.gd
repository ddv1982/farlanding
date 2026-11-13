extends GutTest
## Sabotage goes through the one click-resolution path: a squad of Wisps on a working
## enemy building in sight sabotages it (both schemes); with an armed unit in the
## selection the click attacks; the controller turns it into a SabotageCommand.

var _f: MissionFixture
var _scheme: StringName


func before_each() -> void:
	_f = MissionFixture.new(self)
	_scheme = Settings.control_scheme


func after_each() -> void:
	Settings.control_scheme = _scheme
	_f.dispose()


func test_wisps_sabotage_an_enemy_building_in_sight() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3.ZERO)
	var uplink: Building = _f.world.spawn_building(_f.target, 1, Vector3(0, 0, -15), true)
	uplink.is_visible_to_player = true
	var wisps: Array[Unit] = [wisp]
	assert_eq(SelectionRules.command_target(wisps, uplink, 0), SelectionRules.CLICK_SABOTAGE)
	assert_eq(
		SelectionRules.resolve(Settings.SCHEME_CLASSIC, MOUSE_BUTTON_LEFT, wisps, null, uplink, 0),
		SelectionRules.CLICK_SABOTAGE
	)
	assert_eq(
		SelectionRules.resolve(Settings.SCHEME_MODERN, MOUSE_BUTTON_RIGHT, wisps, null, uplink, 0),
		SelectionRules.CLICK_SABOTAGE
	)


func test_armed_company_attacks_instead() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3.ZERO)
	var soldier: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(3, 0, 0))
	var uplink: Building = _f.world.spawn_building(_f.target, 1, Vector3(0, 0, -15), true)
	uplink.is_visible_to_player = true
	assert_eq(
		SelectionRules.command_target([wisp, soldier] as Array[Unit], uplink, 0),
		SelectionRules.CLICK_ATTACK
	)


func test_unseen_or_dead_targets_are_not_sabotaged() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3.ZERO)
	var uplink: Building = _f.world.spawn_building(_f.target, 1, Vector3(0, 0, -15), true)
	uplink.is_visible_to_player = false
	assert_eq(
		SelectionRules.command_target([wisp] as Array[Unit], uplink, 0), SelectionRules.CLICK_MOVE
	)
	uplink.is_visible_to_player = true
	uplink.sabotage()
	assert_eq(
		SelectionRules.command_target([wisp] as Array[Unit], uplink, 0),
		SelectionRules.CLICK_ATTACK,
		"already sabotaged: nothing left to sabotage"
	)


func test_the_controller_issues_a_sabotage_command() -> void:
	Settings.control_scheme = Settings.SCHEME_CLASSIC
	var controller: SelectionController = SelectionController.new()
	controller.world = _f.world
	add_child_autofree(controller)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, -5))
	var uplink: Building = _f.world.spawn_building(_f.target, 1, Vector3(0, 0, -15), true)
	_f.tick(3)
	controller.set_selection([wisp] as Array[Unit])
	var action: StringName = controller.apply_click(
		MOUSE_BUTTON_LEFT, uplink, uplink.position, false
	)
	assert_eq(action, SelectionRules.CLICK_SABOTAGE)
	_f.tick(2)
	assert_eq(wisp.saboteur.target, uplink)


func test_sabotage_cursor_exists() -> void:
	assert_not_null(CursorIcons.get_cursor(CursorIcons.SABOTAGE))
	assert_eq(
		SelectionController.CURSOR_FOR_ACTION[SelectionRules.CLICK_SABOTAGE], CursorIcons.SABOTAGE
	)
