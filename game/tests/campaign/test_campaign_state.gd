extends GutTest
## CampaignState on the real campaign data: route opening and branching, banking
## Intel, buying techs and their requirements (Antecedent discoveries too), loadout
## limits, and the save round trip with its version check.

const CAMPAIGN: String = "res://data/campaign/kessel_trail.tres"

var _def: CampaignDef
var _state: CampaignState


func before_each() -> void:
	_def = load(CAMPAIGN)
	_state = CampaignState.new(_def)


func _win(node_id: StringName, intel_held: int, found: Array[StringName] = []) -> int:
	return _state.resolve_landing(node_id, true, intel_held, found, 600.0)


func test_the_data_is_consistent() -> void:
	assert_eq(_def.nodes.size(), 11)
	var planets: Dictionary[StringName, bool] = {}
	for route_node: RouteNodeDef in _def.nodes:
		assert_not_null(route_node.mission, "%s has a mission" % route_node.id)
		assert_not_null(route_node.planet, "%s has a planet" % route_node.id)
		planets[route_node.planet.id] = true
		for next: StringName in route_node.leads_to:
			assert_not_null(_def.node(next), "%s leads to a real node" % route_node.id)
	assert_eq(planets.size(), 5, "five planets on the route")
	for route_node: RouteNodeDef in _def.nodes:
		assert_false(route_node.placeholder, "%s is a real landing" % route_node.id)
	assert_true(
		_def.node(&"thalassa_shallows").leads_to.has(&"thalassa_recovery"),
		"Recovery follows Tidewater Landing"
	)
	assert_true(_def.node(&"thalassa_recovery").leads_to.has(&"emberfall_conquest"))
	assert_true(_def.node(&"emberfall_conquest").leads_to.has(&"emberfall_holdout"))
	assert_true(_def.node(&"emberfall_holdout").leads_to.has(&"verdance_conquest"))
	assert_true(_def.node(&"verdance_conquest").leads_to.has(&"verdance_infiltration"))
	assert_true(_def.node(&"verdance_infiltration").leads_to.has(&"hollow_power"))
	assert_true(_def.node(&"hollow_power").leads_to.has(&"hollow_finale"))
	assert_eq(_def.techs.size(), 21, "twelve, and three each for Emberfall, Verdance, Hollow")
	var branches: Dictionary[StringName, bool] = {}
	for tech: TechDef in _def.techs:
		branches[tech.branch] = true
		assert_false(tech.effects.is_empty(), "%s does something" % tech.id)
		for needed: StringName in tech.requires:
			assert_not_null(_def.tech(needed), "%s needs a real tech" % tech.id)
	assert_eq(branches.size(), 3, "three branches")
	for slot: LoadoutSlotDef in _def.loadout_slots:
		assert_true(slot.options[0].requires_tech.is_empty(), "%s defaults freely" % slot.id)


func test_only_the_start_node_is_open_at_first() -> void:
	assert_eq(_state.node_state(&"kessel_proving"), CampaignState.NODE_OPEN)
	for node_id: StringName in [&"kessel_storm", &"kessel_uplink", &"thalassa_shallows"]:
		assert_eq(_state.node_state(node_id), CampaignState.NODE_LOCKED)


func test_winning_opens_the_branch_and_banks_the_stockpile() -> void:
	var banked: int = _win(&"kessel_proving", 140)
	assert_eq(banked, 140)
	assert_eq(_state.intel, 140)
	assert_eq(_state.node_state(&"kessel_proving"), CampaignState.NODE_WON)
	assert_eq(_state.node_state(&"kessel_storm"), CampaignState.NODE_OPEN)
	assert_eq(_state.node_state(&"kessel_uplink"), CampaignState.NODE_OPEN)
	assert_eq(_state.node_state(&"thalassa_shallows"), CampaignState.NODE_LOCKED)


func test_taking_one_side_of_the_branch_closes_the_other() -> void:
	_win(&"kessel_proving", 0)
	_win(&"kessel_uplink", 20)
	assert_eq(_state.node_state(&"kessel_storm"), CampaignState.NODE_CLOSED)
	assert_eq(_state.node_state(&"thalassa_shallows"), CampaignState.NODE_OPEN)
	_win(&"thalassa_shallows", 10)
	assert_eq(_state.node_state(&"kessel_storm"), CampaignState.NODE_CLOSED, "stays closed")


func test_a_lost_landing_banks_nothing_but_keeps_its_finds() -> void:
	var found: Array[StringName] = [&"kessel_trail_beacon"]
	var banked: int = _state.resolve_landing(&"kessel_proving", false, 300, found, 90.0)
	assert_eq(banked, 0)
	assert_eq(_state.intel, 0)
	assert_eq(_state.node_state(&"kessel_proving"), CampaignState.NODE_OPEN, "can be retried")
	assert_true(_state.discoveries.has(&"kessel_trail_beacon"))
	var attempts: int = _state.results[&"kessel_proving"]["attempts"]
	assert_eq(attempts, 1)


func test_a_lost_share_banks_that_fraction() -> void:
	_def = _def.duplicate()
	_def.lost_landing_share = 0.5
	_state = CampaignState.new(_def)
	assert_eq(_state.resolve_landing(&"kessel_proving", false, 101, [], 1.0), 50)


func test_buying_spends_intel_and_needs_the_requirements() -> void:
	assert_eq(_state.tech_state(&"survey_lab"), CampaignState.TECH_AVAILABLE)
	assert_false(_state.buy(&"survey_lab"), "no Intel yet")
	_win(&"kessel_proving", 200)
	assert_eq(_state.tech_state(&"survey_lab"), CampaignState.TECH_AFFORDABLE)
	assert_eq(_state.tech_state(&"deep_scan"), CampaignState.TECH_LOCKED, "needs the lab")
	assert_true(_state.buy(&"survey_lab"))
	assert_eq(_state.intel, 140)
	assert_eq(_state.tech_state(&"survey_lab"), CampaignState.TECH_OWNED)
	assert_false(_state.buy(&"survey_lab"), "once only")
	assert_eq(_state.tech_state(&"deep_scan"), CampaignState.TECH_AFFORDABLE)
	assert_true(_state.affordable_techs().has(&"deep_scan"))


func test_antecedent_techs_need_their_discovery() -> void:
	_state.intel = 1000
	_state.techs.append_array([&"survey_lab", &"deep_scan"] as Array[StringName])
	assert_eq(_state.tech_state(&"antecedent_lens"), CampaignState.TECH_LOCKED)
	assert_false(_state.buy(&"antecedent_lens"))
	_win(&"kessel_proving", 0, [&"kessel_trail_beacon", &"kessel_trail_ruin"] as Array[StringName])
	assert_eq(_state.tech_state(&"antecedent_lens"), CampaignState.TECH_AFFORDABLE)
	assert_true(_state.buy(&"antecedent_lens"))


func test_loadout_options_are_limited_by_tech() -> void:
	assert_eq(_state.loadout_option(&"escort").id, &"escort_none", "the default")
	assert_true(_state.choose_loadout(&"escort", &"escort_rangers"))
	assert_false(_state.choose_loadout(&"escort", &"escort_lancers"), "needs Lancer tech")
	assert_false(_state.choose_loadout(&"escort", &"nothing"), "unknown option")
	assert_eq(_state.loadout_option(&"escort").id, &"escort_rangers")
	_state.techs.append(&"lancer_rails")
	assert_true(_state.choose_loadout(&"escort", &"escort_lancers"))
	_state.techs.clear()
	assert_eq(_state.loadout_option(&"escort").id, &"escort_none", "falls back without the tech")


func test_save_round_trip() -> void:
	_win(&"kessel_proving", 250, [&"kessel_sealed_cache"] as Array[StringName])
	_state.buy(&"lancer_rails")
	_state.choose_loadout(&"escort", &"escort_lancers")
	_state.current_node = &"kessel_storm"
	var data: Dictionary = _state.to_dict()
	var copy: CampaignState = CampaignState.from_dict(data, _def)
	assert_not_null(copy)
	assert_eq(copy.intel, _state.intel)
	assert_eq(copy.techs, _state.techs)
	assert_eq(copy.won, _state.won)
	assert_eq(copy.opened, _state.opened)
	assert_eq(copy.discoveries, _state.discoveries)
	assert_eq(copy.loadout, _state.loadout)
	assert_eq(copy.current_node, &"kessel_storm")
	var banked: int = copy.results[&"kessel_proving"]["intel_banked"]
	assert_eq(banked, 250)
	assert_eq(copy.to_dict(), data, "a second round trip changes nothing")


func test_other_versions_and_campaigns_are_refused() -> void:
	var data: Dictionary = _state.to_dict()
	data["version"] = CampaignState.SAVE_VERSION + 1
	assert_null(CampaignState.from_dict(data, _def), "a newer version")
	data = _state.to_dict()
	data["campaign"] = "another"
	assert_null(CampaignState.from_dict(data, _def), "another campaign")
	assert_null(CampaignState.from_dict({}, _def), "no data")


func test_landing_plan_round_trip() -> void:
	_state.techs.append(&"hauler_racks")
	_state.choose_loadout(&"cargo", &"cargo_flux")
	var plan: LandingPlan = LandingPlan.from_state(_state, &"kessel_proving")
	var copy: LandingPlan = LandingPlan.from_dict(plan.to_dict())
	assert_eq(copy.node_id, &"kessel_proving")
	assert_eq(copy.techs, plan.techs)
	assert_eq(copy.loadout, plan.loadout)
	assert_eq(copy.loadout[&"cargo"], &"cargo_flux")
	assert_null(LandingPlan.from_dict({"version": 99}))
