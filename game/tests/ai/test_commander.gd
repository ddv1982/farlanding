extends GutTest
## The commander on a live (fixture) world: it only gives orders to its own faction
## through the command queue, never spends more than it has, and does not stall or
## spam when broke or when its base is gone.

var _f: AiFixture
var _commander: Commander
var _commands: Array[Command] = []


func before_each() -> void:
	_f = AiFixture.new(self)
	_commands = []
	Events.command_issued.connect(_on_command)


func after_each() -> void:
	Events.command_issued.disconnect(_on_command)
	if is_instance_valid(_commander):
		_commander.free()
	_f.dispose()


func _on_command(command: Command) -> void:
	_commands.append(command)


func _start_commander() -> void:
	_commander = Commander.new()
	add_child(_commander)
	_commander.setup(
		_f.combat.base.context,
		_f.world,
		AiFixture.AI,
		_f.profile,
		&"normal",
		Rect2(-120, -120, 240, 240)
	)


func test_builds_up_through_its_own_commands_and_stays_solvent() -> void:
	_f.profile.opening = [_f.harvester, _f.soldier, _f.soldier]
	_f.world.economy.stockpile(AiFixture.AI).alloy = 400
	_f.building(_f.hub, Vector3(60, 0, 60))
	_f.building(_f.forge, Vector3(40, 0, 60))
	_start_commander()
	for i: int in 600:
		_f.tick()
		assert_true(_f.world.economy.stockpile(AiFixture.AI).alloy >= 0)
	assert_gt(_commands.size(), 0)
	for command: Command in _commands:
		assert_eq(command.issuer_faction, AiFixture.AI, "%s" % command.kind)
	assert_gt(_f.world.units_of(AiFixture.AI).size(), 0, "it produced units")
	assert_gt(_commander.decisions, 0)
	assert_lt(_commander.max_decision_usec, 50000, "a decision stays cheap")


func test_broke_with_no_base_it_does_not_spam() -> void:
	_f.world.economy.stockpile(AiFixture.AI).alloy = 0
	_f.soldiers(2, Vector3(60, 0, 60))
	_f.building(_f.combat.sentry, Vector3(-60, 0, -60), AiFixture.ENEMY)
	_start_commander()
	_f.tick(1200)
	assert_lt(_commands.size(), 40, "two minutes with nothing to build: %d" % _commands.size())


func test_an_unreachable_attack_does_not_spam() -> void:
	var paths: PathService = _f.world.paths
	paths.block_area(Rect2(-200, -10, 400, 20))
	_f.world.economy.stockpile(AiFixture.AI).alloy = 0
	_f.building(_f.hub, Vector3(60, 0, 60))
	_f.soldiers(8, Vector3(55, 0, 40))
	_start_commander()
	_commander.memory.waves_launched = 0
	var target: AiAction = AiAction.new(AiAction.ATTACK, &"attack")
	target.units = _f.world.units_of(AiFixture.AI)
	target.position = Vector3(-60, 0, -60)
	_commander._launch(target)
	_f.tick(1500)
	assert_lt(_commands.size(), 60, "%d commands" % _commands.size())


func test_a_new_building_keeps_its_own_door_and_dock_clear() -> void:
	var hub: Building = _f.building(_f.hub, Vector3(0, 0, 0))
	_f.forge.door = Vector3(0, 0, 6)
	_start_commander()
	_commander.home = hub.position
	_commander.staging = Vector3(0, 0, 30)
	for i: int in 6:
		var spot: Vector3 = _commander.find_site(_f.forge, Vector3(0, 0, -8))
		assert_ne(spot, Vector3.INF)
		var door: Vector2 = Vector2(spot.x + _f.forge.door.x, spot.z + _f.forge.door.z)
		for building: Building in _f.world.buildings:
			assert_false(
				building.footprint().grow(NavmeshPathService.CUT_MARGIN).has_point(door),
				"door %s blocked by %s" % [door, building.name]
			)
		_f.building(_f.forge, spot)


func test_sight_sources_sharing_a_cell_still_cover_both_sight_areas() -> void:
	var sources: Dictionary[Vector2i, Vector4] = {}
	var first: Vector3 = Vector3(0.5, 0, 0.5)
	var second: Vector3 = Vector3(7.5, 0, 7.5)
	Commander._add_source(sources, first, 14.0)
	Commander._add_source(sources, second, 14.0)
	assert_eq(sources.size(), 1, "one query per cell")
	var merged: Vector4 = sources.values()[0]
	var centre: Vector3 = Vector3(merged.x, merged.y, merged.z)
	# The far edge of the second source's sight, directly away from the first.
	var edge: Vector3 = second + (second - first).normalized() * 14.0
	assert_lte(centre.distance_to(edge), merged.w, "the merged query reaches it")


func test_without_fog_a_distant_living_building_is_remembered() -> void:
	# This fixture world has no vision grid, i.e. fog of war is off.
	_f.building(_f.hub, Vector3.ZERO)
	_f.building(_f.forge, Vector3(90, 0, -90), 0)
	_start_commander()
	_f.tick()
	_commander.perceive(1)
	_commander.perceive(2)
	assert_eq(
		_commander.knowledge.known_buildings().size(), 1, "far out of sight range, still known"
	)


func test_a_lost_retrieval_squad_makes_the_next_bigger_and_later() -> void:
	# Found by the balance harness (ADR 0018): squads of the same size were fed one
	# after another into whatever guarded the artefact.
	var def: PropDef = PropDef.new()
	def.id = &"artefact"
	def.size = Vector3(1.3, 1.0, 1.3)
	def.blocks_movement = false
	def.blocks_sight = false
	def.carriable = true
	_f.world.spawn_prop(def, Vector3(0, 0, 0))
	# Power for the guns, and the guns around the artefact.
	_f.building(_f.hub, Vector3(-60, 0, -60), AiFixture.ENEMY)
	for at: Vector3 in [Vector3(6, 0, 4), Vector3(-6, 0, 4), Vector3(0, 0, -6)]:
		_f.building(_f.combat.sentry, at, AiFixture.ENEMY)
	_f.world.economy.stockpile(AiFixture.AI).alloy = 0
	_f.building(_f.hub, Vector3(60, 0, 60))
	_f.soldiers(3, Vector3(50, 0, 50))
	_f.profile.retrieves_cargo = true
	_f.profile.retrieve_squad_size = 2
	_f.profile.retrieve_after_seconds = 0.0
	_start_commander()
	_f.tick(900)
	assert_eq(_commander.retrievals_lost, 1, "the first squad of two fell to the guns")
	assert_eq(_commander.retrieve_squad_size(), 4, "the next one is twice the size")
	_f.tick(900)
	assert_null(_commander.retrieval, "the one soldier left is not sent alone")
	var living: int = 0
	for unit: Unit in _f.world.units_of(AiFixture.AI):
		living += 0 if unit.is_dead else 1
	assert_eq(living, 1, "and lives")
	var saved: Dictionary = _commander.to_dict()
	var lost: int = saved["retrievals_lost"]
	assert_eq(lost, 1, "the losses are saved")
