extends GutTest
## VoiceBudget: free voices, instance caps, cooldowns, priority stealing, expiry.


func test_takes_free_voices_first() -> void:
	var budget: VoiceBudget = VoiceBudget.new(3)
	assert_eq(budget.request(&"a", 50, 4, 0.0, 1.0, 0.0), 0)
	assert_eq(budget.request(&"b", 50, 4, 0.0, 1.0, 0.0), 1)
	assert_eq(budget.active_count(), 2)
	assert_eq(budget.last_stolen, -1)


func test_instance_cap_rejects_extra_copies() -> void:
	var budget: VoiceBudget = VoiceBudget.new(8)
	assert_ne(budget.request(&"shot", 50, 2, 0.0, 1.0, 0.0), VoiceBudget.REJECTED)
	assert_ne(budget.request(&"shot", 50, 2, 0.0, 1.0, 0.0), VoiceBudget.REJECTED)
	assert_eq(budget.request(&"shot", 50, 2, 0.0, 1.0, 0.0), VoiceBudget.REJECTED)
	assert_eq(budget.active_count(&"shot"), 2)


func test_cooldown_rejects_until_elapsed() -> void:
	var budget: VoiceBudget = VoiceBudget.new(8)
	assert_ne(budget.request(&"ack", 50, 4, 0.25, 0.1, 1.0), VoiceBudget.REJECTED)
	assert_eq(budget.request(&"ack", 50, 4, 0.25, 0.1, 1.2), VoiceBudget.REJECTED)
	assert_ne(budget.request(&"ack", 50, 4, 0.25, 0.1, 1.26), VoiceBudget.REJECTED)


func test_steals_lowest_priority_when_full() -> void:
	var budget: VoiceBudget = VoiceBudget.new(2)
	budget.request(&"low", 10, 4, 0.0, 5.0, 0.0)
	budget.request(&"mid", 50, 4, 0.0, 5.0, 0.1)
	var voice: int = budget.request(&"high", 90, 4, 0.0, 5.0, 0.2)
	assert_eq(voice, 0, "the priority-10 voice is replaced")
	assert_eq(budget.last_stolen, 0)
	assert_eq(budget.event_of(0), &"high")


func test_never_steals_a_higher_priority_voice() -> void:
	var budget: VoiceBudget = VoiceBudget.new(1)
	budget.request(&"advisor", 100, 1, 0.0, 5.0, 0.0)
	assert_eq(budget.request(&"click", 90, 2, 0.0, 0.1, 0.1), VoiceBudget.REJECTED)
	assert_eq(budget.event_of(0), &"advisor")


func test_equal_priority_steals_the_oldest() -> void:
	var budget: VoiceBudget = VoiceBudget.new(2)
	budget.request(&"a", 50, 4, 0.0, 5.0, 0.0)
	budget.request(&"b", 50, 4, 0.0, 5.0, 0.5)
	assert_eq(budget.request(&"c", 50, 4, 0.0, 5.0, 1.0), 0)


func test_voices_expire_after_their_duration() -> void:
	var budget: VoiceBudget = VoiceBudget.new(1)
	budget.request(&"a", 100, 1, 0.0, 0.5, 0.0)
	assert_eq(budget.request(&"b", 10, 1, 0.0, 0.5, 0.4), VoiceBudget.REJECTED)
	assert_eq(budget.request(&"b", 10, 1, 0.0, 0.5, 0.6), 0, "expired voice is free again")


func test_release_frees_a_voice() -> void:
	var budget: VoiceBudget = VoiceBudget.new(1)
	var voice: int = budget.request(&"a", 50, 1, 0.0, 10.0, 0.0)
	budget.release(voice)
	assert_false(budget.is_active(voice))
	assert_eq(budget.request(&"a", 50, 1, 0.0, 10.0, 0.1), 0)


func test_forty_units_acknowledging_at_once_stay_clean() -> void:
	# Forty replies inside 50 ms: cap 1 and a 0.25 s cooldown leave one voice.
	var budget: VoiceBudget = VoiceBudget.new(16)
	var started: int = 0
	for i: int in 40:
		if budget.request(&"unit_ranger_move", 70, 1, 0.25, 0.9, i * 0.00125) >= 0:
			started += 1
	assert_eq(started, 1)
	assert_eq(budget.active_count(), 1)


func test_a_flood_of_one_event_cannot_starve_others() -> void:
	var budget: VoiceBudget = VoiceBudget.new(8)
	for i: int in 100:
		budget.request(&"shot", 40, 4, 0.0, 1.0, i * 0.001)
	assert_eq(budget.active_count(&"shot"), 4)
	assert_ne(budget.request(&"ui_click", 90, 2, 0.0, 0.1, 0.2), VoiceBudget.REJECTED)
