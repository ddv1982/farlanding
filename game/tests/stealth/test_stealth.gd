extends GutTest
## Stealth on the vision grid: concealment, suspicion that rises with closeness and
## only inside the sight cone, decays when nothing is seen, the notice and spotted
## events, and reduced reach for low signatures.

var _f: MissionFixture
var _raised: Array = []
var _spotted: Array = []


func before_each() -> void:
	_f = MissionFixture.new(self)
	_raised.clear()
	_spotted.clear()
	Events.suspicion_raised.connect(_on_raised)
	Events.intruder_spotted.connect(_on_spotted)


func after_each() -> void:
	Events.suspicion_raised.disconnect(_on_raised)
	Events.intruder_spotted.disconnect(_on_spotted)
	_f.dispose()


func _on_raised(watcher: Node3D, target: Node3D) -> void:
	_raised.append([watcher, target])


func _on_spotted(watcher: Node3D, target: Node3D) -> void:
	_spotted.append([watcher, target])


## A guard at the origin looking toward -Z, and a Wisp at `at` holding still with
## stealth mode off (signature 0.5).
func _setup(at: Vector3, stealth_mode: bool = false) -> Array[Unit]:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO, 0.0)
	var wisp: Unit = _f.spawn(_f.wisp, 0, at)
	wisp.cloak.set_stealth_mode(stealth_mode)
	return [guard, wisp]


func test_a_low_signature_unit_is_concealed_until_spotted() -> void:
	var units: Array[Unit] = _setup(Vector3(0, 0, -6))
	var guard: Unit = units[0]
	var wisp: Unit = units[1]
	_f.tick(3)
	assert_true(_f.world.vision.grid.is_visible(1, wisp.sim_position()), "the cell is in sight")
	assert_false(_f.world.vision.can_see(1, wisp), "but the Wisp is concealed")
	assert_false(_f.world.combat.can_target(1, wisp))
	_f.tick(60)
	assert_almost_eq(guard.suspicion, 1.0, 0.001)
	assert_true(guard.is_alerted)
	assert_true(_f.world.vision.can_see(1, wisp), "spotted: now it is seen")
	assert_eq(_spotted.size(), 1)
	var spotted: Node3D = _spotted[0][1]
	assert_eq(spotted, wisp)


func test_full_signature_units_are_seen_as_usual() -> void:
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3.ZERO)
	var soldier: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 8))
	_f.tick(3)
	assert_true(_f.world.vision.can_see(1, soldier))
	assert_eq(guard.suspicion, 0.0, "no alert meter: plain units raise no suspicion")


func test_suspicion_rises_faster_when_closer() -> void:
	var near: Array[Unit] = _setup(Vector3(0, 0, -3))
	var far_guard: Unit = _f.spawn(_f.guard, 1, Vector3(40, 0, 0))
	var far_wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(40, 0, -8))
	far_wisp.cloak.set_stealth_mode(false)
	_f.tick(8)
	assert_gt(near[0].suspicion, 0.0)
	assert_gt(far_guard.suspicion, 0.0)
	assert_gt(near[0].suspicion, far_guard.suspicion * 1.5, "closer intruders are noticed faster")
	var stealth: StealthSystem = _f.world.stealth
	assert_gt(
		stealth.suspicion_rate(near[0], near[1], false),
		stealth.suspicion_rate(far_guard, far_wisp, false)
	)


func test_nothing_is_noticed_behind_the_cone_or_beyond_reach() -> void:
	var behind: Array[Unit] = _setup(Vector3(0, 0, 6))
	var side_guard: Unit = _f.spawn(_f.guard, 1, Vector3(50, 0, 0))
	# Signature 0.5 x sight 20 m = 10 m of reach: 14 m ahead is too far.
	var far_wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(50, 0, -14))
	far_wisp.cloak.set_stealth_mode(false)
	_f.tick(30)
	assert_eq(behind[0].suspicion, 0.0, "behind the guard")
	assert_eq(side_guard.suspicion, 0.0, "beyond signature-reduced reach")
	assert_false(_f.world.vision.can_see(1, behind[1]))


func test_very_close_intruders_are_noticed_all_round() -> void:
	var units: Array[Unit] = _setup(Vector3(0, 0, 2))
	_f.tick(10)
	assert_gt(units[0].suspicion, 0.0, "within CLOSE_RANGE the cone does not matter")


func test_suspicion_decays_after_the_intruder_leaves() -> void:
	var units: Array[Unit] = _setup(Vector3(0, 0, -5))
	_f.tick(4)
	var peak: float = units[0].suspicion
	assert_gt(peak, 0.0)
	assert_lt(peak, 1.0)
	units[1].locomotion.mover.position = Vector3(0, 0, 30)
	_f.tick(StealthSystem.HOLD_TICKS)
	assert_almost_eq(units[0].suspicion, peak, 0.05, "it holds a moment")
	_f.tick(30)
	assert_lt(units[0].suspicion, peak, "then decays")
	_f.tick(200)
	assert_eq(units[0].suspicion, 0.0)
	assert_false(units[0].is_alerted)


func test_suspicion_raised_fires_once_until_calm() -> void:
	var units: Array[Unit] = _setup(Vector3(0, 0, -5))
	_f.tick(8)
	assert_eq(_raised.size(), 1)
	var watcher: Node3D = _raised[0][0]
	assert_eq(watcher, units[0])
	units[1].locomotion.mover.position = Vector3(0, 0, 40)
	_f.tick(10)
	units[1].locomotion.mover.position = Vector3(0, 0, -5)
	_f.tick(8)
	assert_eq(_raised.size(), 1, "not again before it calmed down")


func test_watcher_remembers_where_it_noticed_something() -> void:
	var units: Array[Unit] = _setup(Vector3(1, 0, -5))
	_f.tick(4)
	assert_true(units[0].watcher.has_noticed)
	assert_almost_eq(units[0].watcher.last_noticed.x, 1.0, 0.01)
	assert_almost_eq(units[0].watcher.last_noticed.z, -5.0, 0.01)


func test_watcher_needs_its_grid_to_see_the_cell() -> void:
	var guard_def: UnitDef = _f.guard.duplicate()
	guard_def.vision_range = 2.0
	var guard: Unit = _f.spawn(guard_def, 1, Vector3.ZERO)
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, -1.5))
	wisp.cloak.set_stealth_mode(false)
	_f.tick(5)
	assert_gt(guard.suspicion, 0.0)
	# A watcher's reach never exceeds its own sight.
	assert_eq(guard.sight_range, 2.0)


func test_sensor_zero_never_notices() -> void:
	var blind: UnitDef = _f.guard.duplicate()
	blind.sensor = 0.0
	var guard: Unit = _f.spawn(blind, 1, Vector3.ZERO)
	_f.spawn(_f.wisp, 0, Vector3(0, 0, -3)).cloak.set_stealth_mode(false)
	_f.tick(30)
	assert_null(guard.watcher, "no sensor, no watcher")
	assert_eq(guard.suspicion, 0.0)


func test_attacking_reveals_the_attacker() -> void:
	# Damage dealt in the Wisp's name (it carries no gun of its own).
	var wisp: Unit = _f.spawn(_f.wisp, 0, Vector3(0, 0, 14))
	var victim: Unit = _f.spawn(_f.combat.soldier, 1, Vector3(0, 0, 0), PI)
	wisp.cloak.set_stealth_mode(false)
	_f.tick(3)
	assert_false(_f.world.vision.can_see(1, wisp))
	_f.world.combat.damage(victim, 5.0, &"light", wisp)
	_f.tick(1)
	assert_true(_f.world.vision.can_see(1, wisp), "a shooter shows itself")


func test_line_of_sight_is_blocked_by_terrain() -> void:
	var stealth: StealthSystem = StealthSystem.new()
	stealth.heights = HeightField.new()
	stealth.heights.origin = Vector2(-10, -10)
	stealth.heights.spacing = 1.0
	stealth.heights.columns = 21
	stealth.heights.rows = 21
	var samples: PackedFloat32Array = PackedFloat32Array()
	for z: int in 21:
		for x: int in 21:
			samples.append(6.0 if z == 10 else 0.0)
	stealth.heights.heights = samples
	assert_false(stealth.has_line_of_sight(Vector3(0, 0, -6), Vector3(0, 0, 6)), "a ridge between")
	assert_true(stealth.has_line_of_sight(Vector3(0, 0, -6), Vector3(0, 0, -1)))
