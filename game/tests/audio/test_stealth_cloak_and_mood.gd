extends GutTest
## StealthSoundRouter: cloak changes and the stealth music mood (level ->
## state mapping, decay, freezing at mission end).

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


# --- Cloaks -----------------------------------------------------------------------


func test_first_reading_is_the_baseline() -> void:
	_unit(0, true)
	assert_eq(_router.scan_cloaks().size(), 0, "spawned cloaked: silent")


func test_cloaking_and_uncloaking_play_at_the_unit() -> void:
	var wisp: FakeUnit = _unit(0)
	wisp.position = Vector3(5, 0, 7)
	_router.scan_cloaks()
	wisp.is_cloaked = true
	assert_eq(_router.scan_cloaks(), [StealthCues.CLOAK_ENGAGE] as Array[StringName])
	assert_eq(_played_at[-1], Vector3(5, 0, 7))
	assert_eq(_router.scan_cloaks().size(), 0, "no change, no sound")
	wisp.is_cloaked = false
	assert_eq(_router.scan_cloaks(), [StealthCues.CLOAK_DISENGAGE] as Array[StringName])


func test_an_unseen_enemy_cloaks_silently() -> void:
	var enemy: FakeUnit = _unit(ENEMY)
	enemy.is_visible_to_player = false
	_router.scan_cloaks()
	enemy.is_cloaked = true
	assert_eq(_router.scan_cloaks().size(), 0)


func test_a_visible_enemy_vanishing_is_heard() -> void:
	var enemy: FakeUnit = _unit(ENEMY)
	_router.scan_cloaks()
	enemy.is_cloaked = true
	enemy.is_visible_to_player = false
	assert_eq(_router.scan_cloaks(), [StealthCues.CLOAK_ENGAGE] as Array[StringName])


func test_units_without_a_cloak_are_ignored() -> void:
	var plain: Node3D = Node3D.new()
	plain.add_to_group(&"units")
	add_child_autofree(plain)
	assert_eq(_router.scan_cloaks().size(), 0)


# --- Music ----------------------------------------------------------------------


func test_no_stealth_music_until_the_mission_shows_stealth() -> void:
	assert_eq(_router.update_mood(1.0), &"")
	assert_eq(_music.size(), 0, "nothing reported while inactive")


func test_suspicion_or_a_spotting_alone_keeps_the_combat_score() -> void:
	Events.suspicion_raised.emit(_unit(ENEMY), _unit(0))
	_router.handle_intruder_spotted(_unit(ENEMY), _unit(0), 1.0)
	assert_eq(_router.update_mood(1.0), &"")


func test_an_initial_unaware_report_starts_the_sparse_score_silently() -> void:
	_router.handle_alert_level_changed(ENEMY, &"unaware", &"unaware", 1.0)
	assert_eq(_played.size(), 0)
	assert_eq(_music, [StealthCues.MUSIC_UNAWARE] as Array[StringName])


func test_a_watcher_in_the_group_activates_it() -> void:
	var watcher: FakeUnit = _unit(ENEMY)
	watcher.add_to_group(&"watchers")
	assert_eq(_router.update_mood(1.0), StealthCues.MUSIC_UNAWARE)


func test_alert_levels_map_to_music_states() -> void:
	_router.handle_alert_level_changed(ENEMY, &"suspicious", &"unaware", 1.0)
	assert_eq(_router.music_state(), StealthCues.MUSIC_SUSPICIOUS)
	_router.handle_alert_level_changed(ENEMY, &"alerted", &"suspicious", 2.0)
	assert_eq(_router.music_state(), StealthCues.MUSIC_ALERTED)


func test_music_decays_after_its_hold() -> void:
	var hold_alerted: float = StealthMood.HOLD_DOWN[StealthCues.ALERTED]
	var hold_suspicious: float = StealthMood.HOLD_DOWN[StealthCues.SUSPICIOUS]
	_router.handle_alert_level_changed(ENEMY, &"alerted", &"unaware", 0.0)
	_router.handle_alert_level_changed(ENEMY, &"unaware", &"alerted", 10.0)
	assert_eq(_router.update_mood(10.0 + hold_alerted - 0.1), StealthCues.MUSIC_ALERTED, "held")
	assert_eq(_router.update_mood(10.0 + hold_alerted), StealthCues.MUSIC_UNAWARE, "decayed")
	_router.handle_alert_level_changed(ENEMY, &"suspicious", &"unaware", 30.0)
	_router.handle_alert_level_changed(ENEMY, &"unaware", &"suspicious", 31.0)
	assert_eq(_router.update_mood(31.0 + hold_suspicious - 0.1), StealthCues.MUSIC_SUSPICIOUS)
	assert_eq(_router.update_mood(31.0 + hold_suspicious), StealthCues.MUSIC_UNAWARE)


func test_a_flicker_inside_the_hold_keeps_the_drive() -> void:
	var mood: StealthMood = StealthMood.new()
	mood.note_level(ENEMY, &"alerted")
	assert_eq(mood.update(0.0), StealthCues.MUSIC_ALERTED)
	mood.note_level(ENEMY, &"suspicious")
	assert_eq(mood.update(1.0), StealthCues.MUSIC_ALERTED)
	mood.note_level(ENEMY, &"alerted")
	assert_eq(mood.update(2.0), StealthCues.MUSIC_ALERTED)
	mood.note_level(ENEMY, &"suspicious")
	assert_eq(mood.update(3.0), StealthCues.MUSIC_ALERTED, "the hold restarted")
	assert_eq(mood.update(3.0 + StealthMood.HOLD_DOWN[StealthCues.ALERTED]), &"stealth_suspicious")


func test_mission_end_freezes_the_music_request() -> void:
	_router.handle_alert_level_changed(ENEMY, &"alerted", &"unaware", 1.0)
	_router.handle_mission_ended(true)
	_music.clear()
	_router.handle_alert_level_changed(ENEMY, &"unaware", &"alerted", 2.0)
	_router.update_mood(100.0)
	assert_eq(_music.size(), 0)
