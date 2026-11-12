extends GutTest
## AdvisorQueue: per-kind throttle, no stacking, priority, staleness.

var _queue: AdvisorQueue


func before_each() -> void:
	_queue = AdvisorQueue.new()


func test_same_kind_is_throttled() -> void:
	assert_true(_queue.push(&"insufficient_resources", 0.0))
	assert_eq(_queue.pop_ready(0.0), &"insufficient_resources")
	_queue.started(0.0, 0.8)
	for t: float in [1.0, 5.0, 14.9]:
		assert_false(_queue.push(&"insufficient_resources", t), "throttled at %.1f s" % t)
	assert_true(_queue.push(&"insufficient_resources", 15.1))


func test_insufficient_resources_is_throttled_longest() -> void:
	assert_gt(
		AdvisorQueue.throttle_of(&"insufficient_resources"), AdvisorQueue.throttle_of(&"unit_ready")
	)
	assert_gt(AdvisorQueue.throttle_of(&"insufficient_resources"), 5.0)


func test_different_kinds_do_not_throttle_each_other() -> void:
	assert_true(_queue.push(&"unit_ready", 0.0))
	assert_true(_queue.push(&"construction_complete", 0.0))
	assert_eq(_queue.queued().size(), 2)


func test_phrases_never_stack() -> void:
	_queue.push(&"unit_ready", 0.0)
	assert_eq(_queue.pop_ready(0.0), &"unit_ready")
	_queue.started(0.0, 1.0)
	assert_true(_queue.push(&"construction_complete", 0.2))
	assert_eq(_queue.pop_ready(0.2), &"", "waits while a phrase sounds")
	assert_eq(_queue.pop_ready(1.0 + AdvisorQueue.GAP - 0.01), &"", "and for the gap")
	assert_eq(_queue.pop_ready(1.0 + AdvisorQueue.GAP + 0.01), &"construction_complete")


func test_most_important_waiting_alert_goes_first() -> void:
	_queue.started(0.0, 2.0)
	_queue.push(&"building_placed", 0.1)
	_queue.push(&"insufficient_resources", 0.2)
	_queue.push(&"low_power", 0.3)
	assert_eq(_queue.pop_ready(3.0), &"low_power")
	_queue.started(3.0, 0.5)
	assert_eq(_queue.pop_ready(4.0), &"insufficient_resources")


func test_stale_alerts_are_dropped() -> void:
	_queue.started(0.0, 10.0)
	_queue.push(&"unit_ready", 0.5)
	assert_eq(_queue.pop_ready(0.5 + AdvisorQueue.MAX_WAIT + 6.0), &"")
	assert_eq(_queue.queued().size(), 0)


func test_full_queue_keeps_the_important_ones() -> void:
	_queue.started(0.0, 3.0)
	_queue.push(&"building_placed", 0.0)
	_queue.push(&"unit_ready", 0.0)
	_queue.push(&"construction_complete", 0.0)
	assert_true(_queue.push(&"low_power", 0.1), "outranks building_placed")
	assert_false(_queue.queued().has(&"building_placed"))
	assert_false(_queue.push(&"insufficient_resources", 0.2), "below everything queued")


func test_power_flapping_unheard_cancels_out() -> void:
	_queue.started(0.0, 2.0)
	assert_true(_queue.push(&"low_power", 0.5))
	assert_false(_queue.push(&"power_restored", 1.0))
	assert_eq(_queue.queued().size(), 0)
	assert_true(_queue.push(&"low_power", 1.5), "a new warning is not throttled by the moot one")


func test_power_restored_follows_a_heard_warning() -> void:
	_queue.push(&"low_power", 0.0)
	assert_eq(_queue.pop_ready(0.0), &"low_power")
	_queue.started(0.0, 1.5)
	assert_true(_queue.push(&"power_restored", 1.0))
	assert_eq(_queue.pop_ready(2.0), &"power_restored")
