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


func _building(sound_set: StringName, faction: int = 0) -> FakeUnit:
	var building: FakeUnit = _unit(sound_set)
	building.faction = faction
	building.add_to_group(&"buildings")
	return building


func _first_ids() -> Array[StringName]:
	var ids: Array[StringName] = _played[0][0]
	return ids


func test_selecting_buildings_plays_one_machine_identity() -> void:
	var buildings: Array[Node3D] = [_building(&"reactor"), _building(&"reactor")]
	buildings.append(_building(&"refinery"))
	Events.selection_changed.emit(buildings)
	assert_eq(_played.size(), 1)
	assert_eq(_first_ids(), [&"building_reactor_select", &"ui_select"] as Array[StringName])


func test_units_win_over_buildings_in_a_mixed_selection() -> void:
	var mixed: Array[Node3D] = [_building(&"foundry"), _building(&"foundry"), _unit(&"hauler")]
	Events.selection_changed.emit(mixed)
	assert_eq(_first_ids()[0], &"unit_hauler_select")


func test_economy_one_shots_play_at_the_building_for_the_player_only() -> void:
	var own: FakeUnit = _building(&"reactor")
	own.position = Vector3(3, 0, 4)
	Events.building_placed.emit(own)
	Events.building_placed.emit(_building(&"reactor", 1))
	Events.construction_completed.emit(_building(&"foundry", 1))
	assert_eq(_played.size(), 1)
	assert_eq(_first_ids(), [&"base_place"] as Array[StringName])
	var at: Vector3 = _played[0][1]
	assert_eq(at, Vector3(3, 0, 4))


func test_queue_click_is_skipped_when_the_queue_just_moved_on() -> void:
	var bay: FakeUnit = _building(&"muster_bay")
	var unit: FakeUnit = _unit(&"ranger")
	Events.production_started.emit(bay, unit.def)
	Events.production_completed.emit(bay, unit)
	Events.production_started.emit(bay, unit.def)
	var all: Array[StringName] = []
	for entry: Array in _played:
		var ids: Array[StringName] = entry[0]
		all.append(ids[0])
	assert_eq(all, [&"ui_queue", &"base_unit_ready"] as Array[StringName])


func test_rally_order_sets_the_rally_sound_and_pings() -> void:
	var command: Command = Command.new(&"rally", 0, [_building(&"foundry")] as Array[Node3D])
	Events.command_issued.emit(command)
	assert_eq(_first_ids()[0], &"ui_rally_set")
	assert_eq(_played.size(), 2)


func test_advisor_alerts_are_throttled_and_never_stack() -> void:
	_router.event_seconds = func(_id: StringName) -> float: return 1.0
	_router.offer_advisor_alert(&"insufficient_resources", 1e5)
	_router.offer_advisor_alert(&"insufficient_resources", 1e5 + 1.0)
	_router.offer_advisor_alert(&"unit_ready", 1e5 + 0.5)
	assert_eq(_played.size(), 1, "one phrase at a time, repeat throttled")
	assert_eq(
		_first_ids(), [&"advisor_insufficient_resources", &"advisor_alert"] as Array[StringName]
	)
	assert_eq(_router.pump_advisor(1e5 + 1.0), &"", "still sounding")
	assert_eq(_router.pump_advisor(1e5 + 1.5), &"unit_ready")
	assert_eq(_played.size(), 2)
