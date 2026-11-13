extends GutTest
## What reaches a landing (ADR 0012): the LandingBuilder turns techs, loadout and
## earlier finds into LandingModifiers, and the sim applies them through the
## faction's perks (locks, stat scales, field option costs and charges) and the
## Mission (extra crew, resources, unlocked options) without knowing the campaign.

const CAMPAIGN: String = "res://data/campaign/kessel_trail.tres"

var _def: CampaignDef
var _state: CampaignState
var _f: MissionFixture


func before_each() -> void:
	_def = load(CAMPAIGN)
	_state = CampaignState.new(_def)
	_f = MissionFixture.new(self)


func after_each() -> void:
	_f.dispose()


func _modifiers() -> LandingModifiers:
	return LandingBuilder.build(_def, LandingPlan.from_state(_state, &"kessel_proving"))


func test_a_fresh_campaign_starts_with_the_locks_only() -> void:
	var modifiers: LandingModifiers = _modifiers()
	for id: StringName in [&"concord_survey_lab", &"concord_lancer", &"concord_sentry"]:
		assert_true(modifiers.perks.is_locked(id), "%s starts locked" % id)
	assert_true(modifiers.perks.is_locked(&"concord_arc"))
	assert_eq(modifiers.extra_roster.size(), 0)
	assert_eq(modifiers.bonus_alloy, 150, "the default cargo: Alloy pallets")


func test_techs_loadout_and_finds_build_the_modifiers() -> void:
	_state.techs.append_array(
		(
			[&"survey_lab", &"lancer_rails", &"hauler_racks", &"supply_manifest", &"long_optics"]
			as Array[StringName]
		)
	)
	_state.discoveries.append_array(
		[&"kessel_trail_beacon", &"kessel_combine_relay"] as Array[StringName]
	)
	assert_true(_state.choose_loadout(&"escort", &"escort_lancers"))
	assert_true(_state.choose_loadout(&"ship", &"ship_orbital_scan"))
	assert_true(_state.choose_loadout(&"cargo", &"cargo_alloy"))
	var modifiers: LandingModifiers = _modifiers()
	assert_false(modifiers.perks.is_locked(&"concord_survey_lab"), "the lab is cleared")
	assert_false(modifiers.perks.is_locked(&"concord_lancer"))
	assert_true(modifiers.perks.is_locked(&"concord_arc"), "the Arc is not")
	assert_almost_eq(
		modifiers.perks.scale(&"concord_hauler", FactionPerks.CARRY_CAPACITY), 1.25, 0.001
	)
	assert_almost_eq(modifiers.perks.scale(&"anything", FactionPerks.VISION_RANGE), 1.2, 0.001)
	assert_eq(modifiers.extra_roster.size(), 2, "two Lancers")
	assert_eq(modifiers.extra_roster[0].id, &"concord_lancer")
	assert_eq(modifiers.bonus_alloy, 200 + 150, "manifest and cargo")
	assert_eq(modifiers.bonus_flux, 50)
	assert_eq(modifiers.bonus_intel, 30, "the relay's codes")
	var charges: int = modifiers.option_charges.get(&"orbital_scan", 0)
	assert_eq(charges, 1)
	assert_true(modifiers.charts(&"kessel_trail_ruin"), "the beacon's bearing")
	assert_false(modifiers.notes.is_empty(), "the briefing lists them")


func test_perks_scale_stats_and_remove_locked_production() -> void:
	var perks: FactionPerks = FactionPerks.new()
	perks.add_scale(&"", FactionPerks.MAX_HEALTH, 1.5)
	perks.add_scale(&"hauler", FactionPerks.CARRY_CAPACITY, 2.0)
	perks.add_scale(&"", FactionPerks.VISION_RANGE, 1.25)
	perks.add_scale(&"", FactionPerks.SCAN_RATE, 2.0)
	perks.lock(&"ranger")
	perks.lock(&"barracks")
	_f.world.perks[0] = perks
	var hauler: Unit = _f.spawn(_f.base.hauler, 0, Vector3(0, 0, 0))
	assert_eq(hauler.carry_capacity, 100)
	assert_almost_eq(hauler.health.max_health, _f.base.hauler.max_health * 1.5, 0.5)
	assert_almost_eq(hauler.vision_range, _f.base.hauler.vision_range * 1.25, 0.01)
	var enemy: Unit = _f.spawn(_f.base.hauler, 1, Vector3(20, 0, 0))
	assert_eq(enemy.carry_capacity, 50, "other factions are untouched")
	var surveyor: Unit = _f.spawn(_f.discovery.surveyor, 0, Vector3(-20, 0, 0))
	assert_almost_eq(surveyor.scan_rate, 2.0, 0.001)
	var barracks: Building = _f.world.spawn_building(_f.base.barracks, 0, Vector3(30, 0, 30), true)
	assert_false(barracks.producer.options.has(_f.base.ranger), "locked units are not offered")
	assert_eq(barracks.producer.check(_f.base.ranger), Producer.NOT_PRODUCIBLE)
	var place: PlaceBuildingCommand = PlaceBuildingCommand.new(
		0, [] as Array[Node3D], _f.base.barracks, Vector3(-30, 0, -30)
	)
	place.entities.append(hauler)
	place.execute()
	assert_eq(place.refused, PlaceBuildingCommand.LOCKED, "locked buildings cannot be placed")


func test_field_option_cost_scale_and_charges() -> void:
	var perks: FactionPerks = FactionPerks.new()
	perks.add_scale(&"orbital_scan", FactionPerks.INTEL_COST, 0.5)
	perks.add_scale(&"orbital_scan", FactionPerks.COOLDOWN, 0.5)
	_f.world.perks[0] = perks
	var options: FieldOptions = _f.world.discovery.field_options
	assert_eq(options.cost(0, _f.discovery.orbital_scan), 20)
	assert_almost_eq(options.cooldown(0, _f.discovery.orbital_scan), 30.0, 0.01)
	assert_eq(options.cost(1, _f.discovery.orbital_scan), 40, "only the player's")
	options.add_charges(0, &"supply_drop", 1)
	assert_eq(options.check(0, _f.discovery.supply_drop), FieldOptions.OK, "free with no Intel")
	var flux: int = _f.world.economy.stockpile(0).flux
	assert_eq(options.use(0, _f.discovery.supply_drop, Vector3(40, 0, 40)), FieldOptions.OK)
	assert_eq(_f.world.economy.stockpile(0).flux, flux + 75)
	assert_eq(options.charges(0, _f.discovery.supply_drop), 0, "the charge is spent")
	assert_eq(options.check(0, _f.discovery.supply_drop), FieldOptions.NO_INTEL)
	var restored: FieldOptions = FieldOptions.new(_f.world, 0)
	options.add_charges(0, &"orbital_scan", 2)
	restored.from_dict(options.to_dict())
	assert_eq(restored.charges(0, _f.discovery.orbital_scan), 2, "charges are saved")


func test_the_mission_applies_the_modifiers() -> void:
	var modifiers: LandingModifiers = LandingModifiers.new()
	modifiers.extra_roster = [_f.base.ranger, _f.base.ranger] as Array[UnitDef]
	modifiers.bonus_alloy = 300
	modifiers.bonus_intel = 25
	modifiers.unlocked_options = [&"antecedent_power"] as Array[StringName]
	modifiers.perks.lock(&"ranger")
	_f.def.player_roster = [_f.base.hauler] as Array[UnitDef]
	_f.def.player_start = Vector3(-30, 0, 30)
	var alloy: int = _f.world.economy.stockpile(0).alloy
	_f.mission = Mission.new()
	_f.mission.modifiers = modifiers
	add_child(_f.mission)
	_f.mission.setup(_f.def, _f.base.context, _f.world, MissionFixture.AREA)
	_f.mission.spawn_units()
	assert_eq(_f.world.units_of(0).size(), 3, "the crew and the escort")
	assert_eq(_f.world.economy.stockpile(0).alloy, alloy + 300)
	assert_eq(_f.world.economy.stockpile(0).intel, 25)
	assert_true(_f.world.discovery.field_options.is_unlocked(0, _f.discovery.lance))
	assert_true(FactionPerks.of(_f.world.perks, 0).is_locked(&"ranger"))
