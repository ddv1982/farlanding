extends GutTest
## Goal scoring: economy first when poor, attack first when strong, scouting while
## nothing is known, defence when the base is attacked.

var _f: AiFixture
var _hub: Building
var _forge: Building


func before_each() -> void:
	_f = AiFixture.new(self)
	_hub = _f.building(_f.hub, Vector3(0, 0, 0))
	_forge = _f.building(_f.forge, Vector3(20, 0, 0))


func after_each() -> void:
	_f.dispose()


func _scores(view: CommanderView) -> Dictionary[StringName, float]:
	return GoalScorer.score_all(view, _f.profile, _f.difficulty, CommanderMemory.new())


func test_picks_economy_when_poor() -> void:
	var view: CommanderView = _f.base_view(40, _hub, _forge)
	view.tick = CommanderDifficulty.ticks(400.0)
	view.deposits_near_home = 3
	view.unit_counts = {_f.harvester.id: 1, _f.builder.id: 1}
	view.guards = _f.soldiers(3, Vector3(0, 0, 30))
	view.has_target = true
	var scores: Dictionary[StringName, float] = _scores(view)
	assert_eq(GoalScorer.best(scores), GoalScorer.ECONOMY, str(scores))
	assert_gt(scores[GoalScorer.ECONOMY], 1.0, "poor and short of harvesters is urgent")


func test_picks_attack_when_strong() -> void:
	var view: CommanderView = _f.base_view(100, _hub, _forge)
	view.tick = CommanderDifficulty.ticks(400.0)
	view.deposits_near_home = 3
	view.unit_counts = {_f.harvester.id: 6, _f.builder.id: 1}
	view.building_counts[_f.forge.id] = 3
	view.guards = _f.soldiers(14, Vector3(0, 0, 30))
	view.has_target = true
	view.explored_share = 0.9
	var scores: Dictionary[StringName, float] = _scores(view)
	assert_eq(GoalScorer.best(scores), GoalScorer.ATTACK, str(scores))


func test_no_attack_without_a_seen_target() -> void:
	var view: CommanderView = _f.base_view(100, _hub, _forge)
	view.tick = CommanderDifficulty.ticks(400.0)
	view.guards = _f.soldiers(14, Vector3(0, 0, 30))
	view.has_target = false
	var scores: Dictionary[StringName, float] = _scores(view)
	assert_eq(scores[GoalScorer.ATTACK], 0.0)
	assert_gt(scores[GoalScorer.SCOUT], 0.0, "it goes looking instead")


func test_no_attack_before_the_first_attack_time() -> void:
	var view: CommanderView = _f.base_view(100, _hub, _forge)
	view.tick = CommanderDifficulty.ticks(_f.difficulty.first_attack_seconds - 1.0)
	view.guards = _f.soldiers(14, Vector3(0, 0, 30))
	view.has_target = true
	assert_eq(_scores(view)[GoalScorer.ATTACK], 0.0)


func test_picks_defence_when_the_base_is_attacked() -> void:
	var view: CommanderView = _f.base_view(300, _hub, _forge)
	view.tick = CommanderDifficulty.ticks(400.0)
	view.deposits_near_home = 1
	view.unit_counts = {_f.harvester.id: 2, _f.builder.id: 1}
	view.guards = _f.soldiers(2, Vector3(0, 0, 30))
	view.guard_strength = 100.0
	view.threat_strength = 600.0
	view.threat_position = Vector3(10, 0, 10)
	var scores: Dictionary[StringName, float] = _scores(view)
	assert_eq(GoalScorer.best(scores), GoalScorer.DEFENCE, str(scores))


func test_a_missing_factory_is_the_most_urgent_economy_step() -> void:
	var view: CommanderView = _f.base_view(300, _hub, _forge)
	view.building_counts[_f.forge.id] = 0
	view.unit_counts = {_f.harvester.id: 4, _f.builder.id: 1}
	view.builders = [_f.unit(_f.builder, Vector3(5, 0, 5))]
	assert_almost_eq(GoalScorer.economy(view, _f.profile), 1.0, 0.001)
