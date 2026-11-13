extends GutTest
## Phase 8c, Verdance: the CanopySound router and its pure rules (CanopyCues).
## Units are plain Node3D doubles with a `faction` (and, for enemies, an
## `is_visible_to_player`); the canopy map is a double in group &"canopy". The
## router's outputs are captured through its callables; nothing plays.


class FakeUnit:
	extends Node3D
	var faction: int = 0
	var is_visible_to_player: bool = true


class FakeCanopyMap:
	extends Node
	var shaded: Rect2 = Rect2(-10, -10, 20, 20)

	func is_under_canopy(point: Vector3) -> bool:
		return shaded.has_point(Vector2(point.x, point.z))


var _sound: CanopySound
var _played: Array[StringName] = []
var _played_at: Array[Vector3] = []
var _shades: Array[float] = []


func before_each() -> void:
	_played.clear()
	_played_at.clear()
	_shades.clear()
	_sound = CanopySound.new()
	_sound.play_at = func(id: StringName, at: Vector3) -> bool:
		_played.append(id)
		_played_at.append(at)
		return true
	_sound.set_shade = func(amount: float) -> void: _shades.append(amount)
	add_child_autofree(_sound)
	_sound.set_process(false)


func _unit(at: Vector3, faction: int = 0) -> FakeUnit:
	var unit: FakeUnit = FakeUnit.new()
	unit.faction = faction
	add_child_autofree(unit)
	unit.global_position = at
	return unit


# --- Rustles ---------------------------------------------------------------------


func test_an_own_unit_going_under_a_crown_rustles_at_the_unit() -> void:
	var unit: FakeUnit = _unit(Vector3(5, 0, 3))
	assert_true(_sound.handle_cover_changed(unit, true))
	assert_eq(_played, [CanopyCues.RUSTLE_IN] as Array[StringName])
	assert_eq(_played_at[0], Vector3(5, 0, 3), "heard where the unit is")
	_sound.advance(1.0)
	assert_true(_sound.handle_cover_changed(unit, false))
	assert_eq(_played[1], CanopyCues.RUSTLE_OUT, "coming out is the lighter rustle")


func test_a_group_filing_under_a_crown_is_one_gesture() -> void:
	var units: Array[FakeUnit] = []
	for i: int in 20:
		units.append(_unit(Vector3(i * 0.5, 0, 0)))
	for unit: FakeUnit in units:  # twenty reports over two seconds
		_sound.handle_cover_changed(unit, true)
		_sound.advance(0.1)
	assert_eq(_played.size(), 1, "twenty units, one rustle")
	_sound.advance(1.0)
	for unit: FakeUnit in units:
		_sound.handle_cover_changed(unit, false)
		_sound.advance(0.05)
	assert_eq(_played, [CanopyCues.RUSTLE_IN, CanopyCues.RUSTLE_OUT] as Array[StringName])


func test_a_long_stream_of_units_rustles_again_after_the_gesture_ends() -> void:
	for i: int in 40:  # one report every 0.2 s for eight seconds
		_sound.handle_cover_changed(_unit(Vector3(i * 0.2, 0, 0)), true)
		_sound.advance(0.2)
	var rustles: int = _played.size()
	assert_gt(rustles, 1, "a column passing for eight seconds is heard more than once")
	assert_lte(rustles, 4, "but only once per %.1f s gesture" % CanopyCues.GESTURE_MAX)


func test_in_and_out_never_crowd_each_other() -> void:
	var a: FakeUnit = _unit(Vector3(1, 0, 0))
	var b: FakeUnit = _unit(Vector3(2, 0, 0))
	_sound.handle_cover_changed(a, true)
	_sound.advance(0.05)
	_sound.handle_cover_changed(b, false)
	assert_eq(_played.size(), 1, "an out right on top of an in is carried by it")


func test_other_factions_and_far_units_are_never_heard() -> void:
	var enemy: FakeUnit = _unit(Vector3(3, 0, 0), 1)
	assert_false(_sound.handle_cover_changed(enemy, true), "no rustle gives an ambush away")
	var far: FakeUnit = _unit(Vector3(CanopyCues.VIEW_RADIUS + 10.0, 0, 0))
	assert_false(_sound.handle_cover_changed(far, true), "out of view")
	assert_true(_played.is_empty())
	assert_eq(_sound.covered_count(), 2, "both are still known to be covered")
	assert_false(_sound.handle_cover_changed(null, true), "a null unit is ignored")


func test_mission_start_resets_the_gesture_and_the_cover() -> void:
	var unit: FakeUnit = _unit(Vector3.ZERO)
	_sound.handle_cover_changed(unit, true)
	_sound.handle_mission_started()
	assert_eq(_sound.covered_count(), 0)
	assert_true(
		_sound.handle_cover_changed(_unit(Vector3(1, 0, 0)), true), "a fresh gesture at once"
	)


# --- Shade -----------------------------------------------------------------------


func test_shade_follows_a_canopy_map_when_there_is_one() -> void:
	var map: FakeCanopyMap = FakeCanopyMap.new()
	map.add_to_group(CanopySound.CANOPY_GROUP)
	add_child_autofree(map)
	_sound.focus = Vector3(2, 0, 2)
	assert_true(_sound.is_focus_shaded())
	for i: int in 20:
		_sound.advance(0.1)
	assert_almost_eq(_sound.shade(), 1.0, 0.001, "under the crown")
	assert_gt(_shades.size(), 2, "it glides, a step at a time")
	_sound.focus = Vector3(50, 0, 50)
	for i: int in 20:
		_sound.advance(0.1)
	assert_almost_eq(_sound.shade(), 0.0, 0.001, "out in the open")


func test_without_a_map_a_covered_unit_near_the_focus_shades_it() -> void:
	var own: FakeUnit = _unit(Vector3(3, 0, 0))
	_sound.handle_cover_changed(own, true)
	assert_true(_sound.is_focus_shaded(), "the player's unit under a crown by the camera")
	_sound.handle_cover_changed(own, false)
	assert_false(_sound.is_focus_shaded())
	var hidden: FakeUnit = _unit(Vector3(2, 0, 0), 1)
	hidden.is_visible_to_player = false
	_sound.handle_cover_changed(hidden, true)
	assert_false(_sound.is_focus_shaded(), "a hidden enemy's crown is not given away")
	hidden.is_visible_to_player = true
	assert_true(_sound.is_focus_shaded(), "a seen one's is")


func test_shade_closes_the_ambience_high_band_a_little() -> void:
	assert_almost_eq(CanopyCues.shade_cutoff_hz(0.0), CanopyCues.OPEN_CUTOFF_HZ, 0.1)
	assert_almost_eq(CanopyCues.shade_cutoff_hz(1.0), CanopyCues.SHADE_CUTOFF_HZ, 0.1)
	var half: float = CanopyCues.shade_cutoff_hz(0.5)
	assert_between(half, CanopyCues.SHADE_CUTOFF_HZ, CanopyCues.OPEN_CUTOFF_HZ)
	assert_gt(CanopyCues.SHADE_CUTOFF_HZ, StormCues.muffle_cutoff_hz(1.0), "far less than a storm")


func test_through_the_real_service_shade_filters_only_the_ambience() -> void:
	var canopy: CanopySound = Audio.get_node(^"Canopy") as CanopySound
	assert_not_null(canopy, "the AudioService has a Canopy child")
	var map: FakeCanopyMap = FakeCanopyMap.new()
	map.add_to_group(CanopySound.CANOPY_GROUP)
	add_child_autofree(map)
	Audio.set_listener_focus(Vector3.ZERO, 0.5)
	for i: int in 30:
		canopy.advance(0.1)
	var ambience: int = AudioServer.get_bus_index(&"Ambience")
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	var effect: int = _muffle_effect(ambience)
	if effect >= 0:
		assert_true(AudioServer.is_bus_effect_enabled(ambience, effect), "the leaves overhead")
		var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(ambience, effect)
		assert_almost_eq(filter.cutoff_hz, CanopyCues.SHADE_CUTOFF_HZ, 1.0)
	var sfx_effect: int = _muffle_effect(sfx)
	if sfx_effect >= 0 and Audio.muffle() <= 0.001:
		assert_false(AudioServer.is_bus_effect_enabled(sfx, sfx_effect), "the battle stays clear")
	map.remove_from_group(CanopySound.CANOPY_GROUP)
	Events.mission_started.emit()
	if effect >= 0 and Audio.muffle() <= 0.001:
		assert_false(AudioServer.is_bus_effect_enabled(ambience, effect), "open again")


func _muffle_effect(bus_index: int) -> int:
	if bus_index < 0:
		return -1
	for i: int in AudioServer.get_bus_effect_count(bus_index):
		if AudioServer.get_bus_effect(bus_index, i).resource_name == AudioMix.MUFFLE_EFFECT:
			return i
	return -1
