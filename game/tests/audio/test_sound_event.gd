extends GutTest
## SoundEvent variation picking.


func test_avoid_repeat_never_picks_the_last_index() -> void:
	for last: int in 3:
		for step: int in 100:
			var roll: float = step / 100.0
			assert_ne(SoundEvent.pick_index(3, last, roll, true), last)


func test_avoid_repeat_covers_all_other_indices() -> void:
	var seen: Dictionary[int, bool] = {}
	for step: int in 100:
		seen[SoundEvent.pick_index(4, 1, step / 100.0, true)] = true
	assert_eq(seen.keys().size(), 3)
	assert_false(seen.has(1))


func test_single_stream_and_empty() -> void:
	assert_eq(SoundEvent.pick_index(1, 0, 0.7, true), 0)
	assert_eq(SoundEvent.pick_index(0, -1, 0.3, true), -1)


func test_without_avoid_repeat_any_index_is_possible() -> void:
	assert_eq(SoundEvent.pick_index(3, 2, 0.99, false), 2)
