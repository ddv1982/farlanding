extends GutTest
## CombatMixer: per-frame arbitration of combat sounds (nearest and heaviest
## first, category budgets per rolling window, ducking under explosions).

var _mixer: CombatMixer
var _played: Array[Array] = []
var _refuse: Array[StringName] = []


func before_each() -> void:
	_mixer = CombatMixer.new()
	_played.clear()
	_refuse.clear()


func _play(event_id: StringName, at: Vector3, offset_db: float) -> bool:
	if event_id in _refuse:
		return false
	_played.append([event_id, at, offset_db])
	return true


func _flush(now: float) -> Array[StringName]:
	return _mixer.flush(now, Vector3.ZERO, _play)


func test_thirty_units_firing_stay_within_the_fire_budget() -> void:
	var limit: int = CombatMixer.LIMITS[&"fire"]
	var total: int = 0
	# 30 units, each firing about twice a second, for 3 s at 60 frames/s.
	for frame: int in 180:
		var now: float = frame / 60.0
		for unit: int in 30:
			if (frame + unit * 7) % 30 == 0:
				_mixer.offer(&"weapon_repeater_fire", Vector3(unit, 0, 0), 40, 70.0)
		total += _flush(now).size()
		assert_lte(_mixer.recent_starts(&"fire", now), limit)
	assert_gt(total, 0)
	assert_lte(total, int(limit * 3.0 / CombatMixer.WINDOW) + limit, "bounded by the window budget")
	assert_lt(total, 180, "far fewer starts than shots (180 shots)")


func test_nearest_wins_among_equals() -> void:
	for x: float in [30.0, 5.0, 60.0, 12.0]:
		_mixer.offer(&"weapon_repeater_fire", Vector3(x, 0, 0), 40, 70.0)
	_flush(0.0)
	var first: Vector3 = _played[0][1]
	assert_eq(first.x, 5.0)
	var second: Vector3 = _played[1][1]
	assert_eq(second.x, 12.0)


func test_heaviest_beats_a_nearer_light_weapon() -> void:
	_mixer.offer(&"weapon_repeater_fire", Vector3(2, 0, 0), 40, 70.0)
	_mixer.offer(&"weapon_cannon_fire", Vector3(14, 0, 0), 58, 90.0)
	assert_eq(_flush(0.0)[0], &"weapon_cannon_fire")


func test_over_budget_keeps_the_best() -> void:
	var limit: int = CombatMixer.LIMITS[&"fire"]
	for i: int in 20:
		_mixer.offer(&"weapon_skitter_gun_fire", Vector3(40 + i, 0, 0), 38, 70.0)
	_mixer.offer(&"weapon_siege_fire", Vector3(60, 0, 0), 58, 90.0)
	var started: Array[StringName] = _flush(0.0)
	assert_eq(started.size(), limit)
	assert_true(started.has(&"weapon_siege_fire"), "the heavy gun survives")
	var farthest_kept: float = 0.0
	for entry: Array in _played:
		var at: Vector3 = entry[1]
		var id: StringName = entry[0]
		if id == &"weapon_skitter_gun_fire":
			farthest_kept = maxf(farthest_kept, at.x)
	assert_lt(farthest_kept, 40.0 + limit, "the nearest drones are the ones heard")


func test_out_of_range_offers_do_not_take_slots() -> void:
	for i: int in 30:
		_mixer.offer(&"weapon_repeater_fire", Vector3(500 + i, 0, 0), 40, 70.0)
	_mixer.offer(&"weapon_repeater_fire", Vector3(10, 0, 0), 40, 70.0)
	var started: Array[StringName] = _flush(0.0)
	assert_eq(started.size(), 1)


func test_refused_plays_do_not_use_the_budget() -> void:
	_refuse.append(&"weapon_cannon_fire")
	for i: int in 10:
		_mixer.offer(&"weapon_cannon_fire", Vector3(i, 0, 0), 58, 90.0)
	_mixer.offer(&"weapon_repeater_fire", Vector3(20, 0, 0), 40, 70.0)
	assert_eq(_flush(0.0), [&"weapon_repeater_fire"] as Array[StringName])
	assert_eq(_mixer.recent_starts(&"fire", 0.0), 1)


func test_budget_refills_after_the_window() -> void:
	var limit: int = CombatMixer.LIMITS[&"impact"]
	for i: int in 20:
		_mixer.offer(&"impact_spark", Vector3(i, 0, 0), 34, 55.0)
	assert_eq(_flush(0.0).size(), limit)
	_mixer.offer(&"impact_spark", Vector3(1, 0, 0), 34, 55.0)
	assert_eq(_flush(0.2).size(), 0, "still inside the window")
	_mixer.offer(&"impact_spark", Vector3(1, 0, 0), 34, 55.0)
	assert_eq(_flush(CombatMixer.WINDOW + 0.01).size(), 1)


func test_categories_have_separate_budgets() -> void:
	for i: int in 20:
		_mixer.offer(&"weapon_repeater_fire", Vector3(i, 0, 0), 40, 70.0)
		_mixer.offer(&"impact_spark", Vector3(i, 0, 0), 34, 55.0)
	_mixer.offer(&"explosion_medium", Vector3(30, 0, 0), 66, 120.0)
	_flush(0.0)
	assert_eq(_mixer.recent_starts(&"fire", 0.0), CombatMixer.LIMITS[&"fire"])
	assert_eq(_mixer.recent_starts(&"impact", 0.0), CombatMixer.LIMITS[&"impact"])
	assert_eq(_mixer.recent_starts(&"blast", 0.0), 1)


func test_explosions_duck_light_fire_but_not_heavy_fire() -> void:
	_mixer.offer(&"weapon_repeater_fire", Vector3(1, 0, 0), 40, 70.0)
	_mixer.offer(&"weapon_cannon_fire", Vector3(2, 0, 0), 58, 90.0)
	_mixer.offer(&"explosion_large", Vector3(50, 0, 0), 70, 150.0)
	assert_eq(_flush(0.0)[0], &"explosion_large", "blasts go first")
	var offsets: Dictionary[StringName, float] = {}
	for entry: Array in _played:
		var id: StringName = entry[0]
		var offset: float = entry[2]
		offsets[id] = offset
	assert_eq(offsets[&"weapon_repeater_fire"], CombatMixer.DUCK_DB)
	assert_eq(offsets[&"weapon_cannon_fire"], 0.0)
	assert_true(_mixer.is_ducking(0.1))
	assert_false(_mixer.is_ducking(CombatMixer.DUCK_SECONDS + 0.01))


func test_category_by_name() -> void:
	assert_eq(CombatMixer.category_of(&"weapon_lance_fire"), &"fire")
	assert_eq(CombatMixer.category_of(&"impact_ground"), &"impact")
	assert_eq(CombatMixer.category_of(&"explosion_small"), &"blast")
	assert_eq(CombatMixer.category_of(&"death_building"), &"blast")
