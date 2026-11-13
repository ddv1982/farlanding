extends GutTest
## The Wisp, Lancer and Arc: their definitions, production entries and the Arc's
## minimum range.

var _f: CombatFixture


func before_each() -> void:
	_f = CombatFixture.new(self)


func after_each() -> void:
	_f.dispose()


func test_definitions_load_with_models_and_icons() -> void:
	for id: String in ["concord_wisp", "concord_lancer", "concord_arc"]:
		var def: UnitDef = load("res://data/units/%s.tres" % id)
		assert_not_null(def.scene, id)
		assert_not_null(def.icon, id)
		assert_eq(String(def.id), id)


func test_wisp_is_an_unarmed_cloaking_saboteur() -> void:
	var wisp: UnitDef = load("res://data/units/concord_wisp.tres")
	assert_null(wisp.weapon)
	assert_true(wisp.can_cloak)
	assert_true(wisp.can_sabotage())
	assert_lt(wisp.signature, 1.0)
	assert_lt(wisp.cloak_signature, wisp.signature)


func test_lancer_beats_armour_and_arc_outranges_everything() -> void:
	var lancer: UnitDef = load("res://data/units/concord_lancer.tres")
	var arc: UnitDef = load("res://data/units/concord_arc.tres")
	var table: DamageTable = load("res://data/combat/damage_table.tres")
	assert_gt(
		table.apply(lancer.weapon.damage, lancer.weapon.damage_type, &"heavy"), lancer.weapon.damage
	)
	assert_gt(arc.weapon.max_range, 30.0)
	assert_gt(arc.weapon.min_range, 0.0)
	assert_lt(arc.weapon.min_range, arc.weapon.max_range)
	assert_gt(arc.weapon.max_range, arc.vision_range, "it needs spotters")
	assert_lt(arc.weapon.projectile_speed, 30.0, "slow shells")


func test_new_units_are_produced_where_they_belong() -> void:
	var muster: BuildingDef = load("res://data/buildings/concord_muster_bay.tres")
	var foundry: BuildingDef = load("res://data/buildings/concord_foundry.tres")
	var ids: Array[StringName] = []
	for def: UnitDef in muster.produces + foundry.produces:
		ids.append(def.id)
	for id: StringName in [&"concord_wisp", &"concord_lancer", &"concord_arc"]:
		assert_true(ids.has(id), String(id))


func test_minimum_range_keeps_close_targets_safe() -> void:
	var mortar: WeaponDef = _f.cannon.duplicate()
	mortar.min_range = 8.0
	var artillery: UnitDef = _f.tank.duplicate()
	artillery.weapon = mortar
	var gun: Unit = _f.spawn(artillery, 0, Vector3.ZERO)
	var close: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, -4))
	_f.tick(40)
	assert_eq(close.health.current, float(_f.scout.max_health), "too close to shell")
	var far: Unit = _f.spawn(_f.scout, 1, Vector3(15, 0, 0))
	_f.tick(60)
	assert_lt(far.health.current, float(_f.scout.max_health), "in its band it fires")
	assert_true(gun.weapon.in_range(far, gun.sim_position()))
	assert_false(gun.weapon.in_range(close, gun.sim_position()))
