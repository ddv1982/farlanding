extends GutTest

var _f: EconomyFixture
var _controller: SelectionController
var _panel: CommandPanel


func before_each() -> void:
	_f = EconomyFixture.new(self)
	_controller = SelectionController.new()
	_controller.world = _f.world
	add_child(_controller)
	_panel = CommandPanel.new()
	add_child(_panel)
	_panel.setup(_controller, _f.world, 0)


func after_each() -> void:
	_panel.free()
	_controller.free()
	_f.dispose()


func _select(building: Building) -> void:
	_controller.select_building(building)
	_panel._process(0.0)


func _sale() -> Dictionary:
	for entry: Dictionary in _panel._entries:
		if entry.has("sell"):
			return entry
	return {}


func test_sell_requires_inline_confirmation_and_cancel_does_not_issue_order() -> void:
	var building: Building = _f.world.spawn_building(_f.reactor, 0, Vector3.ZERO, true)
	_select(building)
	var entry: Dictionary = _sale()
	assert_false(entry.is_empty())
	var button: Button = entry["button"]
	var cancel: Button = entry["cancel"]
	assert_true(button.text.begins_with("SELL"))
	assert_string_contains(button.text, "+75 Alloy")
	assert_false(cancel.visible)
	button.pressed.emit()
	assert_true(button.text.begins_with("Confirm sell"))
	assert_true(cancel.visible)
	assert_eq(_f.context.command_queue.pending_count(), 0)
	cancel.pressed.emit()
	assert_true(button.text.begins_with("SELL"))
	assert_false(cancel.visible)
	assert_eq(_f.context.command_queue.pending_count(), 0)
	button.pressed.emit()
	button.pressed.emit()
	button.pressed.emit()
	assert_eq(_f.context.command_queue.pending_count(), 1)
	assert_true(button.disabled)
	assert_true(_f.world.buildings.has(building))
	_f.tick()
	assert_null(_controller.selected_building)
	assert_eq(_f.pile().alloy, 1075)


func test_construction_has_full_refund_and_confirmation_resets_with_selection() -> void:
	var site: Building = _f.world.spawn_building(_f.reactor, 0, Vector3.ZERO, false)
	var other: Building = _f.world.spawn_building(_f.barracks, 0, Vector3(30, 0, 0), true)
	_select(site)
	var button: Button = _sale()["button"]
	assert_string_contains(button.text, "+150 Alloy")
	button.pressed.emit()
	_select(other)
	var other_button: Button = _sale()["button"]
	assert_true(other_button.text.begins_with("SELL"))
	other_button.pressed.emit()
	assert_eq(_f.context.command_queue.pending_count(), 0)
	_select(site)
	var reset_button: Button = _sale()["button"]
	assert_true(reset_button.text.begins_with("SELL"))


func test_production_commands_remain_and_refund_preview_tracks_queue() -> void:
	var building: Building = _f.world.spawn_building(_f.barracks, 0, Vector3.ZERO, true)
	_select(building)
	assert_eq(_panel._entries.size(), 2, "unit production and SELL both available")
	_panel.fit_width(220.0)
	assert_eq(_panel._scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_lte(_panel._scroll.custom_minimum_size.x, 220.0)
	var sale: Button = _sale()["button"]
	sale.pressed.emit()
	_f.push(ProduceCommand.new(0, building, _f.ranger))
	_f.tick()
	_panel._process(0.0)
	assert_string_contains(sale.text, "+175 Alloy")
	sale.pressed.emit()
	_f.tick()
	assert_eq(_f.pile().alloy, 1100)


func test_protected_building_has_no_sell_action() -> void:
	var lander: Building = _f.world.spawn_building(_f.lander, 0, Vector3.ZERO, true)
	_select(lander)
	assert_true(_sale().is_empty())
	assert_eq(_panel._entries.size(), 2, "Lander keeps its production commands")


func test_field_and_vent_commands_coexist_with_sell() -> void:
	var option := FieldOptionDef.new()
	option.id = &"test_scan"
	option.display_name = "Scan"
	_f.barracks.field_options = [option]
	var lab: Building = _f.world.spawn_building(_f.barracks, 0, Vector3(30, 0, 0), true)
	_select(lab)
	assert_eq(_panel._entries.size(), 3, "production, field option and SELL")
	_f.vent.erupts = true
	_f.world.spawn_resource_node(_f.vent, Vector3.ZERO)
	var tap: Building = _f.world.spawn_building(_f.tap, 0, Vector3.ZERO, true)
	var rule := EruptionRule.new()
	rule.system = EruptionSystem
	PlanetRuleSystem.start(_f.world, rule)
	_select(tap)
	assert_eq(_panel._entries.size(), 2, "VENT and SELL")
	var vent_entry: Dictionary = _panel._entries[0]
	assert_true(vent_entry.has("vent"))
	assert_false(_sale().is_empty())
