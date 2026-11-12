extends GutTest
## The armour x damage table: lookups, defaults and the shipped data.


func test_listed_pairs_use_their_multiplier_and_others_full_damage() -> void:
	var table: DamageTable = DamageTable.new()
	table.multipliers = {DamageTable.key(&"light", &"heavy"): 0.5}
	assert_almost_eq(table.multiplier(&"light", &"heavy"), 0.5, 1e-6)
	assert_almost_eq(table.multiplier(&"light", &"light"), 1.0, 1e-6, "unlisted = full")
	assert_almost_eq(table.apply(30.0, &"light", &"heavy"), 15.0, 1e-6)


func test_shipped_table_favours_the_right_tools() -> void:
	var table: DamageTable = load("res://data/combat/damage_table.tres")
	assert_not_null(table)
	var types: Array[StringName] = [&"light", &"heavy", &"pierce"]
	var armours: Array[StringName] = [&"light", &"heavy", &"structure"]
	for damage_type: StringName in types:
		for armour: StringName in armours:
			assert_true(
				table.multipliers.has(DamageTable.key(damage_type, armour)),
				"%s vs %s listed" % [damage_type, armour]
			)
	assert_gt(table.multiplier(&"light", &"light"), table.multiplier(&"light", &"heavy"))
	assert_gt(table.multiplier(&"pierce", &"heavy"), table.multiplier(&"light", &"heavy"))
	assert_gt(table.multiplier(&"heavy", &"structure"), table.multiplier(&"light", &"structure"))


func test_every_shipped_unit_and_building_has_health_and_armour() -> void:
	for dir_path: String in ["res://data/units/", "res://data/buildings/"]:
		for file: String in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".tres"):
				continue
			var def: EntityDef = load(dir_path + file)
			var health: int = def.get(&"max_health")
			var armour: StringName = def.get(&"armour_type")
			assert_gt(health, 0, "%s has health" % file)
			assert_ne(armour, &"", "%s states its armour" % file)


func test_armed_and_unarmed_roster() -> void:
	var armed: Array[String] = [
		"concord_ranger",
		"concord_bulwark",
		"concord_kite",
		"combine_skitter",
		"combine_stinger",
		"combine_mauler",
	]
	for id: String in armed:
		var def: UnitDef = load("res://data/units/%s.tres" % id)
		assert_true(def.is_armed(), "%s is armed" % id)
		assert_ne(def.weapon.sound_set, &"", "%s weapon has a sound set" % id)
	for id: String in ["concord_surveyor", "concord_hauler", "concord_fabricator"]:
		var def: UnitDef = load("res://data/units/%s.tres" % id)
		assert_false(def.is_armed(), "%s is unarmed" % id)
	var sentry: BuildingDef = load("res://data/buildings/concord_sentry.tres")
	assert_not_null(sentry.weapon)
	assert_gt(sentry.power_use, 0, "the Sentry uses power")
	var mauler: UnitDef = load("res://data/units/combine_mauler.tres")
	assert_eq(mauler.faction, 1, "Combine units are faction 1")
	assert_eq(mauler.weapon.salvo, 2, "twin shells")
