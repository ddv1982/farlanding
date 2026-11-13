class_name TimerTrigger
extends Trigger
## Fires `seconds` of game time after it was added to the mission (with `repeat`,
## every `seconds`).

var seconds: float = 60.0

var _due_tick: int = 0


func _init(p_seconds: float = 60.0, p_action: Callable = Callable()) -> void:
	seconds = p_seconds
	action = p_action


func start(mission: Mission) -> void:
	_due_tick = mission.now() + CommanderDifficulty.ticks(seconds)


func update(mission: Mission) -> void:
	if (has_fired() and not repeat) or mission.now() < _due_tick:
		return
	fired_count += 1
	if repeat:
		_due_tick = mission.now() + CommanderDifficulty.ticks(seconds)
	if action.is_valid():
		action.call()


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	data["due"] = _due_tick
	return data


func from_dict(data: Dictionary) -> void:
	super(data)
	_due_tick = data.get("due", _due_tick)
