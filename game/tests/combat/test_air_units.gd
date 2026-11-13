extends GutTest
## Flying units (ADR 0016): the Talon and the Hornet as data, straight flight at
## altitude over anything (no navmesh, never blocking or blocked by ground units),
## separation, which guns hit air, flyers attacking the ground, and the enemy AI
## answering flyers.

const TALON: String = "res://data/units/concord_talon.tres"
const HORNET: String = "res://data/units/combine_hornet.tres"

var _f: CombatFixture
var _flyer: UnitDef
var _flak: WeaponDef
var _gunner: UnitDef


func before_each() -> void:
	_f = CombatFixture.new(self)
	_flyer = _f.soldier.duplicate() as UnitDef
	_flyer.id = &"flyer"
	_flyer.flies = true
	_flyer.flight_altitude = 13.0
	_flyer.armour_type = DamageTable.ARMOUR_AIR
	_flyer.can_carry = false
	_flyer.move_speed = 10.0
	_flyer.radius = 1.2
	_flak = _f.rifle.duplicate() as WeaponDef
	_flak.id = &"flak"
	_flak.hits_air = true
	_gunner = _f.soldier.duplicate() as UnitDef
	_gunner.id = &"gunner"
	_gunner.weapon = _flak


func after_each() -> void:
	_f.dispose()


func test_the_talon_and_the_hornet_fly() -> void:
	var talon: UnitDef = load(TALON)
	var hornet: UnitDef = load(HORNET)
	for def: UnitDef in [talon, hornet]:
		assert_true(def.flies, "%s flies" % def.id)
		assert_gt(def.flight_altitude, 13.0 - 0.01, "above the crowns")
		assert_eq(def.armour(), DamageTable.ARMOUR_AIR)
		assert_false(def.can_carry, "nothing to carry")
		assert_not_null(def.scene)
		assert_not_null(def.icon)
		assert_not_null(def.weapon)
		assert_true(def.weapon.hits_ground, "they attack the ground")
	assert_eq(talon.faction, 0)
	assert_eq(hornet.faction, 1)
	assert_true(talon.weapon.hits_air, "the Talon also fights flyers")
	assert_false(hornet.weapon.hits_air, "the Hornet does not")
	var foundry: BuildingDef = load("res://data/buildings/concord_foundry.tres")
	var forge: BuildingDef = load("res://data/buildings/combine_forge.tres")
	assert_true(foundry.produces.has(talon), "Talons come from the Foundry")
	assert_true(forge.produces.has(hornet), "Hornets from the Forge")


func test_their_models_have_fans() -> void:
	var expect: Dictionary = {TALON: ["fan_l", "fan_r"], HORNET: ["fan"]}
	for path: String in expect:
		var def: UnitDef = load(path)
		var unit: Unit = def.scene.instantiate() as Unit
		var visual: UnitVisual = unit.get_node(^"Visual") as UnitVisual
		var model: Node3D = visual.model_scene.instantiate() as Node3D
		var names: Array = expect[path]
		for part: Variant in names:
			assert_not_null(model.find_child(str(part), true, false), "%s has %s" % [def.id, part])
		model.free()
		unit.free()


func test_which_guns_hit_air_is_data() -> void:
	var up: Array[String] = ["ranger_repeater", "sentry_repeater", "skitter_needler", "spire_lance"]
	var down: Array[String] = [
		"lancer_rail", "bulwark_cannon", "arc_howitzer", "mauler_twin_cannon", "stinger_lance"
	]
	for id: String in up:
		var weapon: WeaponDef = load("res://data/weapons/%s.tres" % id)
		assert_true(weapon.reaches(true), "%s shoots up" % id)
		assert_true(weapon.reaches(false), "%s still hits the ground" % id)
	for id: String in down:
		var weapon: WeaponDef = load("res://data/weapons/%s.tres" % id)
		assert_false(weapon.reaches(true), "%s cannot hit flyers" % id)
	var table: DamageTable = load("res://data/combat/damage_table.tres")
	assert_true(table.multipliers.has(DamageTable.key(&"light", DamageTable.ARMOUR_AIR)))
	assert_lt(table.multiplier(&"pierce", DamageTable.ARMOUR_AIR), 1.0, "lances glance off")


func test_a_flyer_flies_straight_over_anything_at_altitude() -> void:
	var flyer: Unit = _f.spawn(_flyer, 0, Vector3.ZERO)
	assert_eq(flyer.locomotion.paths, _f.world.air_paths, "no navmesh for flyers")
	assert_almost_eq(flyer.sim_position().y, 13.0, 0.01, "at its altitude")
	# A wall straight across its way: ground paths go round, flyers do not care.
	_f.world.paths.block_area(Rect2(8, -30, 4, 60))
	_f.push(MoveCommand.new(MoveCommand.KIND_MOVE, 0, [flyer], Vector3(30, 0, 0)))
	_f.tick(1)
	assert_eq(flyer.locomotion.mover.path.size(), 1, "one straight leg")
	_f.tick(60)
	assert_true(flyer.orders.is_idle(), "it arrived")
	var at: Vector3 = flyer.sim_position()
	assert_almost_eq(Vector2(at.x, at.z).distance_to(Vector2(30, 0)), 0.0, 0.5)
	assert_almost_eq(at.y, 13.0, 0.01, "still at altitude")


func test_flyers_keep_apart_and_never_block_the_ground() -> void:
	var a: Unit = _f.spawn(_flyer, 0, Vector3(0, 0, 0))
	var b: Unit = _f.spawn(_flyer, 0, Vector3(0.2, 0, 0))
	var walker: Unit = _f.spawn(_f.soldier, 0, Vector3(20, 0, 0))
	_f.tick(30)
	var apart: float = (
		Vector2(a.sim_position().x - b.sim_position().x, a.sim_position().z - b.sim_position().z)
		. length()
	)
	assert_gt(apart, _flyer.radius * 2.0, "pushed apart")
	# A building placed under a flyer moves the walker out, not the flyer.
	var hover: Unit = _f.spawn(_flyer, 0, Vector3(20, 0, 5))
	_f.world.spawn_building(_f.hq, 0, Vector3(20, 0, 5), true)
	assert_true(hover.orders.is_idle(), "nothing to make room for")
	_f.world.evacuate(Rect2(16, -4, 8, 8))
	assert_false(walker.orders.is_idle(), "the walker steps out")


func test_only_guns_that_hit_air_shoot_flyers() -> void:
	var unarmed: UnitDef = _flyer.duplicate() as UnitDef
	unarmed.weapon = null
	var flyer: Unit = _f.spawn(unarmed, 1, Vector3(0, 0, 0))
	var rifleman: Unit = _f.spawn(_f.soldier, 0, Vector3(0, 0, 6))
	var gunner: Unit = _f.spawn(_gunner, 0, Vector3(0, 0, -6))
	assert_false(_f.world.combat.can_engage(rifleman, rifleman.weapon.def, flyer))
	assert_true(_f.world.combat.can_engage(gunner, gunner.weapon.def, flyer))
	_f.tick(25)
	assert_lt(flyer.health.current, float(_flyer.max_health), "the gunner hits it")
	assert_eq(rifleman.weapon.target, null, "the rifleman never aims at it")
	# An attack order from a gun that cannot hit air is left alone.
	_f.push(AttackCommand.new(0, [rifleman], flyer))
	_f.tick(2)
	assert_true(rifleman.orders.is_idle(), "it does not chase what it cannot hit")


func test_flyers_attack_ground_units_and_shells_burst_under_them() -> void:
	var flyer: Unit = _f.spawn(_flyer, 0, Vector3(0, 0, 0))
	var target: Unit = _f.spawn(_f.scout, 1, Vector3(0, 0, 6))
	_f.tick(25)
	assert_lt(target.health.current, float(_f.scout.max_health), "the flyer fires on the ground")
	_f.spawn(_f.tank, 1, Vector3(15, 0, 0))
	var ground: Unit = _f.spawn(_f.soldier, 0, Vector3(1, 0, 1))
	var health: float = flyer.health.current
	_f.tick(80)
	assert_lt(ground.health.current, float(_f.soldier.max_health), "the shells land")
	assert_eq(flyer.health.current, health, "and never hit the flyer above")


func test_the_commander_answers_flyers() -> void:
	var profile: CommanderProfile = load("res://data/ai/combine_understory.tres")
	var hornet: UnitDef = load(HORNET)
	assert_true(profile.army.has(hornet), "the Verdance commander builds Hornets")
	assert_not_null(profile.anti_air)
	assert_true(profile.anti_air.weapon.hits_air, "its anti-air unit shoots up")
	var brain: CommanderBrain = CommanderBrain.new(profile, profile.normal)
	var calm: int = 0
	var alarmed: int = 0
	for i: int in 400:
		if brain.pick_army_unit(0.0, 0.0) == profile.anti_air:
			calm += 1
		if brain.pick_army_unit(0.0, 1.0) == profile.anti_air:
			alarmed += 1
	assert_gt(alarmed, calm + 80, "Talons seen: more units that shoot up")
	for path: String in [
		"res://data/ai/combine_commander.tres",
		"res://data/ai/combine_raiders.tres",
		"res://data/ai/combine_salvagers.tres",
		"res://data/ai/combine_caldera.tres",
	]:
		var other: CommanderProfile = load(path)
		assert_not_null(other.anti_air, "%s answers flyers too" % path)


func test_ai_groups_focus_on_what_they_can_hit() -> void:
	var flyer: Unit = _f.spawn(_flyer, 0, Vector3(0, 0, 2))
	var walker: Unit = _f.spawn(_f.soldier, 0, Vector3(0, 0, 8))
	var rifleman: Unit = _f.spawn(_f.soldier, 1, Vector3(0, 0, 14))
	var members: Array[Unit] = [rifleman]
	var enemies: Array[Node3D] = [flyer, walker]
	assert_eq(AttackGroup.pick_focus(enemies, rifleman.sim_position(), members), walker)
	assert_eq(AiGroup.able_to_hit(members, flyer).size(), 0)
	var knowledge: AiKnowledge = AiKnowledge.new(1, 400)
	knowledge.observe(enemies, 0)
	assert_almost_eq(knowledge.air_share(), 0.5, 0.01, "half of what it saw flies")
