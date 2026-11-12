extends GutTest


func test_slot_count_matches_unit_count() -> void:
	for count: int in [1, 2, 5, 12, 200]:
		var formation: Formation = Formation.new(count, Vector3.ZERO, Vector3.FORWARD, 3.0)
		assert_eq(formation.slots.size(), count)


func test_single_slot_is_the_target() -> void:
	var target: Vector3 = Vector3(10, 0, -4)
	var formation: Formation = Formation.new(1, target, Vector3.FORWARD, 3.0)
	assert_almost_eq(formation.slots[0], target, Vector3.ONE * 1e-4)


func test_slots_are_centred_on_target() -> void:
	var target: Vector3 = Vector3(5, 0, 5)
	var formation: Formation = Formation.new(9, target, Vector3(1, 0, 0), 2.0)
	var centre: Vector3 = Vector3.ZERO
	for slot: Vector3 in formation.slots:
		centre += slot
	centre /= 9.0
	assert_almost_eq(centre, target, Vector3.ONE * 1e-4)


func test_slots_are_spaced_apart() -> void:
	var formation: Formation = Formation.new(12, Vector3.ZERO, Vector3(1, 0, 1), 2.6)
	for i: int in formation.slots.size():
		for j: int in range(i + 1, formation.slots.size()):
			assert_gt(formation.slots[i].distance_to(formation.slots[j]), 2.59)


func test_formation_is_wider_than_deep() -> void:
	var formation: Formation = Formation.new(12, Vector3.ZERO, Vector3.FORWARD, 2.0)
	assert_gt(formation.row_sizes[0], formation.row_sizes.size())


func test_front_row_lies_ahead_along_forward() -> void:
	var forward: Vector3 = Vector3(0, 0, 1)
	var formation: Formation = Formation.new(6, Vector3.ZERO, forward, 2.0)
	assert_gt(formation.slots[0].dot(forward), formation.slots[5].dot(forward))


func test_assignment_uses_every_slot_once() -> void:
	var formation: Formation = Formation.new(7, Vector3.ZERO, Vector3.FORWARD, 2.0)
	var positions: PackedVector3Array = PackedVector3Array()
	for i: int in 7:
		positions.append(Vector3(randf_range(-20, 20), 0, randf_range(10, 40)))
	var assignment: PackedInt32Array = formation.assign(positions)
	var sorted: Array[int] = []
	for slot: int in assignment:
		sorted.append(slot)
	sorted.sort()
	assert_eq(sorted, [0, 1, 2, 3, 4, 5, 6] as Array[int])


func test_assignment_keeps_left_right_order() -> void:
	# A line abreast moving forward (-Z) keeps who is on the left.
	var formation: Formation = Formation.new(3, Vector3(0, 0, -50), Vector3.FORWARD, 2.0)
	var positions: PackedVector3Array = [Vector3(10, 0, 0), Vector3(-10, 0, 0), Vector3(0, 0, 0)]
	var assignment: PackedInt32Array = formation.assign(positions)
	var x_left: float = formation.slots[assignment[1]].x
	var x_mid: float = formation.slots[assignment[2]].x
	var x_right: float = formation.slots[assignment[0]].x
	assert_lt(x_left, x_mid)
	assert_lt(x_mid, x_right)


func test_front_units_take_front_row() -> void:
	# Six units: a front row of four, a back row of two.
	var formation: Formation = Formation.new(6, Vector3(0, 0, -50), Vector3.FORWARD, 2.0)
	assert_eq(formation.row_sizes, PackedInt32Array([4, 2]))
	# Units 0 and 3 trail behind (larger z, since forward is -Z).
	var positions: PackedVector3Array = [
		Vector3(0, 0, 10),
		Vector3(2, 0, -10),
		Vector3(-2, 0, -10),
		Vector3(1, 0, 10),
		Vector3(4, 0, -10),
		Vector3(-4, 0, -10),
	]
	var assignment: PackedInt32Array = formation.assign(positions)
	assert_gte(assignment[0], 4)
	assert_gte(assignment[3], 4)


func test_spacing_uses_widest_body() -> void:
	assert_almost_eq(Formation.spacing_for([0.8, 1.75, 0.6]), 1.75 * 2.0 + Formation.GAP, 1e-4)


func test_unwalkable_slots_are_replaced_by_walkable_ones() -> void:
	# Everything with x > 0 is a cliff.
	var walkable: Callable = func(point: Vector3) -> bool: return point.x <= 0.0
	var formation: Formation = Formation.new(12, Vector3.ZERO, Vector3.FORWARD, 2.0, walkable)
	assert_eq(formation.slots.size(), 12)
	var total: int = 0
	for size: int in formation.row_sizes:
		total += size
	assert_eq(total, 12)
	for i: int in formation.slots.size():
		var ok: bool = walkable.call(formation.slots[i])
		assert_true(ok, "slot %d walkable" % i)
		for j: int in range(i + 1, formation.slots.size()):
			assert_gt(formation.slots[i].distance_to(formation.slots[j]), 1.99)


func test_walkable_filter_keeps_ideal_block_when_all_walkable() -> void:
	var always: Callable = func(_point: Vector3) -> bool: return true
	var filtered: Formation = Formation.new(9, Vector3(3, 0, 3), Vector3.RIGHT, 2.5, always)
	var plain: Formation = Formation.new(9, Vector3(3, 0, 3), Vector3.RIGHT, 2.5)
	assert_eq(filtered.slots, plain.slots)
