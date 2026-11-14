extends GutTest
## Attack group behaviour: gather -> advance -> fight -> retreat -> done, regroup when
## strung out, fall back when badly outnumbered, and no command spam.

const HOME: Vector3 = Vector3(0, 0, 0)
const STAGING: Vector3 = Vector3(10, 0, 0)
const TARGET: Vector3 = Vector3(80, 0, 0)

var _f: AiFixture
var _port: AiFixture.FakePort


func before_each() -> void:
	_f = AiFixture.new(self)
	_port = AiFixture.FakePort.new(AiFixture.AI)


func after_each() -> void:
	_f.dispose()


func _group(units: Array[Unit], mode: StringName = AttackGroup.MODE_ATTACK) -> AttackGroup:
	var group: AttackGroup = AttackGroup.new(_port, _f.profile, units, mode, TARGET, HOME, STAGING)
	group.start()
	return group


## Puts every member at `point` (in a small cluster).
func _place(group: AttackGroup, point: Vector3) -> void:
	for i: int in group.members.size():
		group.members[i].locomotion.mover.position = point + Vector3(i % 3, 0, floori(i / 3.0))


func _step(group: AttackGroup, ticks: int = 5) -> void:
	_port.tick += ticks
	group.tick(_port.tick)


func test_gathers_then_advances_on_the_target() -> void:
	var group: AttackGroup = _group(_f.soldiers(6, Vector3(-30, 0, 0)))
	assert_eq(group.state(), AttackGroup.GATHER)
	assert_eq(_port.last_kind(), MoveCommand.KIND_MOVE)
	assert_eq(_port.pushed[0].target_position, STAGING)
	_step(group)
	assert_eq(group.state(), AttackGroup.GATHER, "still on the way to the staging point")
	_place(group, STAGING)
	_step(group)
	assert_eq(group.state(), AttackGroup.ADVANCE)
	assert_eq(_port.pushed[_port.pushed.size() - 1].target_position, TARGET)


func test_fights_what_it_meets_focusing_the_armed() -> void:
	var group: AttackGroup = _group(_f.soldiers(6, STAGING))
	_step(group)
	assert_eq(group.state(), AttackGroup.ADVANCE)
	var hauler: Unit = _f.unit(_f.scout, Vector3(40, 0, 0), AiFixture.ENEMY)
	var rifle: Unit = _f.unit(_f.soldier, Vector3(45, 0, 0), AiFixture.ENEMY)
	_port.enemies = [hauler, rifle]
	_step(group)
	assert_eq(group.state(), AttackGroup.FIGHT)
	_step(group)
	assert_eq(_port.last_kind(), AttackCommand.KIND)
	assert_eq(_port.pushed[_port.pushed.size() - 1].target_entity, rifle, "armed first")
	rifle.health.take(10000.0)
	_step(group)
	assert_eq(group.focus, hauler, "then the rest")


func test_falls_back_when_badly_outnumbered_and_ends_at_home() -> void:
	var group: AttackGroup = _group(_f.soldiers(3, STAGING))
	_step(group)
	var tanks: Array[Node3D] = []
	for i: int in 4:
		tanks.append(_f.unit(_f.tank, Vector3(40, 0, i * 3), AiFixture.ENEMY))
	_port.enemies = tanks
	_step(group)
	_step(group)
	assert_eq(group.state(), AttackGroup.RETREAT)
	assert_eq(group.retreat_reason, &"outnumbered")
	assert_eq(_port.pushed[_port.pushed.size() - 1].target_position, HOME)
	_port.enemies = []
	_place(group, HOME)
	_step(group)
	assert_true(group.finished)


func test_regroups_when_the_column_strings_out() -> void:
	var units: Array[Unit] = _f.soldiers(6, STAGING)
	var group: AttackGroup = _group(units)
	_step(group)
	assert_eq(group.state(), AttackGroup.ADVANCE)
	for i: int in 3:
		units[i].locomotion.mover.position = Vector3(90, 0, i)
	_step(group)
	assert_eq(group.state(), AttackGroup.REGROUP)
	_place(group, Vector3(30, 0, 0))
	_step(group)
	assert_eq(group.state(), AttackGroup.ADVANCE)


func test_stragglers_that_cannot_catch_up_are_left_behind() -> void:
	var units: Array[Unit] = _f.soldiers(6, STAGING)
	var group: AttackGroup = _group(units)
	_step(group)
	for i: int in 2:
		units[i].locomotion.mover.position = Vector3(10, 0, 90)
	_step(group)
	assert_eq(group.state(), AttackGroup.REGROUP)
	_step(group, CommanderDifficulty.ticks(_f.profile.gather_timeout_seconds) + 5)
	assert_eq(group.state(), AttackGroup.ADVANCE, "it goes on")
	assert_eq(group.members.size(), 4, "without the two stuck far away")
	assert_false(group.has_member(units[0]))


func test_a_defence_never_runs_and_goes_home_when_clear() -> void:
	var group: AttackGroup = _group(_f.soldiers(2, HOME), AttackGroup.MODE_DEFEND)
	assert_eq(group.state(), AttackGroup.ADVANCE, "defenders go at once")
	var tanks: Array[Node3D] = []
	for i: int in 5:
		tanks.append(_f.unit(_f.tank, Vector3(70, 0, i * 3), AiFixture.ENEMY))
	_port.enemies = tanks
	_step(group)
	_step(group)
	assert_eq(group.state(), AttackGroup.FIGHT, "outnumbered, but this is home")
	_port.enemies = []
	for i: int in AttackGroup.QUIET_STEPS:
		_step(group)
	assert_eq(group.state(), AttackGroup.RETREAT)
	assert_eq(group.retreat_reason, &"clear")


func test_a_recalled_wave_turns_home() -> void:
	var group: AttackGroup = _group(_f.soldiers(4, STAGING))
	_step(group)
	group.recall()
	assert_eq(group.state(), AttackGroup.RETREAT)
	assert_eq(group.retreat_reason, &"recalled")


func test_gives_up_on_an_unreachable_target_without_spamming() -> void:
	# Members stay idle where they are (the fake port executes nothing): every re-order
	# fails, so the group gives up after a few tries instead of ordering forever.
	var group: AttackGroup = _group(_f.soldiers(4, STAGING))
	for i: int in 200:
		_step(group)
	assert_true(group.finished or group.state() == AttackGroup.RETREAT)
	assert_lt(_port.commands_pushed, 30, "orders are rate-limited")


func test_dead_members_are_dropped_and_an_empty_group_ends() -> void:
	var units: Array[Unit] = _f.soldiers(2, STAGING)
	var group: AttackGroup = _group(units)
	for unit: Unit in units:
		unit.health.take(10000.0)
	_step(group)
	assert_true(group.finished)


func test_reading_the_group_right_after_a_member_is_freed_is_safe() -> void:
	var units: Array[Unit] = _f.soldiers(3, STAGING)
	var group: AttackGroup = _group(units)
	units[0].free()
	assert_eq(group.centroid(), (units[1].sim_position() + units[2].sim_position()) / 2.0)
	assert_eq(group.members.size(), 2)
	assert_almost_eq(group.strength(), 100.0, 0.01)


func test_a_hunting_group_saves_that_it_is_searching() -> void:
	var group: AttackGroup = _group(_f.soldiers(2, STAGING))
	var plain: bool = group.to_dict()["searching"]
	assert_false(plain, "an ordinary wave is not")
	group.searching = true
	var hunting: bool = group.to_dict()["searching"]
	assert_true(hunting, "a hunt is, and says so in its save")
