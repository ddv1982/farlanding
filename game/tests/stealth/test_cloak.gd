extends GutTest
## The Wisp's cloak: closes after holding still or creeping in stealth mode, opens
## when it runs, when stealth mode is switched off (a CloakCommand) or when hit; a
## cloaked unit has a lower signature and is noticed only much closer.

var _f: MissionFixture
var _changes: Array = []


func before_each() -> void:
	_f = MissionFixture.new(self)
	_changes.clear()
	Events.cloak_changed.connect(_on_cloak_changed)


func after_each() -> void:
	Events.cloak_changed.disconnect(_on_cloak_changed)
	_f.dispose()


func _on_cloak_changed(unit: Node3D, cloaked: bool) -> void:
	_changes.append([unit, cloaked])


func test_cloaks_after_holding_still() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3.ZERO)
	assert_false(wisp.is_cloaked)
	_f.tick(5)
	assert_false(wisp.is_cloaked, "not before the delay")
	_f.tick(7)
	assert_true(wisp.is_cloaked)
	assert_almost_eq(wisp.signature, _f.wisp.cloak_signature, 0.001)
	assert_eq(_changes, [[wisp, true]])


func test_stealth_mode_caps_speed_and_stays_cloaked_while_creeping() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3.ZERO)
	_f.tick(12)
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [wisp] as Array[Node3D], Vector3(0, 0, -30)))
	_f.tick(20)
	assert_lte(wisp.speed, _f.wisp.cloak_max_speed + 0.2, "creeps")
	assert_true(wisp.is_cloaked, "creeping keeps the cloak")


func test_switching_stealth_off_runs_in_the_open() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3.ZERO)
	_f.tick(12)
	_f.push(CloakCommand.new(0, [wisp] as Array[Node3D], false))
	_f.tick(1)
	assert_false(wisp.is_cloaked)
	assert_false(wisp.cloak.stealth_mode)
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [wisp] as Array[Node3D], Vector3(0, 0, -40)))
	_f.tick(20)
	assert_gt(wisp.speed, _f.wisp.cloak_max_speed + 1.0, "full speed")
	assert_false(wisp.is_cloaked)
	assert_almost_eq(wisp.signature, _f.wisp.signature, 0.001)


func test_cloak_command_ignores_other_factions_units() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3.ZERO)
	_f.push(CloakCommand.new(1, [wisp] as Array[Node3D], false))
	_f.tick(1)
	assert_true(wisp.cloak.stealth_mode)


func test_a_hit_opens_the_cloak_for_a_while() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3.ZERO)
	_f.tick(12)
	assert_true(wisp.is_cloaked)
	wisp.health.take(5.0, null)
	assert_false(wisp.is_cloaked)
	_f.tick(15)
	assert_false(wisp.is_cloaked, "still open during BREAK_SECONDS")
	_f.tick(25)
	assert_true(wisp.is_cloaked, "closes again once quiet")


func test_a_cloaked_wisp_must_come_much_closer_to_be_noticed() -> void:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, -6))
	_f.tick(1)
	var stealth: StealthSystem = _f.world.stealth
	# 6 m ahead: signature 0.5 reaches 10 m, but cloaked 0.2 only 4 m.
	assert_gt(stealth.suspicion_rate(guard, wisp, false), 0.0, "uncloaked: noticed")
	_f.tick(12)
	assert_true(wisp.is_cloaked)
	assert_eq(stealth.suspicion_rate(guard, wisp, false), 0.0, "cloaked: out of reach")
	wisp.locomotion.mover.position = Vector3(0, 0, -3.5)
	assert_gt(stealth.suspicion_rate(guard, wisp, false), 0.0, "close enough after all")


func test_cloak_state_saves_and_loads() -> void:
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3.ZERO)
	_f.tick(12)
	wisp.cloak.set_stealth_mode(true)
	var data: Dictionary = wisp.cloak.to_dict()
	var other: Unit = _f.spawn(_f.wisp, 0, Vector3(5, 0, 0))
	other.cloak.from_dict(data)
	assert_true(other.is_cloaked)
	assert_true(other.cloak.stealth_mode)
