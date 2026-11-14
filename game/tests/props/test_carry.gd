extends GutTest
## Carrying an artefact (ADR 0014): the carry order sends the nearest able unit to
## lift it and the rest along as escort; the carrier is slowed and does not fight; it
## drops the artefact where it dies and any unit can lift it again; the enemy can
## take it. What is announced, the save of a carrier, and the two Recovery objectives
## (bring it home; keep it out of the enemy base).

var _f: MissionFixture
var _artefact_def: PropDef
var _feedback: Array[StringName] = []
var _alerts: Array[StringName] = []
var _lifted: Array[Node3D] = []


func before_each() -> void:
	_f = MissionFixture.new(self)
	_artefact_def = PropDef.new()
	_artefact_def.id = &"artefact"
	_artefact_def.size = Vector3(1.3, 1.0, 1.3)
	_artefact_def.blocks_movement = false
	_artefact_def.blocks_sight = false
	_artefact_def.carriable = true
	_feedback.clear()
	_alerts.clear()
	_lifted.clear()
	Events.ui_feedback.connect(_on_feedback)
	Events.advisor_alert.connect(_on_alert)
	Events.cargo_picked_up.connect(_on_lifted)


func after_each() -> void:
	Events.ui_feedback.disconnect(_on_feedback)
	Events.advisor_alert.disconnect(_on_alert)
	Events.cargo_picked_up.disconnect(_on_lifted)
	_f.dispose()


func _on_feedback(kind: StringName) -> void:
	_feedback.append(kind)


func _on_alert(kind: StringName) -> void:
	_alerts.append(kind)


func _on_lifted(carrier: Node3D, _cargo: Node3D) -> void:
	_lifted.append(carrier)


func _artefact(at: Vector3 = Vector3(20, 0, 0)) -> Prop:
	return _f.world.spawn_prop(_artefact_def, at)


func _soldier(faction: int, at: Vector3) -> Unit:
	return _f.spawn(_f.combat.soldier, faction, at)


func _carry(faction: int, units: Array[Node3D], prop: Prop) -> CarryCommand:
	var command: CarryCommand = CarryCommand.new(faction, units, prop)
	_f.push(command)
	_f.tick()
	return command


func _seconds(seconds: float) -> void:
	_f.tick(roundi(seconds * SimClock.TICK_RATE))


func test_the_nearest_lifts_it_and_the_rest_escort() -> void:
	var prop: Prop = _artefact()
	assert_true(prop.is_in_group(Prop.ARTEFACTS_GROUP), "audio hums for it")
	var far: Unit = _soldier(0, Vector3(-10, 0, 0))
	var near: Unit = _soldier(0, Vector3(5, 0, 0))
	var command: CarryCommand = _carry(0, [far, near] as Array[Node3D], prop)
	assert_eq(command.carrier, near, "the nearest is sent to lift it")
	_seconds(4.0)
	assert_true(near.is_carrying, "it lifted the artefact")
	assert_eq(prop.carrier, near)
	assert_true(prop.is_carried())
	assert_eq(_lifted, [near] as Array[Node3D])
	assert_eq(_feedback.count(&"artefact_pickup"), 1)
	assert_eq(_alerts.count(&"artefact_secured"), 1, "ours")
	assert_almost_eq(
		near.locomotion.mover.max_speed, _f.combat.soldier.move_speed * Carrier.SPEED_FACTOR, 0.01
	)
	assert_lt(far.sim_position().distance_to(prop.sim_position()), 12.0, "the escort came along")
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [near] as Array[Node3D], Vector3(20, 0, 20)))
	_seconds(8.0)
	assert_almost_eq(prop.sim_position().z, 20.0, 1.0, "it goes where its carrier goes")


func test_a_fast_unit_carries_no_faster_than_the_cap() -> void:
	var fast_def: UnitDef = _f.combat.soldier.duplicate() as UnitDef
	fast_def.move_speed = 13.0
	var fast: Unit = _f.spawn(fast_def, 0, Vector3.ZERO)
	var prop: Prop = _artefact(Vector3(3, 0, 0))
	_carry(0, [fast] as Array[Node3D], prop)
	_seconds(3.0)
	assert_true(fast.is_carrying, "it lifted the artefact")
	assert_almost_eq(fast.locomotion.mover.max_speed, Carrier.MAX_SPEED, 0.01, "capped")


func test_a_free_artefact_is_a_carry_target() -> void:
	var prop: Prop = _artefact()
	var unit: Unit = _soldier(0, Vector3.ZERO)
	assert_eq(SelectionRules.command_target([unit], prop, 0), SelectionRules.CLICK_CARRY)


func test_a_carrier_does_not_fight() -> void:
	var prop: Prop = _artefact(Vector3(2, 0, 0))
	var carrier: Unit = _soldier(0, Vector3.ZERO)
	_carry(0, [carrier] as Array[Node3D], prop)
	_seconds(1.0)
	assert_true(carrier.is_carrying)
	var enemy: Unit = _soldier(1, Vector3(6, 0, 0))
	_seconds(3.0)
	assert_lt(carrier.health.current, carrier.health.max_health, "it is shot at")
	assert_eq(enemy.health.current, enemy.health.max_health, "it never shoots back")


func test_it_drops_where_its_carrier_dies_and_anyone_can_lift_it_again() -> void:
	var prop: Prop = _artefact(Vector3(2, 0, 0))
	var first: Unit = _soldier(0, Vector3.ZERO)
	var second: Unit = _soldier(0, Vector3(-15, 0, 0))
	_carry(0, [first] as Array[Node3D], prop)
	_seconds(1.0)
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [first] as Array[Node3D], Vector3(0, 0, 15)))
	_seconds(2.0)
	var fell_at: Vector3 = first.sim_position()
	first.health.take(1.0e6, null)
	_f.tick()
	assert_false(prop.is_carried(), "it fell")
	assert_almost_eq(prop.position.x, fell_at.x, 0.3)
	assert_almost_eq(prop.position.z, fell_at.z, 0.3)
	assert_eq(_feedback.count(&"artefact_drop"), 1)
	_carry(0, [second] as Array[Node3D], prop)
	_seconds(6.0)
	assert_true(second.is_carrying, "picked up again")
	assert_eq(_alerts.count(&"artefact_secured"), 1, "still ours: not announced again")


func test_the_enemy_can_take_it_and_must_be_killed_for_it() -> void:
	var prop: Prop = _artefact(Vector3(2, 0, 0))
	var raider: Unit = _soldier(1, Vector3(4, 0, 0))
	var ours: Unit = _soldier(0, Vector3(-30, 0, 0))
	_carry(1, [raider] as Array[Node3D], prop)
	_seconds(1.0)
	assert_true(raider.is_carrying)
	assert_eq(_alerts.count(&"artefact_taken"), 1, "the player hears the enemy has it")
	assert_eq(_feedback.count(&"artefact_pickup"), 0, "no click for the enemy's pick-up")
	var command: CarryCommand = _carry(0, [ours] as Array[Node3D], prop)
	assert_null(command.carrier, "nobody can lift what someone carries")
	raider.health.take(1.0e6, null)
	_f.tick()
	_carry(0, [ours] as Array[Node3D], prop)
	_seconds(8.0)
	assert_true(ours.is_carrying)
	assert_eq(_alerts.count(&"artefact_secured"), 1, "won back")


func test_a_saved_carrier_lifts_its_cargo_again_quietly() -> void:
	var prop: Prop = _artefact(Vector3(2, 0, 0))
	var carrier: Unit = _soldier(0, Vector3.ZERO)
	_carry(0, [carrier] as Array[Node3D], prop)
	_seconds(1.0)
	var saved: Dictionary = carrier.carrier.to_dict()
	var prop_saved: Dictionary = prop.to_dict()
	var cargo_id: int = saved["cargo"]
	var lifted: bool = prop_saved["lifted"]
	assert_eq(cargo_id, prop.entity_id)
	assert_true(lifted)
	carrier.carrier.drop()
	var heard: int = _feedback.size() + _alerts.size()
	var restored: Unit = _soldier(0, Vector3(1, 0, 0))
	restored.carrier.from_dict(saved)
	restored.carrier.resolve_cargo(_f.world.entity)
	assert_true(restored.is_carrying)
	assert_eq(prop.carrier, restored)
	assert_eq(_feedback.size() + _alerts.size(), heard, "a load announces nothing")
	assert_almost_eq(
		restored.locomotion.mover.max_speed,
		_f.combat.soldier.move_speed * Carrier.SPEED_FACTOR,
		0.01,
		"slowed again"
	)


func test_carry_to_is_done_when_it_reaches_the_area() -> void:
	var prop: Prop = _artefact(Vector3(20, 0, 0))
	var carrier: Unit = _soldier(0, Vector3(16, 0, 0))
	var props: Dictionary = {
		"side": ObjectiveDef.SIDE_PLAYER,
		"defs": [_artefact_def] as Array[EntityDef],
		"area_center": Vector3(0, 0, -20),
		"area_radius": 5.0,
	}
	var mission: Mission = _f.start(
		(
			[MissionFixture.objective(&"bring", ObjectiveDef.TYPE_CARRY_TO, &"primary", props)]
			as Array[ObjectiveDef]
		)
	)
	var objective: Objective = mission.objective(&"bring")
	_f.tick(2)
	assert_true(objective.is_active())
	assert_eq(objective.progress_text, "Not yet found")
	_carry(0, [carrier] as Array[Node3D], prop)
	_seconds(2.0)
	assert_string_starts_with(objective.progress_text, "Carried:")
	_f.push(
		MoveCommand.new(MoveCommand.KIND_MOVE, 0, [carrier] as Array[Node3D], Vector3(0, 0, -20))
	)
	_seconds(12.0)
	assert_eq(objective.state, Objective.STATE_DONE)


func test_an_enemy_dropping_it_in_the_goal_delivers_nothing() -> void:
	var prop: Prop = _artefact(Vector3(2, 0, -20))
	var thief: Unit = _soldier(1, Vector3(4, 0, -20))
	var props: Dictionary = {
		"side": ObjectiveDef.SIDE_PLAYER,
		"defs": [_artefact_def] as Array[EntityDef],
		"area_center": Vector3(0, 0, -20),
		"area_radius": 8.0,
	}
	var mission: Mission = _f.start(
		(
			[MissionFixture.objective(&"bring", ObjectiveDef.TYPE_CARRY_TO, &"primary", props)]
			as Array[ObjectiveDef]
		)
	)
	var objective: Objective = mission.objective(&"bring")
	_carry(1, [thief] as Array[Node3D], prop)
	_seconds(2.0)
	assert_true(prop.is_carried(), "the enemy has it, inside the player's goal")
	thief.health.take(100000.0)
	_seconds(1.0)
	assert_false(prop.is_carried())
	assert_true(objective.is_active(), "dropped there by the enemy: not delivered")


func test_a_carried_prop_is_drawn_only_while_its_carrier_is_seen() -> void:
	var prop: Prop = _artefact(Vector3(20, 0, 0))
	var thief: Unit = _soldier(1, Vector3(17, 0, 0))
	_carry(1, [thief] as Array[Node3D], prop)
	_seconds(2.0)
	assert_true(prop.is_carried())
	thief.is_visible_to_player = false
	prop._process(0.1)
	assert_false(prop.visible, "it must not show where a hidden carrier is")
	thief.is_visible_to_player = true
	prop._process(0.1)
	assert_true(prop.visible)
	thief.is_visible_to_player = false
	prop._process(0.1)
	thief.health.take(100000.0)
	_seconds(0.5)
	prop._process(0.1)
	assert_true(prop.visible, "dropped, it is drawn like any prop")


func test_keep_from_enemy_fails_when_the_enemy_brings_it_home() -> void:
	var prop: Prop = _artefact(Vector3(2, 0, 0))
	var raider: Unit = _soldier(1, Vector3(4, 0, 0))
	var props: Dictionary = {
		"side": ObjectiveDef.SIDE_ENEMY,
		"passive": true,
		"defs": [_artefact_def] as Array[EntityDef],
		"area_center": Vector3(30, 0, 0),
		"area_radius": 6.0,
	}
	var mission: Mission = _f.start(
		(
			[
				MissionFixture.objective(
					&"keep", ObjectiveDef.TYPE_KEEP_FROM_ENEMY, &"primary", props
				)
			]
			as Array[ObjectiveDef]
		)
	)
	var objective: Objective = mission.objective(&"keep")
	_carry(1, [raider] as Array[Node3D], prop)
	_seconds(1.0)
	assert_true(objective.is_active())
	assert_eq(objective.progress_text, "The enemy has it!")
	var saved: Dictionary = objective.to_dict()
	assert_true(saved.has("holders"))
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 1, [raider] as Array[Node3D], Vector3(30, 0, 0)))
	_seconds(12.0)
	assert_eq(objective.state, Objective.STATE_FAILED)
