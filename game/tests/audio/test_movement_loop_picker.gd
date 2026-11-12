extends GutTest
## MovementLoopPicker: nearest moving units, per-loop caps, range.


func test_picks_nearest_first_within_the_budget() -> void:
	var positions: PackedVector3Array = [
		Vector3(30, 0, 0), Vector3(5, 0, 0), Vector3(10, 0, 0), Vector3(1, 0, 0)
	]
	var events: Array[StringName] = [&"move_a", &"move_b", &"move_c", &"move_d"]
	var caps: Dictionary[StringName, int] = {}
	var chosen: PackedInt32Array = MovementLoopPicker.pick(
		positions, events, caps, Vector3.ZERO, 2, 100.0
	)
	assert_eq(chosen, PackedInt32Array([3, 1]))


func test_caps_identical_loops() -> void:
	var positions: PackedVector3Array = []
	var events: Array[StringName] = []
	for i: int in 10:
		positions.append(Vector3(i, 0, 0))
		events.append(&"move_ranger" if i < 8 else &"move_bulwark")
	var caps: Dictionary[StringName, int] = {&"move_ranger": 3, &"move_bulwark": 3}
	var chosen: PackedInt32Array = MovementLoopPicker.pick(
		positions, events, caps, Vector3.ZERO, 6, 100.0
	)
	assert_eq(chosen, PackedInt32Array([0, 1, 2, 8, 9]))


func test_ignores_units_out_of_range_and_height() -> void:
	var positions: PackedVector3Array = [Vector3(0, 50, 3), Vector3(80, 0, 0)]
	var events: Array[StringName] = [&"move_kite", &"move_kite"]
	var caps: Dictionary[StringName, int] = {}
	var chosen: PackedInt32Array = MovementLoopPicker.pick(
		positions, events, caps, Vector3.ZERO, 6, 45.0
	)
	assert_eq(chosen, PackedInt32Array([0]), "height is ignored, distance is on the ground")
