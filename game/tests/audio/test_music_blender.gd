extends GutTest
## MusicBlender: state hold, deferred calming, layer fades.


func _blender() -> MusicBlender:
	var blender: MusicBlender = MusicBlender.new()
	blender.min_hold = 8.0
	blender.fade_seconds = 2.0
	return blender


func test_first_state_applies_immediately() -> void:
	var blender: MusicBlender = _blender()
	assert_true(blender.request(&"explore", 0, 0.0))
	assert_eq(blender.current_state, &"explore")


func test_more_intense_state_applies_immediately() -> void:
	var blender: MusicBlender = _blender()
	blender.request(&"explore", 0, 0.0)
	assert_true(blender.request(&"combat", 2, 1.0))
	assert_eq(blender.current_state, &"combat")


func test_calmer_state_waits_for_the_hold_time() -> void:
	var blender: MusicBlender = _blender()
	blender.request(&"explore", 0, 0.0)
	blender.request(&"combat", 2, 1.0)
	assert_false(blender.request(&"explore", 0, 3.0))
	assert_eq(blender.current_state, &"combat")
	assert_eq(blender.poll(5.0), &"")
	assert_eq(blender.poll(9.1), &"explore")
	assert_eq(blender.current_state, &"explore")


func test_returning_to_the_current_state_cancels_a_pending_one() -> void:
	var blender: MusicBlender = _blender()
	blender.request(&"combat", 2, 0.0)
	blender.request(&"explore", 0, 1.0)
	blender.request(&"combat", 2, 2.0)
	assert_eq(blender.pending_state(), &"")
	assert_eq(blender.poll(20.0), &"")


func test_layers_fade_over_fade_seconds() -> void:
	var blender: MusicBlender = _blender()
	blender.set_targets(PackedFloat32Array([0.0, -80.0]))
	var half: PackedFloat32Array = blender.step(1.0)
	assert_almost_eq(half[0], linear_to_db(0.5), 0.01)
	assert_eq(half[1], AudioMix.SILENT_DB)
	var full: PackedFloat32Array = blender.step(1.5)
	assert_almost_eq(full[0], 0.0, 0.001)


func test_snap_jumps_to_targets() -> void:
	var blender: MusicBlender = _blender()
	blender.set_targets(PackedFloat32Array([-6.0]))
	blender.snap()
	assert_almost_eq(blender.step(0.0)[0], -6.0, 0.01)
