extends GutTest

var _ranger: UnitDef
var _kite: UnitDef


func before_each() -> void:
	_ranger = UnitDef.new()
	_kite = UnitDef.new()


func _unit(def: UnitDef, faction: int = 0) -> Unit:
	var unit: Unit = Unit.new()
	unit.def = def
	unit.faction = faction
	add_child_autofree(unit)
	return unit


func test_click_selects_only_clicked() -> void:
	var a: Unit = _unit(_ranger)
	var b: Unit = _unit(_ranger)
	assert_eq(SelectionRules.click([a], b, false, 0), [b] as Array[Unit])


func test_click_on_ground_clears() -> void:
	var a: Unit = _unit(_ranger)
	assert_eq(SelectionRules.click([a], null, false, 0), [] as Array[Unit])


func test_shift_click_on_ground_keeps() -> void:
	var a: Unit = _unit(_ranger)
	assert_eq(SelectionRules.click([a], null, true, 0), [a] as Array[Unit])


func test_shift_click_toggles() -> void:
	var a: Unit = _unit(_ranger)
	var b: Unit = _unit(_ranger)
	assert_eq(SelectionRules.click([a], b, true, 0), [a, b] as Array[Unit])
	assert_eq(SelectionRules.click([a, b], a, true, 0), [b] as Array[Unit])


func test_enemy_cannot_be_selected() -> void:
	var a: Unit = _unit(_ranger)
	var enemy: Unit = _unit(_ranger, 1)
	assert_eq(SelectionRules.click([a], enemy, false, 0), [] as Array[Unit])
	assert_eq(SelectionRules.box([], [a, enemy], false, 0), [a] as Array[Unit])


func test_box_replaces_or_adds() -> void:
	var a: Unit = _unit(_ranger)
	var b: Unit = _unit(_ranger)
	var c: Unit = _unit(_kite)
	assert_eq(SelectionRules.box([a], [b, c], false, 0), [b, c] as Array[Unit])
	assert_eq(SelectionRules.box([a], [b, a], true, 0), [a, b] as Array[Unit])
	assert_eq(SelectionRules.box([a], [], false, 0), [] as Array[Unit])


func test_same_type_picks_matching_def() -> void:
	var a: Unit = _unit(_ranger)
	var b: Unit = _unit(_ranger)
	var c: Unit = _unit(_kite)
	var enemy: Unit = _unit(_ranger, 1)
	assert_eq(SelectionRules.same_type([a, b, c, enemy], a, 0), [a, b] as Array[Unit])


func test_freed_units_drop_out() -> void:
	var a: Unit = _unit(_ranger)
	var doomed: Unit = Unit.new()
	add_child(doomed)
	var current: Array[Unit] = [a, doomed]
	doomed.free()
	assert_eq(SelectionRules.selectable(current, 0), [a] as Array[Unit])


func test_control_groups_store_and_recall() -> void:
	var groups: ControlGroups = ControlGroups.new()
	var a: Unit = _unit(_ranger)
	var doomed: Unit = Unit.new()
	add_child(doomed)
	groups.assign(3, [a, doomed])
	doomed.free()
	assert_eq(groups.recall(3), [a] as Array[Unit])
	assert_eq(groups.recall(4), [] as Array[Unit])


func test_hud_summary_counts_types() -> void:
	_ranger.display_name = "Ranger"
	_kite.display_name = "Kite"
	var entities: Array[Node3D] = [_unit(_ranger), _unit(_kite), _unit(_ranger)]
	assert_eq(Hud.summarize(entities), "3 selected: 2 Ranger, 1 Kite")
	assert_eq(Hud.summarize([]), "Nothing selected")


func test_left_click_resolution() -> void:
	var own: Unit = _unit(_ranger)
	var enemy: Unit = _unit(_ranger, 1)
	var none: Array[Unit] = []
	var some: Array[Unit] = [own]
	assert_eq(SelectionRules.left_click(none, own, 0), SelectionRules.CLICK_SELECT)
	assert_eq(SelectionRules.left_click(none, null, 0), SelectionRules.CLICK_SELECT)
	assert_eq(SelectionRules.left_click(none, enemy, 0), SelectionRules.CLICK_NONE)
	assert_eq(SelectionRules.left_click(some, own, 0), SelectionRules.CLICK_SELECT)
	assert_eq(SelectionRules.left_click(some, null, 0), SelectionRules.CLICK_SELECT)
	assert_eq(SelectionRules.left_click(some, enemy, 0), SelectionRules.CLICK_ATTACK)


func test_right_click_resolution() -> void:
	var own: Unit = _unit(_ranger)
	var enemy: Unit = _unit(_ranger, 1)
	var none: Array[Unit] = []
	var some: Array[Unit] = [own]
	assert_eq(SelectionRules.right_click(none, own, 0), SelectionRules.CLICK_NONE)
	assert_eq(SelectionRules.right_click(none, null, 0), SelectionRules.CLICK_NONE)
	assert_eq(SelectionRules.right_click(none, enemy, 0), SelectionRules.CLICK_NONE)
	assert_eq(SelectionRules.right_click(some, own, 0), SelectionRules.CLICK_MOVE)
	assert_eq(SelectionRules.right_click(some, null, 0), SelectionRules.CLICK_MOVE)
	assert_eq(SelectionRules.right_click(some, enemy, 0), SelectionRules.CLICK_ATTACK)


func test_enemies_are_not_selected_by_click() -> void:
	var enemy: Unit = _unit(_ranger, 1)
	assert_eq(SelectionRules.click([], enemy, false, 0), [] as Array[Unit])
