extends GutTest
## The commander's building-site search uses only what its faction may know: its own
## buildings, enemy buildings it has seen, and sites the real placement rules refused.
## An unseen enemy building does not steer it; a refused site is not tried again.

const FAR: Vector3 = Vector3(60, 0, -60)

var _f: AiFixture
var _commander: Commander


func before_each() -> void:
	_f = AiFixture.new(self)
	_f.world.enable_vision(Rect2(-120, -120, 240, 240), 2.0)


func after_each() -> void:
	if is_instance_valid(_commander):
		_commander.free()
	_f.dispose()


## A commander with a Hub at the origin, which sees about 14 m: FAR is out of sight.
## It does not decide on its own here; the tests drive it.
func _start_commander() -> void:
	var hub: Building = _f.building(_f.hub, Vector3.ZERO)
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
	_f.combat.base.context.sim_clock.ticked.disconnect(_commander._on_ticked)
	_commander.home = hub.position
	_commander.staging = Vector3(0, 0, 30)


## Runs both factions' vision updates, then lets the commander look.
func _look() -> void:
	_f.tick(2)
	_commander.perceive(_f.combat.base.context.sim_clock.get_tick())


func _overlaps(spot: Vector3, building: Building) -> bool:
	return _f.forge.world_footprint(spot).grow(1.0).intersects(building.footprint())


func test_an_unseen_enemy_building_does_not_change_the_site() -> void:
	_start_commander()
	_look()
	var open_spot: Vector3 = _commander.find_site(_f.forge, FAR)
	assert_ne(open_spot, Vector3.INF)
	_f.building(_f.forge, open_spot, AiFixture.ENEMY)
	_look()
	assert_eq(_commander.knowledge.known_buildings().size(), 0, "the enemy forge is unseen")
	assert_eq(_commander.find_site(_f.forge, FAR), open_spot, "same choice as without the building")


func test_a_seen_enemy_building_is_avoided() -> void:
	_start_commander()
	_look()
	var open_spot: Vector3 = _commander.find_site(_f.forge, FAR)
	var enemy: Building = _f.building(_f.forge, open_spot, AiFixture.ENEMY)
	var eyes: Unit = _f.unit(_f.scout, FAR + Vector3(0, 0, 15))
	_look()
	eyes.free()
	_look()
	assert_eq(_commander.knowledge.known_buildings().size(), 1, "seen, then remembered")
	var spot: Vector3 = _commander.find_site(_f.forge, FAR)
	assert_ne(spot, Vector3.INF)
	assert_false(_overlaps(spot, enemy), "%s clear of the remembered forge" % spot)


func test_a_refused_site_is_not_tried_again() -> void:
	_start_commander()
	_look()
	var open_spot: Vector3 = _commander.find_site(_f.forge, FAR)
	var enemy: Building = _f.building(_f.forge, open_spot, AiFixture.ENEMY)
	_look()
	_f.world.economy.stockpile(AiFixture.AI).alloy = 1000
	var rigger: Unit = _f.unit(_f.builder, Vector3(5, 0, 5))
	var order: AiAction = AiAction.new(AiAction.BUILD, &"test")
	order.def = _f.forge
	order.units = [rigger]
	order.position = FAR
	var placed: Array[PlaceBuildingCommand] = []
	var record: Callable = func(command: Command) -> void:
		if command is PlaceBuildingCommand:
			placed.append(command as PlaceBuildingCommand)
	Events.command_issued.connect(record)
	_commander._place(order, 1)
	_f.tick(1)
	_commander._place(order, 20)
	_f.tick(1)
	Events.command_issued.disconnect(record)
	assert_eq(placed.size(), 2)
	assert_eq(placed[0].target_position, open_spot, "first try: the spot it thought free")
	assert_eq(placed[0].refused, PlacementRules.BLOCKED, "the real rules refused it")
	assert_ne(placed[1].target_position, open_spot, "second try: somewhere else")
	assert_false(_overlaps(placed[1].target_position, enemy), "clear of what refused it")
	assert_not_null(placed[1].placed, "and that one stands")
	assert_eq(_f.world.economy.stockpile(AiFixture.AI).alloy, 1000 - _f.forge.cost_alloy)
