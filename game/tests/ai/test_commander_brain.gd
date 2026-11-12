extends GutTest
## The brain: the opening follows the data, it never asks for more than it can pay,
## waves follow the difficulty (including its mistakes), and factories pause at the
## army cap.

var _f: AiFixture
var _hub: Building
var _forge: Building


func before_each() -> void:
	_f = AiFixture.new(self)
	_hub = _f.building(_f.hub, Vector3(0, 0, 0))
	_forge = _f.building(_f.forge, Vector3(20, 0, 0))


func after_each() -> void:
	_f.dispose()


func _kinds(actions: Array[AiAction]) -> Array[String]:
	var names: Array[String] = []
	for action: AiAction in actions:
		names.append("%s:%s" % [action.kind, action.def.id if action.def != null else &""])
	return names


func test_the_opening_follows_the_data_in_order() -> void:
	_f.profile.opening = [_f.harvester, _f.soldier, _f.tower, _f.harvester]
	var brain: CommanderBrain = _f.brain()
	var view: CommanderView = _f.base_view(1000, _hub, _forge)
	var rigger: Unit = _f.unit(_f.builder, Vector3(5, 0, 8))
	view.builders = [rigger]
	view.idle_builders = [rigger]
	var actions: Array[AiAction] = brain.decide(view)
	assert_eq(
		_kinds(actions),
		(
			["produce:harvester", "produce:soldier", "build:tower", "produce:harvester"]
			as Array[String]
		)
	)
	assert_eq(actions[0].building, _hub, "harvesters come from the hub")
	assert_eq(actions[1].building, _forge, "soldiers come from the forge")
	assert_eq(actions[2].units, [rigger] as Array[Unit])
	assert_eq(brain.memory.opening_index, 4)


func test_the_opening_waits_for_money_and_then_carries_on() -> void:
	_f.profile.opening = [_f.harvester, _f.tank, _f.soldier]
	var brain: CommanderBrain = _f.brain()
	var actions: Array[AiAction] = brain.decide(_f.base_view(150, _hub, _forge))
	assert_eq(_kinds(actions), ["produce:harvester"] as Array[String], "the tank must wait")
	assert_eq(brain.memory.opening_index, 1)
	actions = brain.decide(_f.base_view(150, _hub, _forge))
	assert_eq(actions.size(), 0, "still not enough for the tank; the soldier waits behind it")
	actions = brain.decide(_f.base_view(260, _hub, _forge))
	assert_eq(_kinds(actions), ["produce:tank", "produce:soldier"] as Array[String])


func test_an_opening_step_nothing_can_make_is_skipped() -> void:
	var orphan: UnitDef = UnitDef.new()
	orphan.id = &"orphan"
	_f.profile.opening = [orphan, _f.soldier]
	var brain: CommanderBrain = _f.brain()
	var actions: Array[AiAction] = brain.decide(_f.base_view(500, _hub, _forge))
	assert_eq(_kinds(actions), ["produce:soldier"] as Array[String])


func test_never_asks_for_more_than_it_can_pay() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var rigger: Unit = _f.unit(_f.builder, Vector3(5, 0, 8))
	var guards: Array[Unit] = _f.soldiers(12, Vector3(0, 0, 30))
	for trial: int in 300:
		var opening: Array[EntityDef] = []
		if trial % 3 == 0:
			opening = [_f.harvester, _f.tower, _f.tank]
		_f.profile.opening = opening
		var brain: CommanderBrain = _f.brain()
		var view: CommanderView = _f.base_view(rng.randi_range(0, 900), _hub, _forge)
		view.tick = rng.randi_range(0, 6000)
		view.deposits_near_home = rng.randi_range(0, 4)
		view.unit_counts = {_f.harvester.id: rng.randi_range(0, 8)}
		view.building_counts[_f.forge.id] = rng.randi_range(0, 3)
		view.building_counts[_f.tower.id] = rng.randi_range(0, 3)
		view.builders = [rigger]
		if rng.randf() < 0.5:
			view.idle_builders = [rigger]
		view.guards = guards.slice(0, rng.randi_range(0, guards.size()))
		view.has_target = rng.randf() < 0.5
		view.threat_strength = 400.0 if rng.randf() < 0.2 else 0.0
		var alloy: int = view.alloy
		var spent: int = 0
		for action: AiAction in brain.decide(view):
			assert_true(action.cost_alloy >= 0)
			spent += action.cost_alloy
		assert_true(spent <= alloy, "trial %d spent %d of %d" % [trial, spent, alloy])


func test_waves_follow_the_difficulty() -> void:
	var memory: CommanderMemory = CommanderMemory.new()
	var brain: CommanderBrain = _f.brain(memory)
	var view: CommanderView = _f.base_view(0, _hub, _forge)
	view.tick = CommanderDifficulty.ticks(120.0)
	view.has_target = true
	view.attack_target = Vector3(-80, 0, 80)
	view.unit_counts = {_f.harvester.id: 4, _f.builder.id: 1}
	view.building_counts[_f.forge.id] = 3
	view.explored_share = 1.0
	# Home guard 2 + first wave 4: five soldiers are one short.
	view.guards = _f.soldiers(5, Vector3(0, 0, 30))
	assert_eq(_attacks(brain.decide(view)), 0)
	view.guards = _f.soldiers(6, Vector3(0, 0, 30))
	var actions: Array[AiAction] = brain.decide(view)
	assert_eq(_attacks(actions), 1)
	assert_eq(_attack(actions).units.size(), 4, "the home guard stays")
	assert_eq(_attack(actions).position, view.attack_target)
	assert_eq(memory.waves_launched, 1)
	assert_eq(_f.difficulty.wave_size(1), 6, "the next wave is bigger")


func test_a_wave_takes_at_most_half_again_its_size() -> void:
	var brain: CommanderBrain = _f.brain()
	var view: CommanderView = _f.base_view(0, _hub, _forge)
	view.tick = CommanderDifficulty.ticks(120.0)
	view.has_target = true
	view.unit_counts = {_f.harvester.id: 4, _f.builder.id: 1}
	view.guards = _f.soldiers(20, Vector3(0, 0, 30))
	var actions: Array[AiAction] = brain.decide(view)
	assert_eq(_attack(actions).units.size(), 6, "planned 4, at most 6; the rest guard home")


func test_a_mistake_sends_a_wave_too_early() -> void:
	_f.difficulty.mistake_chance = 1.0
	_f.difficulty.early_wave_share = 0.5
	var brain: CommanderBrain = _f.brain()
	var view: CommanderView = _f.base_view(0, _hub, _forge)
	view.tick = CommanderDifficulty.ticks(120.0)
	view.has_target = true
	view.unit_counts = {_f.harvester.id: 4, _f.builder.id: 1}
	view.guards = _f.soldiers(4, Vector3(0, 0, 30))
	var actions: Array[AiAction] = brain.decide(view)
	assert_eq(_attacks(actions), 1, "two of the planned four leave")
	assert_eq(_attack(actions).units.size(), 2)


func test_factories_pause_at_the_army_cap_unless_attacked() -> void:
	var brain: CommanderBrain = _f.brain()
	var view: CommanderView = _f.base_view(2000, _hub, _forge)
	view.unit_counts = {_f.harvester.id: 4, _f.builder.id: 1}
	view.guards = _f.soldiers(brain.army_cap(), Vector3(0, 0, 30))
	assert_eq(_produced_at(brain.decide(view), _forge), 0)
	view = _f.base_view(2000, _hub, _forge)
	view.unit_counts = {_f.harvester.id: 4, _f.builder.id: 1}
	view.guards = _f.soldiers(brain.army_cap(), Vector3(0, 0, 30))
	view.threat_strength = 300.0
	view.threat_position = Vector3(5, 0, 5)
	assert_gt(_produced_at(brain.decide(view), _forge), 0)


func test_without_production_the_army_makes_a_last_stand_once() -> void:
	var brain: CommanderBrain = _f.brain()
	var view: CommanderView = CommanderView.new()
	view.guards = _f.soldiers(3, Vector3(0, 0, 30))
	var actions: Array[AiAction] = brain.decide(view)
	assert_eq(_attacks(actions), 1)
	assert_eq(_attack(actions).reason, &"last_stand")
	view.attack_active = true
	assert_eq(brain.decide(view).size(), 0, "nothing more to do: no spam")


func test_difficulty_data_changes_the_numbers() -> void:
	var data: CommanderProfile = load("res://data/ai/combine_commander.tres")
	var easy: CommanderDifficulty = data.difficulty(&"easy")
	var normal: CommanderDifficulty = data.difficulty(&"normal")
	var hard: CommanderDifficulty = data.difficulty(&"hard")
	assert_eq(data.difficulty(&"unknown"), normal, "normal by default")
	assert_gt(easy.decision_interval_ticks, normal.decision_interval_ticks)
	assert_gt(normal.decision_interval_ticks, hard.decision_interval_ticks)
	assert_gt(easy.first_attack_seconds, normal.first_attack_seconds)
	assert_gt(normal.first_attack_seconds, hard.first_attack_seconds)
	assert_lt(easy.wave_size(0), normal.wave_size(0))
	assert_lt(normal.wave_size(0), hard.wave_size(0))
	assert_lt(easy.wave_size(3), hard.wave_size(3))
	assert_gt(easy.mistake_chance, normal.mistake_chance)
	assert_eq(hard.mistake_chance, 0.0)
	assert_eq(normal.wave_size(100), normal.max_wave_size, "waves stop growing at the cap")


func _attacks(actions: Array[AiAction]) -> int:
	var count: int = 0
	for action: AiAction in actions:
		if action.kind == AiAction.ATTACK:
			count += 1
	return count


func _attack(actions: Array[AiAction]) -> AiAction:
	for action: AiAction in actions:
		if action.kind == AiAction.ATTACK:
			return action
	return null


func _produced_at(actions: Array[AiAction], building: Building) -> int:
	var count: int = 0
	for action: AiAction in actions:
		if action.kind == AiAction.PRODUCE and action.building == building:
			count += 1
	return count
