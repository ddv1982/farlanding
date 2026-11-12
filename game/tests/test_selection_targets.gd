extends GutTest
## What a right click on a building or resource node means for a selection.

var _f: EconomyFixture
var _hauler: Unit
var _fabricator: Unit
var _ranger: Unit


func before_each() -> void:
	_f = EconomyFixture.new(self)
	_hauler = _f.world.spawn_unit(_f.hauler, 0, Vector3(0, 0, 10))
	_fabricator = _f.world.spawn_unit(_f.fabricator, 0, Vector3(4, 0, 10))
	_ranger = _f.world.spawn_unit(_f.ranger, 0, Vector3(8, 0, 10))


func after_each() -> void:
	_f.dispose()


func _action(units: Array[Unit], target: Node3D) -> StringName:
	return SelectionRules.right_click_target(units, target, 0)


func test_haulers_harvest_a_deposit_others_move() -> void:
	var deposit: ResourceNode = _f.world.spawn_resource_node(_f.deposit, Vector3(30, 0, 0))
	assert_eq(_action([_hauler, _ranger], deposit), SelectionRules.CLICK_HARVEST)
	assert_eq(_action([_ranger], deposit), SelectionRules.CLICK_MOVE)
	assert_eq(SelectionRules.able([_hauler, _ranger], Harvester.KIND), [_hauler] as Array[Unit])


func test_fabricators_help_on_an_own_site() -> void:
	var site: Building = _f.world.spawn_building(_f.reactor, 0, Vector3(-30, 0, 0), false)
	var done: Building = _f.world.spawn_building(_f.reactor, 0, Vector3(-30, 0, 30), true)
	assert_eq(_action([_fabricator], site), SelectionRules.CLICK_ASSIST)
	assert_eq(_action([_fabricator], done), SelectionRules.CLICK_MOVE)
	assert_eq(_action([_ranger], site), SelectionRules.CLICK_MOVE)


func test_an_enemy_building_is_attacked() -> void:
	var enemy: Building = _f.world.spawn_building(_f.reactor, 1, Vector3(-30, 0, -30), true)
	assert_eq(_action([_ranger], enemy), SelectionRules.CLICK_ATTACK)
	assert_true(AttackCommand.is_valid_target(enemy, 0))
	assert_eq(_action([], enemy), SelectionRules.CLICK_NONE)
