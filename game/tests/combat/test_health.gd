extends GutTest
## Health: damage, death (once), events and saving.

var _health: Health
var _owner: Node3D


func before_each() -> void:
	_owner = Node3D.new()
	add_child_autofree(_owner)
	_health = Health.new()
	_owner.add_child(_health)
	_health.setup(100.0, &"light", _owner)


func test_damage_lowers_health_and_reports_the_fraction() -> void:
	watch_signals(_health)
	watch_signals(Events)
	assert_almost_eq(_health.take(30.0), 30.0, 1e-6)
	assert_almost_eq(_health.fraction(), 0.7, 1e-6)
	assert_signal_emitted_with_parameters(_health, "changed", [0.7])
	assert_signal_emitted(Events, "entity_damaged")
	assert_false(_health.is_dead())


func test_dies_once_at_zero_and_ignores_further_damage() -> void:
	watch_signals(_health)
	assert_almost_eq(_health.take(250.0), 100.0, 1e-6, "only what was left")
	assert_true(_health.is_dead())
	assert_signal_emit_count(_health, "died", 1)
	assert_eq(_health.take(10.0), 0.0)
	assert_signal_emit_count(_health, "died", 1, "not twice")


func test_heal_is_capped_and_does_not_revive() -> void:
	_health.take(50.0)
	_health.heal(80.0)
	assert_almost_eq(_health.current, 100.0, 1e-6)
	_health.take(200.0)
	_health.heal(50.0)
	assert_true(_health.is_dead())


func test_round_trip() -> void:
	_health.take(42.0)
	var copy: Health = Health.new()
	add_child_autofree(copy)
	copy.from_dict(_health.to_dict())
	assert_almost_eq(copy.current, 58.0, 1e-6)
	assert_almost_eq(copy.max_health, 100.0, 1e-6)
