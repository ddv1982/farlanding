extends GutTest
## The enemy commander reads the tide (public, like the weather; ADR 0014): a
## "wait" commander sends no wave while the shallows may flood before it is across;
## any group crossing the deep channel while they are unsafe walks through the map's
## dry crossing (the causeway). A retrieval squad takes an artefact home.

var _f: AiFixture
var _hub: Building
var _forge: Building


func before_each() -> void:
	_f = AiFixture.new(self)
	_hub = _f.building(_f.hub, Vector3(0, 0, 0))
	_forge = _f.building(_f.forge, Vector3(20, 0, 0))


func after_each() -> void:
	_f.dispose()


## A base ready to send its first wave (home guard 2 + wave 4).
func _ready_view(guards: int) -> CommanderView:
	var view: CommanderView = _f.base_view(0, _hub, _forge)
	view.tick = CommanderDifficulty.ticks(120.0)
	view.has_target = true
	view.attack_target = Vector3(-80, 0, 80)
	view.unit_counts = {_f.harvester.id: 4, _f.builder.id: 1}
	view.building_counts[_f.forge.id] = 3
	view.explored_share = 1.0
	view.guards = _f.soldiers(guards, Vector3(0, 0, 30))
	return view


func _attack(actions: Array[AiAction]) -> AiAction:
	for action: AiAction in actions:
		if action.kind == AiAction.ATTACK:
			return action
	return null


func test_a_waiting_commander_sends_no_wave_into_shallows_that_will_flood() -> void:
	_f.profile.tide_tactic = "wait"
	_f.profile.tide_safe_seconds = 70.0
	var view: CommanderView = _ready_view(6)
	view.shallows_close_seconds = 30.0
	assert_null(_attack(_f.brain().decide(view)), "the ford closes before it is across")
	view = _ready_view(6)
	view.tide_level = 0.4
	view.shallows_close_seconds = 0.0
	assert_null(_attack(_f.brain().decide(view)), "nor while the sea is up")
	view = _ready_view(6)
	view.shallows_close_seconds = 200.0
	assert_not_null(_attack(_f.brain().decide(view)), "low water with time to spare: it goes")
	view = _ready_view(6)
	assert_not_null(_attack(_f.brain().decide(view)), "no sea: nothing to wait for")


func test_a_causeway_commander_sends_its_wave_anyway() -> void:
	_f.profile.tide_tactic = "causeway"
	var view: CommanderView = _ready_view(6)
	view.shallows_close_seconds = 10.0
	assert_not_null(_attack(_f.brain().decide(view)), "it routes the wave instead")


func test_a_group_takes_the_causeway_while_the_shallows_are_unsafe() -> void:
	var port: TidePort = TidePort.new()
	port.crossing = Vector3(0, 0, 12)
	var group: AiGroup = AiGroup.new(port, _f.profile, _f.soldiers(3, Vector3(-30, 0, 0)))
	port.close_seconds = 30.0
	group.order_move(Vector3(40, 0, 0))
	assert_eq(port.pushed.size(), 2, "via the causeway, then on")
	assert_eq(port.pushed[0].target_position, Vector3(0, 0, 12))
	assert_false(port.pushed[0].queued)
	assert_eq(port.pushed[1].target_position, Vector3(40, 0, 0))
	assert_true(port.pushed[1].queued)
	port.pushed.clear()
	port.close_seconds = 200.0
	group.order_move(Vector3(40, 0, 0))
	assert_eq(port.pushed.size(), 1, "safe: the short way")
	port.pushed.clear()
	port.close_seconds = 0.0
	port.level = 1.0
	port.crossing = Vector3.INF
	group.order_move(Vector3(40, 0, 0))
	assert_eq(port.pushed.size(), 1, "no channel in the way: straight there")


func test_the_world_port_finds_the_causeway_over_the_deep_channel() -> void:
	var world: SimWorld = _f.world
	world.heights = _channel_field()
	world.dry_crossings = PackedVector3Array([Vector3(0, 0, 12)])
	world.conditions.sea_level = -1.0
	world.conditions.low_water = -1.0
	world.conditions.high_water = 0.2
	world.conditions.tide_level = 0.3
	world.conditions.shallows_close_seconds = 0.0
	var port: WorldAiPort = WorldAiPort.new(_f.combat.base.context, world, AiFixture.AI)
	assert_eq(port.dry_crossing(Vector3(-20, 0, 0), Vector3(20, 0, 0)), Vector3(0, 0, 12))
	assert_eq(
		port.dry_crossing(Vector3(-20, 0, 0), Vector3(-20, 0, 30)),
		Vector3.INF,
		"the same side: no crossing needed"
	)
	assert_almost_eq(port.tide_level(), 0.3, 0.001, "the tide is public")
	assert_eq(port.shallows_close_seconds(), 0.0)


func test_a_retrieval_squad_takes_the_artefact_home() -> void:
	var def: PropDef = PropDef.new()
	def.id = &"artefact"
	def.size = Vector3(1.3, 1.0, 1.3)
	def.blocks_movement = false
	def.blocks_sight = false
	def.carriable = true
	var prop: Prop = _f.world.spawn_prop(def, Vector3(-30, 0, 20))
	var port: WorldAiPort = WorldAiPort.new(_f.combat.base.context, _f.world, AiFixture.AI)
	assert_true(port.known_cargo().has(prop), "a lying artefact is known")
	var squad: Array[Unit] = _f.soldiers(3, Vector3(-10, 0, 20))
	var group: RetrieveGroup = RetrieveGroup.new(port, _f.profile, squad, prop)
	group.home = Vector3(30, 0, -20)
	group.start()
	var lifted: bool = false
	for i: int in 900:
		_f.tick()
		group.tick(port.now())
		lifted = lifted or prop.carrier_faction() == AiFixture.AI
	assert_true(lifted, "a member lifted it")
	assert_eq(group.state(), RetrieveGroup.BRING)
	var at: Vector3 = prop.sim_position()
	assert_lt(Vector2(at.x - 30.0, at.z + 20.0).length(), RetrieveGroup.HOME_RADIUS + 1.0, "home")
	var saved: Dictionary = group.to_dict()
	var cargo_id: int = saved["cargo"]
	assert_eq(cargo_id, prop.entity_id, "the squad saves what it is after")


## Flats at +1 m with a deep channel (-3 m) across x = -5..5, except a causeway at
## z = 10..14.
static func _channel_field() -> HeightField:
	var columns: int = 81
	var rows: int = 61
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(columns * rows)
	for row: int in rows:
		for column: int in columns:
			var x: float = -40.0 + column
			var z: float = -30.0 + row
			var deep: bool = absf(x) <= 5.0 and not (z >= 10.0 and z <= 14.0)
			heights[row * columns + column] = -3.0 if deep else 1.0
	return HeightField.new(Vector2(-40.0, -30.0), 1.0, columns, rows, heights)


## A FakePort that also reports a tide and a dry crossing.
class TidePort:
	extends AiFixture.FakePort

	var level: float = 0.0
	var close_seconds: float = INF
	var crossing: Vector3 = Vector3.INF

	func tide_level() -> float:
		return level

	func shallows_close_seconds() -> float:
		return close_seconds

	func dry_crossing(_from: Vector3, _to: Vector3) -> Vector3:
		return crossing
