extends GutTest
## What a mouse click means in the classic (C&C) and modern schemes, and the
## SelectionController applying it.

const CLASSIC: StringName = &"classic"
const MODERN: StringName = &"modern"
const LEFT: MouseButton = MOUSE_BUTTON_LEFT
const RIGHT: MouseButton = MOUSE_BUTTON_RIGHT

var _f: DiscoveryFixture
var _scheme: StringName


func before_each() -> void:
	_f = DiscoveryFixture.new(self)
	_scheme = Settings.control_scheme


func after_each() -> void:
	Settings.control_scheme = _scheme
	_f.dispose()


func _resolve(
	scheme: StringName,
	button: MouseButton,
	units: Array[Unit],
	target: Node3D,
	building: Building = null
) -> StringName:
	return SelectionRules.resolve(scheme, button, units, building, target, 0)


func test_classic_left_selects_own_and_commands_the_rest() -> void:
	var soldier: Unit = _f.spawn(_f.combat.soldier, 0, Vector3.ZERO)
	var other: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(5, 0, 0))
	var enemy: Unit = _f.spawn(_f.combat.soldier, 1, Vector3(20, 0, 0))
	var none: Array[Unit] = []
	var some: Array[Unit] = [soldier]
	assert_eq(_resolve(CLASSIC, LEFT, none, other), SelectionRules.CLICK_SELECT)
	assert_eq(_resolve(CLASSIC, LEFT, none, null), SelectionRules.CLICK_SELECT)
	assert_eq(_resolve(CLASSIC, LEFT, some, other), SelectionRules.CLICK_SELECT)
	assert_eq(_resolve(CLASSIC, LEFT, some, null), SelectionRules.CLICK_MOVE)
	assert_eq(_resolve(CLASSIC, LEFT, some, enemy), SelectionRules.CLICK_ATTACK)
	enemy.is_visible_to_player = false
	assert_eq(_resolve(CLASSIC, LEFT, some, enemy), SelectionRules.CLICK_MOVE, "unseen: ground")


func test_classic_right_click_deselects() -> void:
	var soldier: Unit = _f.spawn(_f.combat.soldier, 0, Vector3.ZERO)
	var enemy: Unit = _f.spawn(_f.combat.soldier, 1, Vector3(20, 0, 0))
	assert_eq(_resolve(CLASSIC, RIGHT, [soldier], enemy), SelectionRules.CLICK_DESELECT)
	assert_eq(_resolve(CLASSIC, RIGHT, [soldier], null), SelectionRules.CLICK_DESELECT)


func test_both_schemes_share_the_context_rules() -> void:
	var scanner: Unit = _f.spawn(_f.surveyor, 0, Vector3.ZERO)
	var hauler: Unit = _f.spawn(_f.base.hauler, 0, Vector3(3, 0, 0))
	var fabricator: Unit = _f.spawn(_f.base.fabricator, 0, Vector3(6, 0, 0))
	var site: DiscoverySite = _f.site(_f.discovery(&"seam"), Vector3(30, 0, 0))
	var deposit: ResourceNode = _f.world.spawn_resource_node(_f.base.deposit, Vector3(-30, 0, 0))
	var build: Building = _f.world.spawn_building(_f.base.reactor, 0, Vector3(0, 0, 30), false)
	var enemy_base: Building = _f.world.spawn_building(_f.combat.hq, 1, Vector3(0, 0, -40), true)
	var cases: Array[Array] = [
		[[scanner], site, SelectionRules.CLICK_SCAN],
		[[hauler], site, SelectionRules.CLICK_MOVE],
		[[hauler], deposit, SelectionRules.CLICK_HARVEST],
		[[fabricator], build, SelectionRules.CLICK_ASSIST],
		[[scanner], enemy_base, SelectionRules.CLICK_ATTACK],
	]
	for case: Array in cases:
		var listed: Array = case[0]
		var units: Array[Unit] = []
		units.assign(listed)
		var target: Node3D = case[1]
		var expected: StringName = case[2]
		assert_eq(_resolve(CLASSIC, LEFT, units, target), expected, "classic left on %s" % target)
		assert_eq(_resolve(MODERN, RIGHT, units, target), expected, "modern right on %s" % target)
	_f.world.discovery.resolve(site, 0)
	assert_eq(
		_resolve(CLASSIC, LEFT, [scanner], site), SelectionRules.CLICK_MOVE, "resolved: ground"
	)


func test_classic_left_on_an_own_finished_building_selects_it() -> void:
	var soldier: Unit = _f.spawn(_f.combat.soldier, 0, Vector3.ZERO)
	var done: Building = _f.world.spawn_building(_f.base.reactor, 0, Vector3(0, 0, 30), true)
	assert_eq(_resolve(CLASSIC, LEFT, [soldier], done), SelectionRules.CLICK_SELECT)
	assert_eq(_resolve(MODERN, RIGHT, [soldier], done), SelectionRules.CLICK_MOVE)


func test_rally_point_with_a_producer_selected() -> void:
	var barracks: Building = _f.world.spawn_building(_f.base.barracks, 0, Vector3(0, 0, 30), true)
	var reactor: Building = _f.world.spawn_building(_f.base.reactor, 0, Vector3(30, 0, 30), true)
	var none: Array[Unit] = []
	assert_eq(_resolve(CLASSIC, LEFT, none, null, barracks), SelectionRules.CLICK_RALLY)
	assert_eq(_resolve(CLASSIC, LEFT, none, reactor, barracks), SelectionRules.CLICK_SELECT)
	assert_eq(_resolve(CLASSIC, RIGHT, none, null, barracks), SelectionRules.CLICK_DESELECT)
	assert_eq(_resolve(MODERN, RIGHT, none, null, barracks), SelectionRules.CLICK_RALLY)
	assert_eq(_resolve(MODERN, LEFT, none, null, barracks), SelectionRules.CLICK_SELECT)
	assert_eq(_resolve(CLASSIC, LEFT, none, null, reactor), SelectionRules.CLICK_SELECT, "no rally")


func test_modern_left_selects_and_attacks_right_commands() -> void:
	var soldier: Unit = _f.spawn(_f.combat.soldier, 0, Vector3.ZERO)
	var enemy: Unit = _f.spawn(_f.combat.soldier, 1, Vector3(20, 0, 0))
	var none: Array[Unit] = []
	assert_eq(_resolve(MODERN, LEFT, [soldier], null), SelectionRules.CLICK_SELECT)
	assert_eq(_resolve(MODERN, LEFT, [soldier], enemy), SelectionRules.CLICK_ATTACK)
	assert_eq(_resolve(MODERN, LEFT, none, enemy), SelectionRules.CLICK_NONE)
	assert_eq(_resolve(MODERN, RIGHT, [soldier], null), SelectionRules.CLICK_MOVE)
	assert_eq(_resolve(MODERN, RIGHT, none, null), SelectionRules.CLICK_NONE)
	assert_eq(SelectionRules.command_button(&"modern"), RIGHT)
	assert_eq(SelectionRules.command_button(&"classic"), LEFT)


func _controller() -> SelectionController:
	var controller: SelectionController = SelectionController.new()
	controller.world = _f.world
	add_child_autofree(controller)
	return controller


func test_controller_classic_commands_with_left_and_deselects_with_right() -> void:
	Settings.control_scheme = CLASSIC
	var controller: SelectionController = _controller()
	var scanner: Unit = _f.spawn(_f.surveyor, 0, Vector3.ZERO)
	var site: DiscoverySite = _f.site(_f.discovery(&"seam"), Vector3(10, 0, 0))
	assert_eq(
		controller.apply_click(LEFT, scanner, Vector3.INF, false), SelectionRules.CLICK_SELECT
	)
	assert_eq(controller.selection, [scanner] as Array[Unit])
	assert_eq(controller.apply_click(LEFT, site, Vector3.INF, false), SelectionRules.CLICK_SCAN)
	_f.tick(10)
	assert_true(site.is_being_scanned, "the scan order went through the command queue")
	assert_eq(
		controller.apply_click(RIGHT, null, Vector3.INF, false), SelectionRules.CLICK_DESELECT
	)
	assert_true(controller.selection.is_empty())


func test_controller_sets_a_rally_point_and_deselects_the_building() -> void:
	Settings.control_scheme = CLASSIC
	var controller: SelectionController = _controller()
	var barracks: Building = _f.world.spawn_building(_f.base.barracks, 0, Vector3(0, 0, 30), true)
	controller.select_building(barracks)
	controller.apply_click(LEFT, null, Vector3(10, 0, 10), false)
	_f.tick(1)
	assert_true(barracks.producer.has_rally_point)
	assert_eq(barracks.producer.rally_point, Vector3(10, 0, 10))
	controller.apply_click(RIGHT, null, Vector3.INF, false)
	assert_null(controller.selected_building)


func test_right_click_cancels_placement_in_both_schemes() -> void:
	for scheme: StringName in [CLASSIC, MODERN]:
		Settings.control_scheme = scheme
		var controller: SelectionController = _controller()
		var fabricator: Unit = _f.spawn(_f.base.fabricator, 0, Vector3.ZERO)
		controller.set_selection([fabricator] as Array[Unit])
		controller.begin_placement(_f.base.reactor)
		assert_true(controller.placement.is_active())
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = RIGHT
		click.pressed = true
		controller._unhandled_input(click)
		assert_false(controller.placement.is_active(), "cancelled in %s" % scheme)
		assert_false(controller.selection.is_empty(), "cancelling keeps the selection")


func test_right_click_cancels_aiming_a_field_option() -> void:
	var controller: SelectionController = _controller()
	var lab: Building = _f.world.spawn_building(_f.lab, 0, Vector3(0, 0, 30), true)
	controller.begin_field_option(lab, _f.orbital_scan)
	assert_true(controller.is_targeting())
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = RIGHT
	click.pressed = true
	controller._unhandled_input(click)
	assert_false(controller.is_targeting())


func test_cursors_are_drawn_for_every_action() -> void:
	for kind: StringName in CursorIcons.COLORS:
		var image: Image = CursorIcons.build_image(kind)
		assert_false(image.is_invisible(), "%s has pixels" % kind)
		assert_not_null(CursorIcons.get_cursor(kind))
