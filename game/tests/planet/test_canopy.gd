extends GutTest
## Verdance's planet rule (ADR 0016): canopy hides ground units from the air and from
## long-range sight. Under a crown a unit (or building) is seen only by an enemy ground
## observer within close sight, never from the air, and by everyone for a while after
## it fires; it sees out as usual. Hidden means the same for vision, targeting, the AI's
## port, stealth watchers and the player's view. Cover changes are announced, the
## faction's perks widen close sight, and the reveals and cover save and load.

const VERDANCE: String = "res://data/planets/verdance.tres"
## One crown, 15 m round, at the origin.
const CROWN: Vector4 = Vector4(0, 0, 15, 15)

var _f: MissionFixture
var _rule: CanopyRule
var _flyer: UnitDef
var _covers: Array[Array] = []


func before_each() -> void:
	_f = MissionFixture.new(self)
	_f.world.canopy_zones = PackedVector4Array([CROWN])
	_rule = CanopyRule.new()
	_rule.id = &"test_canopy"
	_rule.system = CanopySystem
	_rule.close_sight = 9.0
	_rule.fire_reveal_seconds = 4.0
	_flyer = _f.combat.soldier.duplicate() as UnitDef
	_flyer.id = &"flyer"
	_flyer.flies = true
	_flyer.flight_altitude = 13.0
	_flyer.armour_type = DamageTable.ARMOUR_AIR
	_flyer.can_carry = false
	_covers.clear()
	Events.canopy_cover_changed.connect(_on_cover)


func after_each() -> void:
	Events.canopy_cover_changed.disconnect(_on_cover)
	_f.dispose()


func _on_cover(unit: Node3D, covered: bool) -> void:
	_covers.append([unit, covered])


func _start() -> CanopySystem:
	return PlanetRuleSystem.start(_f.world, _rule) as CanopySystem


func _scout(faction: int, at: Vector3) -> Unit:
	return _f.spawn(_f.combat.scout, faction, at)


func test_verdance_plays_the_canopy_rule() -> void:
	var planet: PlanetDef = load(VERDANCE)
	var rule: CanopyRule = planet.rule as CanopyRule
	assert_not_null(rule, "Verdance plays a CanopyRule")
	assert_eq(rule.system, CanopySystem)
	assert_eq(planet.id, &"verdance")
	assert_between(rule.close_sight, 6.0, 12.0, "seen only from close by")
	assert_gt(rule.fire_reveal_seconds, 0.0, "firing gives a unit away")
	assert_true(rule.hides_buildings)


func test_the_cover_map_follows_the_crowns() -> void:
	var canopy: CanopySystem = _start()
	assert_not_null(canopy)
	assert_eq(_f.world.vision.cover, canopy, "the vision system asks it")
	assert_eq(_f.world.stealth.cover, canopy, "so does stealth")
	assert_true(canopy.is_under_canopy(Vector3.ZERO))
	assert_true(canopy.is_under_canopy(Vector3(0, 0, 14)))
	assert_true(canopy.is_under_canopy(Vector3(10, 0, 10)), "inside the ellipse")
	assert_false(canopy.is_under_canopy(Vector3(0, 0, 16)))
	assert_false(canopy.is_under_canopy(Vector3(11, 0, 11)), "the ellipse's corner")
	assert_false(canopy.is_under_canopy(Vector3(60, 0, 0)))
	assert_eq(canopy.indicator_title(), "CANOPY")


func test_a_ground_unit_under_a_crown_is_seen_only_from_close_by() -> void:
	var canopy: CanopySystem = _start()
	var hidden: Unit = _scout(1, Vector3(0, 0, 0))
	_scout(0, Vector3(0, 0, 20))
	_f.tick(4)
	assert_true(canopy.is_covered(hidden))
	var vision: VisionSystem = _f.world.vision
	assert_true(vision.grid.is_visible(0, hidden.sim_position()), "the ground is in sight")
	assert_false(vision.can_see(0, hidden), "but not what stands under the crown")
	assert_false(hidden.is_visible_to_player, "the player is not shown it")
	assert_false(hidden.visible, "nor the minimap (it reads `visible`)")
	assert_false(_f.world.combat.can_target(0, hidden))
	_scout(0, Vector3(0, 0, 8))
	_f.tick(4)
	assert_true(vision.can_see(0, hidden), "a ground observer 8 m off sees it")
	assert_true(hidden.is_visible_to_player)
	assert_true(_f.world.combat.can_target(0, hidden))


func test_flyers_never_see_under_a_crown() -> void:
	var canopy: CanopySystem = _start()
	var hidden: Unit = _scout(1, Vector3(0, 0, 0))
	var flyer: Unit = _f.spawn(_flyer, 0, Vector3(0, 0, 3))
	_f.tick(4)
	assert_true(flyer.flies)
	assert_false(canopy.is_covered(flyer), "flyers are never covered")
	assert_false(_f.world.vision.can_see(0, hidden), "a flyer overhead sees nothing")
	assert_true(canopy.hides_from_air(hidden))
	_scout(0, Vector3(0, 0, 6))
	_f.tick(4)
	assert_true(_f.world.vision.can_see(0, hidden), "a ground friend spots it")
	assert_false(
		_f.world.combat.can_engage(flyer, flyer.weapon.def, hidden), "the flyer still cannot aim"
	)
	_f.tick(30)
	assert_eq(hidden.health.current, float(_f.combat.scout.max_health), "never shot from above")


func test_a_unit_that_fires_is_revealed_for_a_while() -> void:
	var canopy: CanopySystem = _start()
	var shooter: Unit = _scout(1, Vector3(0, 0, 0))
	var flyer: Unit = _f.spawn(_flyer, 0, Vector3(0, 0, 18))
	_scout(0, Vector3(0, 0, 20))
	_f.tick(4)
	assert_false(_f.world.vision.can_see(0, shooter))
	Events.weapon_fired.emit(shooter, _f.combat.rifle, shooter.sim_position(), Vector3.ZERO)
	_f.tick(3)
	assert_true(canopy.is_revealed(shooter))
	assert_true(_f.world.vision.can_see(0, shooter), "the shot gives it away")
	assert_true(_f.world.combat.can_engage(flyer, flyer.weapon.def, shooter), "even to the air")
	_f.tick(40)
	assert_false(canopy.is_revealed(shooter))
	assert_false(_f.world.vision.can_see(0, shooter), "hidden again after the reveal")


func test_buildings_under_a_crown_are_hidden_until_something_comes_close() -> void:
	_start()
	var hq: Building = _f.world.spawn_building(_f.combat.hq, 1, Vector3.ZERO, true)
	_scout(0, Vector3(0, 0, 22))
	_f.tick(4)
	assert_false(_f.world.vision.can_see(0, hq))
	assert_false(hq.seen_by_player, "never shown")
	_scout(0, Vector3(0, 0, 10))
	_f.tick(4)
	assert_true(_f.world.vision.can_see(0, hq), "7 m from its walls")
	assert_true(hq.seen_by_player)


func test_a_covered_unit_sees_out() -> void:
	_start()
	var ambusher: Unit = _scout(0, Vector3(0, 0, 0))
	var walker: Unit = _scout(1, Vector3(0, 0, 22))
	_f.tick(4)
	assert_true(_f.world.vision.can_see(0, walker), "it sees into the open")
	assert_false(_f.world.vision.can_see(1, ambusher), "and is not seen back")


func test_going_under_and_out_is_announced() -> void:
	var canopy: CanopySystem = _start()
	var walker: Unit = _scout(0, Vector3(0, 0, 30))
	_f.tick(2)
	assert_eq(_covers.size(), 0, "in the open")
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [walker], Vector3(0, 0, 0)))
	_f.tick(80)
	assert_true(canopy.is_covered(walker))
	assert_eq(_covers.size(), 1)
	var first: Array = _covers[0]
	var who: Node3D = first[0]
	var under: bool = first[1]
	assert_eq(who, walker)
	assert_true(under, "went under")
	assert_eq(canopy.indicator_text(0), "1 UNDER COVER")
	assert_almost_eq(canopy.indicator_level(), 1.0, 0.01)
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [walker], Vector3(0, 0, 30)))
	_f.tick(80)
	assert_false(canopy.is_covered(walker))
	assert_eq(_covers.size(), 2)
	var second: Array = _covers[1]
	var still_under: bool = second[1]
	assert_false(still_under, "came out")
	assert_eq(canopy.indicator_text(0), "IN THE OPEN")


func test_the_ai_port_reports_only_what_its_faction_may_see() -> void:
	_start()
	var hidden: Unit = _scout(0, Vector3(0, 0, 0))
	_scout(1, Vector3(0, 0, 20))
	_f.spawn(_flyer, 1, Vector3(0, 0, 2))
	_f.tick(4)
	var port: WorldAiPort = WorldAiPort.new(_f.base.context, _f.world, 1)
	assert_false(port.seen_enemies(Vector3(0, 0, 20), 30.0).has(hidden), "no cheating")
	assert_false(port.seen_enemies(Vector3(0, 0, 2), 30.0).has(hidden), "not from the air")
	var knowledge: AiKnowledge = AiKnowledge.new(1, 400)
	knowledge.observe(port.seen_enemies(Vector3.ZERO, 40.0), _f.mission_tick())
	assert_eq(knowledge.recent_units(_f.mission_tick(), 100).size(), 0, "nothing remembered")
	_scout(1, Vector3(0, 0, 7))
	_f.tick(4)
	assert_true(port.seen_enemies(Vector3(0, 0, 7), 30.0).has(hidden), "once they come close")


func test_watchers_do_not_notice_what_the_canopy_hides() -> void:
	_start()
	_f.world.stealth.add_guard_faction(1)
	var guard: Unit = _f.spawn(_f.guard, 1, Vector3(0, 0, 20), 0.0)
	var open_guard: Unit = _f.spawn(_f.guard, 1, Vector3(60, 0, 20), 0.0)
	_scout(0, Vector3(0, 0, 5))
	_scout(0, Vector3(60, 0, 5))
	_f.tick(30)
	assert_eq(guard.watcher.suspicion, 0.0, "15 m into a grove: nothing")
	assert_gt(open_guard.watcher.suspicion, 0.0, "the same walk in the open is noticed")


func test_the_canopy_sight_perk_widens_close_sight() -> void:
	_start()
	var hidden: Unit = _scout(1, Vector3(0, 0, 0))
	_scout(0, Vector3(0, 0, 12))
	_f.tick(4)
	assert_false(_f.world.vision.can_see(0, hidden), "12 m is too far")
	var perks: FactionPerks = FactionPerks.new()
	perks.add_scale(&"", FactionPerks.CANOPY_SIGHT, 1.5)
	_f.world.perks[0] = perks
	_f.tick(4)
	assert_true(_f.world.vision.can_see(0, hidden), "13.5 m with Understory Optics")


func test_reveals_and_cover_save_and_load() -> void:
	var canopy: CanopySystem = _start()
	var shooter: Unit = _scout(1, Vector3(0, 0, 0))
	var resting: Unit = _scout(0, Vector3(0, 0, -6))
	_f.tick(4)
	Events.weapon_fired.emit(shooter, _f.combat.rifle, shooter.sim_position(), Vector3.ZERO)
	_f.tick(10)
	var data: Dictionary = canopy.to_dict()
	var version: int = data["version"]
	assert_eq(version, CanopySystem.SAVE_VERSION)
	var revealed: Dictionary = data["revealed"]
	assert_true(revealed.has(str(shooter.entity_id)))
	_covers.clear()
	var restored: CanopySystem = PlanetRuleSystem.start(_f.world, _rule) as CanopySystem
	restored.from_dict(data)
	assert_true(restored.is_revealed(shooter), "the reveal carries on")
	assert_true(restored.is_covered(resting))
	assert_true(restored.is_covered(shooter))
	assert_eq(restored.to_dict(), data, "the same save")
	_f.tick(4)
	assert_eq(_covers.size(), 0, "no cover news for units already under the crown")
	_f.tick(30)
	assert_false(restored.is_revealed(shooter), "until it runs out")
