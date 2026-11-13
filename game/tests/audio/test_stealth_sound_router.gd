extends GutTest
## StealthSoundRouter: alert stingers, the spotted sting, cloak changes, the
## stealth music mood (mapping and decay) and the reset on mission start.

const ENEMY: int = 1


class FakeUnit:
	extends Node3D
	var faction: int = 0
	var is_cloaked: bool = false
	var is_visible_to_player: bool = true


var _router: StealthSoundRouter
var _played: Array[StringName] = []
var _played_at: Array[Vector3] = []
var _ducks: Array[float] = []
var _music: Array[StringName] = []


func before_each() -> void:
	_played.clear()
	_played_at.clear()
	_ducks.clear()
	_music.clear()
	_router = StealthSoundRouter.new()
	_router.play_first = func(ids: Array[StringName], at: Vector3) -> StringName:
		for id: StringName in ids:
			if ResourceLoader.exists("res://data/sounds/stealth/%s.tres" % id):
				_played.append(id)
				_played_at.append(at)
				return id
		return &""
	_router.duck = func(hold: float) -> void: _ducks.append(hold)
	_router.set_music_state = func(state: StringName) -> void: _music.append(state)
	add_child_autofree(_router)
	_router.set_process(false)


func _unit(faction: int, cloaked: bool = false) -> FakeUnit:
	var unit: FakeUnit = FakeUnit.new()
	unit.faction = faction
	unit.is_cloaked = cloaked
	unit.add_to_group(&"units")
	add_child_autofree(unit)
	return unit


# --- Alert levels -------------------------------------------------------------


func test_rising_to_suspicious_queries() -> void:
	var played: Array[StringName] = _router.handle_alert_level_changed(
		ENEMY, &"suspicious", &"unaware", 1.0
	)
	assert_eq(played, [StealthCues.ALERT_SUSPICIOUS] as Array[StringName])
	assert_eq(_played, [&"stealth_alert_suspicious"] as Array[StringName])


func test_rising_to_alerted_sounds_the_alarm() -> void:
	_router.handle_alert_level_changed(ENEMY, &"suspicious", &"unaware", 1.0)
	_router.handle_alert_level_changed(ENEMY, &"alerted", &"suspicious", 2.0)
	assert_eq(_played[-1], &"stealth_alert_alarm")


func test_unaware_straight_to_alerted_is_the_alarm_only() -> void:
	_router.handle_alert_level_changed(ENEMY, &"alerted", &"unaware", 1.0)
	assert_eq(_played, [&"stealth_alert_alarm"] as Array[StringName])


func test_decay_to_suspicious_is_silent_and_unaware_is_the_all_clear() -> void:
	_router.handle_alert_level_changed(ENEMY, &"alerted", &"unaware", 1.0)
	_played.clear()
	_router.handle_alert_level_changed(ENEMY, &"suspicious", &"alerted", 20.0)
	assert_eq(_played.size(), 0, "alerted -> suspicious is left to the music")
	_router.handle_alert_level_changed(ENEMY, &"unaware", &"suspicious", 40.0)
	assert_eq(_played, [&"stealth_all_clear"] as Array[StringName])


func test_the_most_alarmed_faction_decides() -> void:
	_router.handle_alert_level_changed(ENEMY, &"alerted", &"unaware", 1.0)
	_played.clear()
	_router.handle_alert_level_changed(2, &"suspicious", &"unaware", 2.0)
	assert_eq(_played.size(), 0, "another faction's lower level changes nothing")
	_router.handle_alert_level_changed(ENEMY, &"unaware", &"alerted", 3.0)
	assert_eq(_played.size(), 0, "still suspicious overall: no all-clear yet")
	_router.handle_alert_level_changed(2, &"unaware", &"suspicious", 4.0)
	assert_eq(_played, [&"stealth_all_clear"] as Array[StringName])


func test_the_player_factions_own_level_is_ignored() -> void:
	_router.handle_alert_level_changed(0, &"alerted", &"unaware", 1.0)
	assert_eq(_played.size(), 0)
	assert_false(_router.mood.active)


func test_alert_events_rule() -> void:
	assert_eq(StealthCues.alert_events(&"suspicious", &"suspicious").size(), 0)
	assert_eq(StealthCues.alert_events(&"alerted", &"suspicious"), [&"stealth_alert_alarm"])
	assert_eq(StealthCues.alert_events(&"unaware", &"alerted"), [&"stealth_all_clear"])
	assert_eq(StealthCues.alert_events(&"bogus", &"unaware").size(), 0, "unknown = unaware")


# --- Spotted --------------------------------------------------------------------


func test_spotted_stings_once_per_target_and_ducks() -> void:
	var watcher: FakeUnit = _unit(ENEMY)
	var other_watcher: FakeUnit = _unit(ENEMY)
	var intruder: FakeUnit = _unit(0)
	assert_true(_router.handle_intruder_spotted(watcher, intruder, 1.0))
	assert_eq(_played, [&"stealth_spotted"] as Array[StringName])
	assert_eq(_played_at[0], Vector3.INF, "flat: it must read wherever the camera is")
	assert_eq(_ducks, [StealthSoundRouter.SPOTTED_DUCK] as Array[float])
	assert_false(_router.handle_intruder_spotted(other_watcher, intruder, 1.5), "same target")
	assert_true(
		_router.handle_intruder_spotted(watcher, intruder, 1.0 + StealthSoundRouter.SPOTTED_REPEAT)
	)
	var second: FakeUnit = _unit(0)
	assert_true(_router.handle_intruder_spotted(watcher, second, 1.6), "another target")


func test_spotting_someone_elses_unit_is_silent() -> void:
	var watcher: FakeUnit = _unit(0)
	var enemy: FakeUnit = _unit(ENEMY)
	assert_false(_router.handle_intruder_spotted(watcher, enemy, 1.0))
	assert_eq(_played.size(), 0)


func test_spotted_without_a_faction_still_stings() -> void:
	var watcher: Node3D = Node3D.new()
	var target: Node3D = Node3D.new()
	add_child_autofree(watcher)
	add_child_autofree(target)
	assert_true(_router.handle_intruder_spotted(watcher, target, 1.0))


func test_spotted_through_the_events_bus() -> void:
	var watcher: FakeUnit = _unit(ENEMY)
	var intruder: FakeUnit = _unit(0)
	Events.intruder_spotted.emit(watcher, intruder)
	assert_eq(_played, [&"stealth_spotted"] as Array[StringName])


# --- Reset ----------------------------------------------------------------------


func test_mission_start_resets_everything() -> void:
	var watcher: FakeUnit = _unit(ENEMY)
	var intruder: FakeUnit = _unit(0)
	_router.handle_alert_level_changed(ENEMY, &"alerted", &"unaware", 1.0)
	_router.handle_intruder_spotted(watcher, intruder, 1.0)
	_router.handle_mission_ended(false)
	Events.mission_started.emit()
	assert_eq(_music[-1], &"", "stealth music released")
	assert_false(_router.mood.active)
	assert_eq(_router.mood.overall(), StealthCues.UNAWARE)
	_played.clear()
	assert_true(_router.handle_intruder_spotted(watcher, intruder, 2.0), "spot memory cleared")
	_router.handle_alert_level_changed(ENEMY, &"suspicious", &"unaware", 3.0)
	assert_eq(_played[-1], &"stealth_alert_suspicious", "levels start from unaware again")
