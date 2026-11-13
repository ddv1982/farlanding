class_name BriefingPanel
extends Control
## The briefing before a landing: mission type and title, the briefing text, the
## objectives known at the start (primary first), and Start / Back.

## Start the mission shown.
signal start_pressed(mission: MissionDef)
## Back to the mission list.
signal back_pressed

var mission: MissionDef = null

var _type: Label
var _title: Label
var _text: Label
var _objectives: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = MissionSelect.BACKGROUND
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = HudStyle.make_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	column.custom_minimum_size = Vector2(620, 0)
	panel.add_child(column)
	_type = HudStyle.make_label(11, HudStyle.ACCENT_COLOR)
	column.add_child(_type)
	_title = HudStyle.make_label(30, HudStyle.TEXT_COLOR)
	column.add_child(_title)
	_text = HudStyle.make_label(14, HudStyle.TEXT_COLOR)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(620, 0)
	column.add_child(_text)
	column.add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, "OBJECTIVES"))
	_objectives = VBoxContainer.new()
	_objectives.add_theme_constant_override(&"separation", 4)
	column.add_child(_objectives)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 10)
	column.add_child(buttons)
	var back_button: Button = HudStyle.make_small_button("BACK")
	back_button.custom_minimum_size = Vector2(120, 38)
	back_button.pressed.connect(_on_back)
	buttons.add_child(back_button)
	var start: Button = HudStyle.make_small_button("START LANDING")
	start.custom_minimum_size = Vector2(180, 38)
	start.add_theme_color_override(&"font_color", HudStyle.ACCENT_COLOR)
	start.pressed.connect(_on_start)
	buttons.add_child(start)


## Shows the briefing of `p_mission`.
func show_mission(p_mission: MissionDef) -> void:
	mission = p_mission
	Events.ui_feedback.emit(&"briefing_open")
	_type.text = MissionSelect.type_name(mission)
	_title.text = mission.title
	_text.text = mission.briefing
	for child: Node in _objectives.get_children():
		child.queue_free()
	for kind: StringName in [Objective.KIND_PRIMARY, Objective.KIND_SECONDARY]:
		for objective: ObjectiveDef in mission.starting_objectives():
			if objective.kind == kind:
				_objectives.add_child(_objective_line(objective))


func _objective_line(objective: ObjectiveDef) -> Label:
	var primary: bool = objective.kind == Objective.KIND_PRIMARY
	var text: String = ("%s" if primary else "%s  (optional)") % objective.title
	var color: Color = ObjectivesPanel.PRIMARY_COLOR if primary else ObjectivesPanel.SECONDARY_COLOR
	return HudStyle.make_label(14, color, "·  " + text)


func _on_start() -> void:
	Events.ui_feedback.emit(&"click")
	Events.ui_feedback.emit(&"briefing_close")
	start_pressed.emit(mission)


func _on_back() -> void:
	Events.ui_feedback.emit(&"click")
	Events.ui_feedback.emit(&"briefing_close")
	back_pressed.emit()
