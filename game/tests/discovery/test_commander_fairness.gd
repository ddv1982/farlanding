extends GutTest
## The Combine commander gets nothing from the player's discoveries: reveals go to
## the discovering faction's grid only, and the AI's eyes leave Custodians out.

var _f: DiscoveryFixture


func before_each() -> void:
	_f = DiscoveryFixture.new(self, true)


func after_each() -> void:
	_f.dispose()


func test_player_reveals_never_reach_the_combine_grid() -> void:
	var lab: Building = _f.world.spawn_building(_f.lab, 0, Vector3(-80, 0, 80), true)
	_f.world.spawn_building(_f.combat.hq, 1, Vector3(80, 0, -80), true)
	var player_unit: Unit = _f.spawn(_f.combat.soldier, 0, Vector3(0, 0, 60))
	var spot: Vector3 = Vector3(0, 0, 0)
	_f.world.economy.add_intel(0, 100)
	_f.push(FieldOptionCommand.new(0, lab, _f.orbital_scan, spot))
	var def: DiscoveryDef = _f.discovery(&"relay", DiscoveryDef.ENEMY)
	def.payoff = DiscoveryDef.PAYOFF_REVEAL_ENEMY
	_f.world.discovery.resolve(_f.site(def, Vector3(-60, 0, 60)), 0)
	_f.tick(6)
	var grid: VisionGrid = _f.world.vision.grid
	assert_true(grid.is_visible(0, spot), "the player sees the scanned area")
	assert_false(grid.is_visible(1, spot), "the Combine does not")
	assert_false(grid.is_visible(1, player_unit.sim_position()))
	assert_false(grid.is_explored(1, spot))
	assert_eq(_f.world.vision.reveal_count(1), 0)
	assert_eq(_f.pile(1).intel, 0)


func test_a_deposit_found_by_the_player_is_not_known_to_the_combine() -> void:
	var def: DiscoveryDef = _f.discovery(&"seam", DiscoveryDef.GEOLOGICAL)
	def.payoff = DiscoveryDef.PAYOFF_DEPOSIT
	def.payoff_node = _f.rich
	_f.spawn(_f.surveyor, 0, Vector3(-60, 0, 55))
	_f.world.spawn_building(_f.combat.hq, 1, Vector3(80, 0, -80), true)
	_f.world.discovery.resolve(_f.site(def, Vector3(-60, 0, 60)), 0)
	_f.tick(4)
	var node: ResourceNode = _f.world.resource_nodes.back()
	assert_true(_f.world.vision.grid.is_area_explored(0, node.blocked_area()))
	assert_false(
		_f.world.vision.grid.is_area_explored(1, node.blocked_area()),
		"the Combine must find it by sight like any deposit"
	)


func test_the_ai_port_does_not_report_custodians() -> void:
	_f.spawn(_f.combat.soldier, 1, Vector3(0, 0, 0))
	var warden: Unit = _f.spawn(_f.warden, Factions.CUSTODIANS, Vector3(6, 0, 0))
	var player_unit: Unit = _f.spawn(_f.combat.scout, 0, Vector3(-6, 0, 0))
	_f.tick(4)
	var port: WorldAiPort = WorldAiPort.new(_f.base.context, _f.world, 1)
	var seen: Array[Node3D] = port.seen_enemies(Vector3.ZERO, 20.0)
	assert_true(seen.has(player_unit))
	assert_false(seen.has(warden))
	assert_true(_f.world.combat.seen_enemies_near(1, Vector3.ZERO, 20.0).has(warden))
