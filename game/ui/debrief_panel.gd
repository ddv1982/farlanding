class_name DebriefPanel
extends CenterContainer
## The debrief after a mission: won or lost, every known objective's result (in
## words as well as colour), the difficulty, the time taken, Intel earned and
## losses, then Retry or Back to missions. On a short window the objectives and the
## report scroll; the verdict and the buttons stay in view.

signal retry_pressed
signal back_pressed

## Space kept free above and below the panel, px.
const SCREEN_MARGIN: float = 24.0

var _title: Label
var _mission: Label
var _objectives: VBoxContainer
var _stats: GridContainer
var _back: Button
var _retry: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel: PanelContainer = HudStyle.make_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var column := FitColumn.new(10)
	column.custom_minimum_size = Vector2(460, 0)
	column.outer_margin = (
		SCREEN_MARGIN * 2 + panel.get_theme_stylebox(&"panel").get_minimum_size().y
	)
	panel.add_child(column)
	_title = HudStyle.make_label(40, HudStyle.TEXT_COLOR)
	column.add_child(_title)
	_mission = HudStyle.make_label(13, HudStyle.MUTED_COLOR)
	column.add_child(_mission)
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 10)
	column.add_scroll(body)
	body.add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, "OBJECTIVES"))
	_objectives = VBoxContainer.new()
	_objectives.add_theme_constant_override(&"separation", 3)
	body.add_child(_objectives)
	body.add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, "REPORT"))
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override(&"h_separation", 24)
	body.add_child(_stats)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 10)
	column.add_child(buttons)
	_back = HudStyle.make_small_button("BACK TO MISSIONS")
	_back.custom_minimum_size = Vector2(170, 38)
	_back.pressed.connect(_on_back)
	buttons.add_child(_back)
	_retry = HudStyle.make_small_button("RETRY")
	_retry.custom_minimum_size = Vector2(120, 38)
	_retry.add_theme_color_override(&"font_color", HudStyle.ACCENT_COLOR)
	_retry.pressed.connect(_on_retry)
	buttons.add_child(_retry)


## Shows `result`. In a campaign (`banked` >= 0, the Intel the landing banked) Back
## returns to the star map, and a won landing cannot be retried.
func show_result(result: MissionResult, banked: int = -1, final: bool = false) -> void:
	var in_campaign: bool = banked >= 0
	_back.text = "BACK TO STAR MAP" if in_campaign else "BACK TO MISSIONS"
	if final:
		# The campaign's last landing was won: Back goes to the ending (ADR 0017).
		_back.text = "THE END OF THE TRAIL"
	_retry.visible = not (in_campaign and result.won)
	Events.ui_feedback.emit(&"debrief_open")
	_title.text = "Mission accomplished" if result.won else "Mission failed"
	_title.add_theme_color_override(
		&"font_color", HudStyle.ACCENT_COLOR if result.won else HudStyle.WARNING_COLOR
	)
	_mission.text = result.title
	for child: Node in _objectives.get_children():
		child.queue_free()
	for entry: Dictionary in result.objectives:
		var title: String = entry["title"]
		var kind: StringName = entry["kind"]
		var state: StringName = entry["state"]
		_objectives.add_child(_objective_line(title, kind, state))
	for child: Node in _stats.get_children():
		child.queue_free()
	if result.difficulty != &"":
		_stat("Difficulty", Difficulty.label(result.difficulty))
	_stat("Time", MissionResult.clock_text(result.seconds))
	_stat("Intel earned", str(result.intel_earned))
	if in_campaign:
		_stat("Intel banked", str(banked))
	_stat("Units lost", str(result.units_lost))
	_stat("Structures lost", str(result.buildings_lost))
	_stat("Enemies destroyed", str(result.enemies_destroyed))


static func _objective_line(title: String, kind: StringName, state: StringName) -> Label:
	var verdict: String = "not achieved"
	var color: Color = HudStyle.MUTED_COLOR
	if state == Objective.STATE_DONE:
		verdict = "done"
		color = ObjectivesPanel.DONE_COLOR
	elif state == Objective.STATE_FAILED:
		verdict = "failed"
		color = ObjectivesPanel.FAILED_COLOR
	var tag: String = ""
	if kind == Objective.KIND_SECONDARY:
		tag = "  (optional)"
	elif kind == Objective.KIND_HIDDEN:
		tag = "  (hidden)"
	return HudStyle.make_label(14, color, "·  %s%s  —  %s" % [title, tag, verdict])


func _stat(caption: String, value: String) -> void:
	_stats.add_child(HudStyle.make_label(13, HudStyle.MUTED_COLOR, caption))
	_stats.add_child(HudStyle.make_label(13, HudStyle.TEXT_COLOR, value))


func _on_retry() -> void:
	Events.ui_feedback.emit(&"click")
	retry_pressed.emit()


func _on_back() -> void:
	Events.ui_feedback.emit(&"click")
	back_pressed.emit()
