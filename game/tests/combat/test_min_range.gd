extends GutTest
## Artillery (the Arc) with a minimum range: an ordered target inside it makes the
## unit back away until it can fire, an attacker up close is answered the same way,
## and auto-targeting picks something it can hit over something too close. A dust
## storm shortens the reach attack orders close to.

var _f: CombatFixture
var _gun: WeaponDef
var _arc: UnitDef


func before_each() -> void:
	_f = CombatFixture.new(self)
	_gun = _f.rifle.duplicate() as WeaponDef
	_gun.id = &"howitzer"
	_gun.max_range = 30.0
	_gun.min_range = 12.0
	_gun.damage = 25.0
	_arc = _f.soldier.duplicate() as UnitDef
	_arc.id = &"arc"
	_arc.weapon = _gun
	_arc.move_speed = 6.0
	_arc.acceleration = 30.0
	_arc.vision_range = 40.0


func after_each() -> void:
	_f.dispose()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_an_ordered_target_inside_minimum_range_makes_it_back_away_and_fire() -> void:
	var arc: Unit = _f.spawn(_arc, 0, Vector3.ZERO)
	var target: Unit = _f.spawn(_f.scout, 1, Vector3(5, 0, 0))
	_f.push(AttackCommand.new(0, [arc] as Array[Node3D], target))
	_f.tick(80)
	assert_gt(_flat(arc.sim_position(), target.sim_position()), _gun.min_range, "backed away")
	assert_lt(target.health.current, target.health.max_health, "and fired")


func test_an_attacker_up_close_is_answered_from_outside_minimum_range() -> void:
	var arc: Unit = _f.spawn(_arc, 0, Vector3.ZERO)
	var pest: Unit = _f.spawn(_f.soldier, 1, Vector3(4, 0, 0))
	pest.orders.stop()
	_f.tick(60)
	assert_gt(_flat(arc.sim_position(), pest.sim_position()), _gun.min_range, "it made room")
	assert_lt(pest.health.current, pest.health.max_health, "then shelled it")


func test_auto_targeting_prefers_what_it_can_hit() -> void:
	var arc: Unit = _f.spawn(_arc, 0, Vector3.ZERO)
	var close: Unit = _f.spawn(_f.scout, 1, Vector3(5, 0, 0))
	var far: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, 20))
	_f.tick(10)
	assert_eq(arc.weapon.target, far, "the one in its band, not the one too close")
	assert_false(arc.weapon.in_range(close, arc.sim_position()))


func test_a_storm_shortens_the_engagement_distance() -> void:
	var arc: Unit = _f.spawn(_arc, 0, Vector3.ZERO)
	_f.tick(1)
	var calm: float = arc.orders.engage_distance
	_f.world.conditions.long_range_from = 18.0
	_f.world.conditions.range_factor = 0.7
	_f.tick(1)
	assert_almost_eq(arc.weapon.max_range(), 21.0, 0.01)
	assert_lt(arc.orders.engage_distance, calm, "attack orders close in further")
	assert_almost_eq(arc.orders.min_engage_distance, 12.0 + UnitOrders.ENGAGE_MARGIN, 0.01)
