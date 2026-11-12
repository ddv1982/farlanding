extends GutTest
## Stockpile and power maths, and the Economy's announcements and Advisor alerts.

var _economy: Economy
var _def: UnitDef


func before_each() -> void:
	var rules: EconomyRules = EconomyRules.new()
	rules.start_alloy = 300
	rules.start_flux = 40
	rules.low_power_rate = 0.5
	_economy = Economy.new(rules, 0)
	_def = UnitDef.new()
	_def.cost_alloy = 120
	_def.cost_flux = 30


func test_new_stockpile_starts_with_the_rules_resources() -> void:
	var pile: Stockpile = _economy.stockpile(0)
	assert_eq(pile.alloy, 300)
	assert_eq(pile.flux, 40)


func test_spend_takes_all_or_nothing() -> void:
	var pile: Stockpile = Stockpile.new(100, 10)
	assert_true(pile.spend(60, 10))
	assert_eq([pile.alloy, pile.flux], [40, 0])
	assert_false(pile.spend(50, 0), "cannot pay 50 with 40")
	assert_eq([pile.alloy, pile.flux], [40, 0], "nothing taken on failure")


func test_add_never_goes_below_zero() -> void:
	var pile: Stockpile = Stockpile.new(10, 10)
	pile.add(-50, 5)
	assert_eq([pile.alloy, pile.flux], [0, 15])


func test_shortfall_text_names_what_is_missing() -> void:
	var pile: Stockpile = Stockpile.new(100, 0)
	assert_eq(pile.shortfall_text(140, 20), "Need 40 more Alloy and 20 more Flux")
	assert_eq(pile.shortfall_text(100, 0), "")


func test_pay_announces_new_totals() -> void:
	watch_signals(Events)
	assert_true(_economy.pay(0, _def))
	assert_signal_emitted_with_parameters(Events, "resources_changed", [0, 180, 10])


func test_failed_pay_alerts_the_player_only() -> void:
	_def.cost_alloy = 1000
	watch_signals(Events)
	assert_false(_economy.pay(0, _def))
	assert_signal_emitted_with_parameters(Events, "advisor_alert", [&"insufficient_resources"])
	assert_signal_not_emitted(Events, "resources_changed")
	watch_signals(Events)
	assert_false(_economy.pay(1, _def))
	assert_signal_emit_count(Events, "advisor_alert", 1, "no alert for another faction")


func test_refund_returns_a_share() -> void:
	_economy.refund(0, _def, 0.5)
	assert_eq(_economy.stockpile(0).alloy, 360)
	assert_eq(_economy.stockpile(0).flux, 55)


func test_low_power_halves_the_work_rate() -> void:
	_economy.set_power(0, 10, 10)
	assert_eq(_economy.work_rate(0), 1.0, "used == produced is enough")
	_economy.set_power(0, 10, 11)
	assert_eq(_economy.work_rate(0), 0.5)


func test_power_transitions_alert_once_each_way() -> void:
	_economy.set_power(0, 10, 4)
	watch_signals(Events)
	_economy.set_power(0, 10, 11)
	_economy.set_power(0, 10, 12)
	_economy.set_power(0, 25, 12)
	assert_signal_emit_count(Events, "power_changed", 3)
	assert_signal_emit_count(Events, "advisor_alert", 2)
	var first: Array = get_signal_parameters(Events, "advisor_alert", 0)
	var second: Array = get_signal_parameters(Events, "advisor_alert", 1)
	assert_eq(first, [&"low_power"])
	assert_eq(second, [&"power_restored"])


func test_unchanged_power_is_not_announced() -> void:
	_economy.set_power(0, 10, 4)
	watch_signals(Events)
	_economy.set_power(0, 10, 4)
	assert_signal_not_emitted(Events, "power_changed")


func test_other_factions_never_alert() -> void:
	watch_signals(Events)
	_economy.set_power(1, 0, 5)
	assert_signal_emitted(Events, "power_changed")
	assert_signal_not_emitted(Events, "advisor_alert")


func test_round_trip() -> void:
	_economy.pay(0, _def)
	_economy.set_power(0, 25, 8)
	var copy: Economy = Economy.new()
	copy.from_dict(_economy.to_dict())
	var pile: Stockpile = copy.stockpile(0)
	assert_eq([pile.alloy, pile.flux, pile.power_produced, pile.power_used], [180, 10, 25, 8])
