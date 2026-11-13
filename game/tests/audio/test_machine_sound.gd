extends GutTest
## Phase 8d, Hollow Meridian: the old engines (MachineSound and its pure rules,
## MachineCues). Machines are plain Node3D doubles (with `is_visible_to_player`
## for the fog); the router's one-shots are captured through `play_at`, its run
## loops are its own players. Signals are emitted by hand.

const ENEMY: int = 1


class FakeMachine:
	extends Node3D
	var is_visible_to_player: bool = true


class FakeBuilding:
	extends Node3D
	var faction: int = 0


var _sound: MachineSound
var _played: Array[StringName] = []
var _played_at: Array[Vector3] = []


func before_each() -> void:
	_played.clear()
	_played_at.clear()
	_sound = MachineSound.new()
	_sound.resolve_event = Audio.get_event
	_sound.play_at = func(id: StringName, at: Vector3) -> bool:
		_played.append(id)
		_played_at.append(at)
		return true
	add_child_autofree(_sound)
	_sound.set_process(false)


func after_each() -> void:
	_sound.handle_mission_started()


func _machine(at: Vector3) -> FakeMachine:
	var machine: FakeMachine = FakeMachine.new()
	add_child_autofree(machine)
	machine.global_position = at
	return machine


func _run(seconds: float) -> void:
	var steps: int = int(seconds / 0.1)
	for k: int in steps:
		_sound.advance(0.1)


# --- Pure rules -------------------------------------------------------------------


func test_rules() -> void:
	assert_eq(MachineCues.reactivated_event(0, 0, false), MachineCues.SPINUP, "ours, seen or not")
	assert_eq(MachineCues.reactivated_event(ENEMY, 0, true), MachineCues.SEIZED)
	assert_eq(MachineCues.reactivated_event(ENEMY, 0, false), &"", "unseen: silent")
	assert_eq(MachineCues.lost_event(0, 0), MachineCues.WINDDOWN)
	assert_eq(MachineCues.lost_event(ENEMY, 0), &"")
	assert_true(MachineCues.folds(10.5, 10.0))
	assert_false(MachineCues.folds(12.0, 10.0))


# --- The router -------------------------------------------------------------------


func test_our_engine_spins_up_then_hums_at_the_machine() -> void:
	var engine: FakeMachine = _machine(Vector3(12, 0, -5))
	assert_eq(_sound.handle_reactivated(engine, 0), MachineCues.SPINUP)
	assert_eq(_played_at[0], Vector3(12, 0, -5), "heard where the engine is")
	_run(1.0)
	assert_eq(_sound.humming_count(), 0, "the spin-up carries the first seconds")
	_run(MachineCues.RUN_DELAY)
	assert_eq(_sound.humming_count(), 1, "then the run loop takes over")
	assert_eq(_sound.running_count(), 1)


func test_losing_it_winds_down_and_the_hum_fades() -> void:
	var engine: FakeMachine = _machine(Vector3(5, 0, 5))
	_sound.handle_reactivated(engine, 0)
	_run(MachineCues.RUN_DELAY + 0.5)
	assert_eq(_sound.handle_lost(engine, 0), MachineCues.WINDDOWN)
	_run(MachineCues.HUM_FADE + 0.3)
	assert_eq(_sound.humming_count(), 0)
	assert_eq(_sound.running_count(), 0)


func test_the_enemy_seizing_one_in_view_is_colder() -> void:
	var engine: FakeMachine = _machine(Vector3(30, 0, 0))
	assert_eq(_sound.handle_reactivated(engine, ENEMY), MachineCues.SEIZED)
	_run(MachineCues.RUN_DELAY + 1.0)
	assert_eq(_sound.humming_count(), 0, "the enemy's engines do not hum for us")


func test_an_unseen_or_far_seizure_is_silent() -> void:
	var hidden: FakeMachine = _machine(Vector3(10, 0, 0))
	hidden.is_visible_to_player = false
	assert_eq(_sound.handle_reactivated(hidden, ENEMY), &"", "in the fog")
	var far: FakeMachine = _machine(Vector3(MachineCues.VIEW_RADIUS + 20.0, 0, 0))
	assert_eq(_sound.handle_reactivated(far, ENEMY), &"", "out of view")
	assert_eq(_played.size(), 0)
	assert_eq(_sound.handle_lost(far, ENEMY), &"", "the enemy losing one: its takeover says it")


func test_a_takeover_of_ours_is_one_gesture() -> void:
	var engine: FakeMachine = _machine(Vector3(8, 0, 0))
	_sound.handle_reactivated(engine, 0)
	_run(0.5)
	_played.clear()
	_sound.handle_lost(engine, 0)
	_sound.handle_reactivated(engine, ENEMY)  # the same frame: lost, then taken
	assert_eq(_played, [MachineCues.WINDDOWN] as Array[StringName], "the wind-down says it")
	_run(MachineCues.FOLD_SECONDS + 0.5)
	_sound.handle_lost(engine, ENEMY)
	assert_eq(_sound.handle_reactivated(engine, 0), MachineCues.SPINUP, "and we take it back")


func test_at_most_three_hums_nearest_first() -> void:
	var engines: Array[FakeMachine] = []
	for k: int in 5:
		var engine: FakeMachine = _machine(Vector3(8.0 * (k + 1), 0, 0))
		engines.append(engine)
		_sound.handle_reactivated(engine, 0)
	_run(MachineCues.RUN_DELAY + 2.0)
	assert_eq(_sound.running_count(), 5)
	assert_eq(_sound.humming_count(), MachineCues.MAX_HUMS)
	_sound.focus = Vector3(400, 0, 0)  # the camera moves far away
	_run(MachineCues.HUM_FADE + 0.5)
	assert_eq(_sound.humming_count(), 0, "out of earshot")


func test_signals_reach_the_router_and_mission_start_resets() -> void:
	var engine: FakeMachine = _machine(Vector3(3, 0, 3))
	Events.machine_reactivated.emit(engine, 0)
	assert_eq(_played, [MachineCues.SPINUP] as Array[StringName])
	assert_true(_sound.is_tracked(engine))
	_run(MachineCues.RUN_DELAY + 1.0)
	Events.mission_started.emit()
	assert_eq(_sound.running_count(), 0)
	assert_eq(_sound.humming_count(), 0)
	assert_false(_sound.is_tracked(engine))
	Events.machine_lost.emit(engine, 0)
	assert_eq(_played[-1], MachineCues.WINDDOWN)


func test_base_loops_leave_tracked_machines_alone() -> void:
	var loops: BaseLoops = BaseLoops.new()
	loops.resolve_event = Audio.get_event
	loops.claimed = _sound.is_tracked
	add_child_autofree(loops)
	loops.set_process(false)
	var engine: FakeBuilding = FakeBuilding.new()
	engine.add_to_group(BaseLoops.BUILDINGS_GROUP)
	add_child_autofree(engine)
	engine.global_position = Vector3(4, 0, 0)
	loops.rescan()
	assert_eq(loops.chosen().size(), 1, "an ordinary building hums")
	_sound.handle_reactivated(engine, 0)
	loops.rescan()
	assert_eq(loops.chosen().size(), 0, "an engine hums through the MachineSound only")


func test_engine_events_are_positional_on_the_buildings_bus() -> void:
	for id: StringName in [
		MachineCues.SPINUP, MachineCues.WINDDOWN, MachineCues.SEIZED, MachineCues.RUN
	]:
		var event: SoundEvent = Audio.get_event(id)
		assert_not_null(event, String(id))
		if event != null:
			assert_true(event.positional, String(id))
			assert_eq(event.bus, &"Buildings", String(id))
	assert_gt(
		Audio.get_event(MachineCues.SPINUP).longest_seconds(),
		MachineCues.RUN_DELAY,
		"the spin-up lasts until the run loop takes over"
	)
