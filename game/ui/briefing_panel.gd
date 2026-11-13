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
var _carried_title: Label
var _carried: Label
var _back: ColorRect
var _vignette: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back = ColorRect.new()
	_back.color = MissionSelect.BACKGROUND
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette = HudStyle.make_vignette()
	_vignette.visible = false
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_carried_title = HudStyle.make_label(11, HudStyle.MUTED_COLOR, "FROM THE MERIDIAN")
	column.add_child(_carried_title)
	_carried = HudStyle.make_label(13, HudStyle.INTEL_COLOR)
	_carried.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_carried.custom_minimum_size = Vector2(620, 0)
	column.add_child(_carried)
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


## Shows the briefing of `p_mission`; `carried` lists what a campaign landing brings
## along (techs, loadout, earlier finds), one line each.
func show_mission(p_mission: MissionDef, carried: PackedStringArray = []) -> void:
	mission = p_mission
	_carried_title.visible = not carried.is_empty()
	_carried.visible = not carried.is_empty()
	var lines: PackedStringArray = []
	for line: String in carried:
		lines.append("·  " + line)
	_carried.text = "\n".join(lines)
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


## Lets the menu backdrop show through (or not).
func set_see_through(enabled: bool) -> void:
	if _back != null:
		_back.visible = not enabled
		_vignette.visible = enabled
