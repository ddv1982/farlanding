extends GutTest
## CombatSoundRouter and CombatCues: which combat sound plays where, fog of war,
## deaths per weight class, and the end-of-mission music.


class FakeEntity:
	extends Node3D
	var def: EntityDef
	var faction: int = 0
	var is_visible_to_player: bool = true


class FakeWeapon:
	extends Resource
	var id: StringName = &"test_gun"
	var sound_set: StringName = &"repeater"
	var projectile_style: StringName = &"bolt"
	var impact_size: float = 0.0


class FakeFog:
	extends Node
	var hidden_beyond_x: float = 100.0

	func is_point_visible_to_player(position: Vector3) -> bool:
		return position.x < hidden_beyond_x


var _router: CombatSoundRouter
var _played: Array[StringName] = []
var _positions: Array[Vector3] = []
var _states: Array[StringName] = []
var _ended: Array[bool] = []


func before_each() -> void:
	_played.clear()
	_positions.clear()
	_states.clear()
	_ended.clear()
	_router = CombatSoundRouter.new()
	_router.focus = Vector3.ZERO
	_router.resolve_event = _event
	_router.play_at = func(id: StringName, at: Vector3, _db: float) -> bool:
		_played.append(id)
		_positions.append(at)
		return true
	_router.set_music_state = func(state: StringName) -> void: _states.append(state)
	_router.end_music = func(won: bool) -> void: _ended.append(won)
	add_child_autofree(_router)


## Every combat event "exists" except the ones named missing.
func _event(event_id: StringName) -> SoundEvent:
	if String(event_id).begins_with("missing"):
		return null
	var event: SoundEvent = SoundEvent.new()
	event.id = event_id
	event.priority = 50
	event.max_distance = 100.0
	return event


func _entity(
	sound_set: StringName,
	faction: int = 0,
	at: Vector3 = Vector3(5, 0, 5),
	armour: StringName = &""
) -> FakeEntity:
	var entity: FakeEntity = FakeEntity.new()
	entity.def = UnitDef.new()
	entity.def.sound_set = sound_set
	if armour != &"":
		entity.def.set(&"armour_type", armour)
	entity.faction = faction
	add_child_autofree(entity)
	entity.global_position = at
	return entity


func test_weapon_fire_plays_its_sound_set_at_the_muzzle() -> void:
	var shooter: FakeEntity = _entity(&"ranger")
	_router.handle_weapon_fired(shooter, FakeWeapon.new(), Vector3(3, 1, 2), 0.0)
	_router.flush(0.0)
	assert_eq(_played, [&"weapon_repeater_fire"] as Array[StringName])
	assert_eq(_positions[0], Vector3(3, 1, 2))


func test_weapon_data_names_map_to_their_sound_family() -> void:
	var weapon: FakeWeapon = FakeWeapon.new()
	weapon.sound_set = &"mauler_twin_cannon"
	assert_eq(
		CombatCues.fire_events(weapon),
		[&"weapon_mauler_twin_cannon_fire", &"weapon_siege_fire"] as Array[StringName]
	)
	for data_name: StringName in CombatCues.FIRE_ALIASES:
		weapon.sound_set = data_name
		var events: Array[StringName] = CombatCues.fire_events(weapon)
		assert_true(
			ResourceLoader.exists("res://data/sounds/weapon/%s.tres" % events[-1]),
			String(data_name)
		)


func test_hidden_shooters_are_silent() -> void:
	var shooter: FakeEntity = _entity(&"skitter", 1)
	shooter.is_visible_to_player = false
	var weapon: FakeWeapon = FakeWeapon.new()
	weapon.sound_set = &"skitter_gun"
	_router.handle_weapon_fired(shooter, weapon, Vector3(3, 1, 2), 0.0)
	_router.flush(0.0)
	assert_eq(_played.size(), 0)


func test_shooters_without_the_visibility_property_are_heard() -> void:
	var shooter: Node3D = Node3D.new()
	add_child_autofree(shooter)
	_router.handle_weapon_fired(shooter, FakeWeapon.new(), Vector3(1, 0, 1), 0.0)
	_router.flush(0.0)
	assert_eq(_played.size(), 1)


func test_weapons_without_a_sound_set_are_silent() -> void:
	var weapon: FakeWeapon = FakeWeapon.new()
	weapon.sound_set = &""
	_router.handle_weapon_fired(_entity(&"ranger"), weapon, Vector3.ONE, 0.0)
	_router.handle_weapon_fired(_entity(&"ranger"), Resource.new(), Vector3.ONE, 0.0)
	_router.flush(0.0)
	assert_eq(_played.size(), 0)


func test_impacts_by_surface_and_size() -> void:
	var weapon: FakeWeapon = FakeWeapon.new()
	assert_eq(CombatCues.impact_events(weapon, null)[0], &"impact_ground")
	assert_eq(CombatCues.impact_events(weapon, _entity(&"ranger"))[0], &"impact_spark")
	var heavy: FakeEntity = _entity(&"bulwark", 0, Vector3.ZERO, &"heavy")
	assert_eq(CombatCues.impact_events(weapon, heavy)[0], &"impact_armour")
	var light: FakeEntity = _entity(&"bulwark", 0, Vector3.ZERO, &"light")
	assert_eq(CombatCues.impact_events(weapon, light)[0], &"impact_spark", "armour data wins")
	var building: FakeEntity = _entity(&"refinery")
	building.add_to_group(&"buildings")
	assert_eq(CombatCues.impact_events(weapon, building)[0], &"impact_armour")
	weapon.projectile_style = &"lance"
	assert_eq(CombatCues.impact_events(weapon, heavy)[0], &"impact_spark")
	weapon.projectile_style = &"shell"
	weapon.impact_size = 0.6
	assert_eq(CombatCues.impact_events(weapon, null)[0], &"impact_ground", "sub-metre splash")
	weapon.impact_size = 1.5
	assert_eq(CombatCues.impact_events(weapon, null)[0], &"explosion_small")
	weapon.impact_size = 3.0
	assert_eq(CombatCues.impact_events(weapon, null)[0], &"explosion_medium")
	weapon.impact_size = 6.0
	assert_eq(CombatCues.impact_events(weapon, null)[0], &"explosion_large")


func test_impacts_on_hidden_victims_are_silent() -> void:
	var victim: FakeEntity = _entity(&"skitter", 1)
	victim.is_visible_to_player = false
	_router.handle_projectile_impacted(FakeWeapon.new(), Vector3(4, 0, 4), victim, 0.0)
	_router.flush(0.0)
	assert_eq(_played.size(), 0)


func test_ground_impacts_ask_the_fog() -> void:
	var fog: FakeFog = FakeFog.new()
	fog.add_to_group(CombatSoundRouter.FOG_GROUP)
	add_child_autofree(fog)
	_router.handle_projectile_impacted(FakeWeapon.new(), Vector3(150, 0, 0), null, 0.0)
	_router.flush(0.0)
	assert_eq(_played.size(), 0, "hidden ground")
	_router.handle_projectile_impacted(FakeWeapon.new(), Vector3(20, 0, 0), null, 0.0)
	_router.flush(1.0)
	assert_eq(_played, [&"impact_ground"] as Array[StringName])


func test_deaths_by_weight_class() -> void:
	# [0] is always the entity's own death_<set>, played only if it exists.
	assert_eq(CombatCues.death_events(_entity(&"ranger"))[0], &"death_ranger")
	assert_eq(CombatCues.death_events(_entity(&"ranger"))[1], &"death_light")
	var mauler: FakeEntity = _entity(&"mauler", 1, Vector3.ZERO, &"heavy")
	assert_eq(CombatCues.death_events(mauler)[1], &"death_heavy")
	var untyped: FakeEntity = _entity(&"x", 1)
	untyped.def = EntityDef.new()
	untyped.def.sound_set = &"mauler"
	assert_eq(
		CombatCues.death_events(untyped)[1], &"death_heavy", "no armour class: chassis decides"
	)
	var building: FakeEntity = _entity(&"sentry")
	building.add_to_group(&"buildings")
	assert_eq(CombatCues.death_events(building)[1], &"death_building")


func test_the_warden_has_its_own_death_and_weapon() -> void:
	var warden: FakeEntity = _entity(&"warden", 2)
	assert_eq(CombatCues.death_events(warden)[0], &"death_warden")
	assert_true(ResourceLoader.exists("res://data/sounds/explosion/death_warden.tres"))
	var weapon: FakeWeapon = FakeWeapon.new()
	weapon.sound_set = &"warden_bell_bolt"
	var events: Array[StringName] = CombatCues.fire_events(weapon)
	assert_eq(events[-1], &"weapon_warden_fire", "unaliased data name -> owner family")
	assert_true(ResourceLoader.exists("res://data/sounds/weapon/weapon_warden_fire.tres"))


func test_hidden_deaths_are_silent_but_still_count() -> void:
	var enemy: FakeEntity = _entity(&"skitter", 1)
	enemy.is_visible_to_player = false
	_router.handle_entity_died(enemy, 0.0)
	_router.flush(0.0)
	assert_eq(_played.size(), 0)
	assert_gt(_router.mood.heat(0.0), 0.0)


func test_a_sentry_that_starts_firing_swings_its_turret() -> void:
	var sentry: FakeEntity = _entity(&"sentry")
	var weapon: FakeWeapon = FakeWeapon.new()
	weapon.sound_set = &"sentry"
	_router.handle_weapon_fired(sentry, weapon, Vector3.ONE, 0.0)
	_router.handle_weapon_fired(sentry, weapon, Vector3.ONE, 1.0)
	assert_eq(_played.count(CombatSoundRouter.TRAVERSE_EVENT), 1, "only after a pause")
	_router.handle_weapon_fired(sentry, weapon, Vector3.ONE, 1.0 + CombatSoundRouter.TRAVERSE_AFTER)
	assert_eq(_played.count(CombatSoundRouter.TRAVERSE_EVENT), 2)


func test_music_follows_the_fight() -> void:
	var ours: FakeEntity = _entity(&"ranger", 0)
	var theirs: FakeEntity = _entity(&"skitter", 1)
	var t: float = 0.0
	while t < 5.0:
		_router.handle_weapon_fired(ours, FakeWeapon.new(), ours.global_position, t)
		_router.handle_entity_damaged(ours, 4.0, theirs, t)
		_router.update_mood(t)
		t += 0.25
	assert_eq(_states[-1], MusicMood.COMBAT)


func test_mission_end_settles_the_music_once() -> void:
	_router.handle_mission_ended(false)
	_router.handle_mission_ended(true)
	assert_eq(_ended, [false] as Array[bool])
	_router.update_mood(1.0)
	assert_eq(_states.size(), 0, "no state requests after the end")
	var ours: FakeEntity = _entity(&"ranger", 0)
	_router.handle_entity_damaged(ours, 4.0, null, 2.0)
	_router.flush(2.0)
	assert_eq(_played.size(), 0)


func test_a_new_mission_brings_combat_audio_back() -> void:
	_router.handle_mission_ended(true)
	_router.handle_mission_started()
	assert_eq(_states[-1], MusicMood.EXPLORE, "the score returns to explore")
	_router.handle_mission_ended(false)
	assert_eq(_ended, [true, false] as Array[bool], "the next ending plays its sting too")
