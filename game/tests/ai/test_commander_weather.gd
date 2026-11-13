extends GutTest
## The commander reacts to dust storms (public weather): a "hold" commander launches
## no wave while one blows or is coming and calls a wave home when one hits; a
## "press" commander sends the next wave as it arrives, under strength. A storm that
## never lifts is not waited out. Surveyor profiles keep units scanning sites.

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


func _has(actions: Array[AiAction], kind: StringName, reason: StringName) -> bool:
	for action: AiAction in actions:
		if action.kind == kind and action.reason == reason:
			return true
	return false


func test_a_hold_commander_waits_out_a_storm() -> void:
	_f.profile.storm_tactic = "hold"
	var view: CommanderView = _ready_view(6)
	view.storm_intensity = 0.8
	assert_null(_attack(_f.brain().decide(view)), "no wave into the storm")
	view = _ready_view(6)
	view.storm_eta_seconds = 10.0
	assert_null(_attack(_f.brain().decide(view)), "nor just before it")
	view = _ready_view(6)
	assert_not_null(_attack(_f.brain().decide(view)), "clear sky: the wave leaves")


func test_a_hold_commander_calls_its_wave_home_when_a_storm_hits() -> void:
	_f.profile.storm_tactic = "hold"
	var memory: CommanderMemory = CommanderMemory.new()
	var brain: CommanderBrain = _f.brain(memory)
	var view: CommanderView = _ready_view(2)
	view.attack_active = true
	view.storm_intensity = 0.3
	assert_false(_has(brain.decide(view), AiAction.RECALL, &"storm"), "a light storm is ridden out")
	view = _ready_view(2)
	view.attack_active = true
	view.storm_intensity = 0.7
	assert_true(_has(brain.decide(view), AiAction.RECALL, &"storm"), "recalled")
	view = _ready_view(2)
	view.attack_active = true
	view.storm_intensity = 0.9
	assert_false(_has(brain.decide(view), AiAction.RECALL, &"storm"), "once per storm")
	view = _ready_view(2)
	brain.decide(view)
	assert_false(memory.storm_recalled, "forgotten when the sky clears")


func test_a_press_commander_attacks_under_strength_as_the_storm_arrives() -> void:
	_f.profile.storm_tactic = "press"
	_f.difficulty.early_wave_share = 0.5
	var view: CommanderView = _ready_view(4)
	assert_null(_attack(_f.brain().decide(view)), "clear: two short of a full wave")
	view = _ready_view(4)
	view.storm_eta_seconds = 5.0
	var attack: AiAction = _attack(_f.brain().decide(view))
	assert_not_null(attack, "the storm is cover: it goes now")
	assert_eq(attack.units.size(), 2, "half the planned wave")


func test_the_storm_that_never_lifts_is_not_waited_out() -> void:
	_f.profile.storm_tactic = "hold"
	var view: CommanderView = _ready_view(6)
	view.storm_intensity = 1.0
	view.storm_is_final = true
	assert_not_null(_attack(_f.brain().decide(view)), "it fights on")


func test_a_surveyor_profile_makes_surveyors_once_the_survey_opens() -> void:
	_f.builder.scan_rate = 0.6
	_f.profile.surveyor = _f.builder
	_f.profile.surveyors_wanted = 2
	_f.profile.max_builders = 1
	var view: CommanderView = _f.base_view(500, _hub, _forge)
	view.unit_counts = {_f.builder.id: 1}
	view.survey_open = false
	var made: bool = false
	for action: AiAction in _f.brain().decide(view):
		made = made or (action.kind == AiAction.PRODUCE and action.reason == &"survey")
	assert_false(made, "not before the survey opens")
	view = _f.base_view(500, _hub, _forge)
	view.unit_counts = {_f.builder.id: 1}
	view.survey_open = true
	var survey_action: AiAction = null
	for action: AiAction in _f.brain().decide(view):
		if action.kind == AiAction.PRODUCE and action.reason == &"survey":
			survey_action = action
	assert_not_null(survey_action, "another surveyor is made")
	assert_eq(survey_action.building, _hub, "at the producer that makes it")
