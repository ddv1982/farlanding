extends GutTest


func _field() -> HeightField:
	# 2 x 2 samples, 10 m apart: heights 0, 10 / 20, 30.
	return HeightField.new(Vector2.ZERO, 10.0, 2, 2, PackedFloat32Array([0, 10, 20, 30]))


func test_samples_grid_points() -> void:
	var field: HeightField = _field()
	assert_almost_eq(field.sample(0, 0), 0.0, 1e-4)
	assert_almost_eq(field.sample(10, 0), 10.0, 1e-4)
	assert_almost_eq(field.sample(0, 10), 20.0, 1e-4)
	assert_almost_eq(field.sample(10, 10), 30.0, 1e-4)


func test_interpolates_between_samples() -> void:
	assert_almost_eq(_field().sample(5, 5), 15.0, 1e-4)


func test_clamps_outside() -> void:
	assert_almost_eq(_field().sample(-50, 100), 20.0, 1e-4)


func test_empty_field_is_flat() -> void:
	assert_eq(HeightField.new().sample(3, 4), 0.0)
