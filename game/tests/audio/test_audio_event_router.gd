extends GutTest
## AudioEventRouter wired to the real Events bus, with playback captured.


class FakeUnit:
	extends Node3D
	var def: EntityDef
	var faction: int = 0


var _router: AudioEventRouter
var _played: Array[Array] = []


func before_each() -> void:
	_played.clear()
	_router = AudioEventRouter.new()
	_router.play_first = func(ids: Array[StringName], at: Vector3) -> StringName:
		_played.append([ids, at])
		return ids[0]
	add_child_autofree(_router)


func _unit(sound_set: StringName) -> FakeUnit:
	var unit: FakeUnit = FakeUnit.new()
	unit.def = EntityDef.new()
	unit.def.sound_set = sound_set
	add_child_autofree(unit)
	return unit


func test_selecting_forty_units_plays_one_reply() -> void:
	var units: Array[Node3D] = []
	for i: int in 40:
		units.append(_unit(&"bulwark" if i < 25 else &"ranger"))
	Events.selection_changed.emit(units)
	assert_eq(_played.size(), 1)
	var ids: Array[StringName] = _played[0][0]
	assert_eq(ids[0], &"unit_bulwark_select")


func test_player_move_order_replies_and_pings_the_ground() -> void:
	var units: Array[Node3D] = [_unit(&"kite"), _unit(&"kite")]
	var command: Command = Command.new(&"move", 0, units)
	command.target_position = Vector3(4, 0, 9)
	Events.command_issued.emit(command)
	assert_eq(_played.size(), 2)
	var reply: Array[StringName] = _played[0][0]
	var ping: Array[StringName] = _played[1][0]
	var at: Vector3 = _played[1][1]
	assert_eq(reply[0], &"unit_kite_move")
	assert_eq(ping[0], &"world_order_ping")
	assert_eq(at, Vector3(4, 0, 9))


func test_enemy_orders_are_silent() -> void:
	var units: Array[Node3D] = [_unit(&"ranger")]
	Events.command_issued.emit(Command.new(&"move", 1, units))
	assert_eq(_played.size(), 0)


func test_ui_feedback_falls_back_to_invalid() -> void:
	Events.ui_feedback.emit(&"invalid_target")
	var ids: Array[StringName] = _played[0][0]
	assert_eq(ids, [&"ui_invalid_target", &"ui_invalid"] as Array[StringName])
