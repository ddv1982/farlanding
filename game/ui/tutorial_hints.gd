class_name TutorialHints
extends Control
## First-time tutorial cards over a mission (ADR 0011): the HintDirector decides what
## is due; this shows one small card at a time below the resource bar (title, text
## with the current mouse buttons filled in, GOT IT). Only the button takes clicks, so
## a card never blocks the map; it also leaves by itself after AUTO_HIDE_SECONDS.
## Showing a hint marks it seen for the profile.

## Seconds a card stays when not dismissed.
const AUTO_HIDE_SECONDS: float = 16.0
const WIDTH: float = 400.0
const HINT_COLOR := Color(0.4, 0.9, 1.0)

var director: HintDirector = HintDirector.new()
## The hint on screen, or null.
var shown: HintDef = null
## True while the mission is paused: no hint comes due and the card's time stands still.
var suspended: bool = false

var _card: PanelContainer
var _title: Label
var _text: Label
var _shown_for: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = HudStyle.make_panel()
	var style: StyleBoxFlat = HudStyle.panel_style()
	style.border_color = HINT_COLOR
	_card.add_theme_stylebox_override(&"panel", style)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.position.y = 64.0
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_theme_constant_override(&"separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var tag: Label = HudStyle.make_label(10, HINT_COLOR, "FIELD NOTE")
	head.add_child(tag)
	_title = HudStyle.make_label(14, HudStyle.TEXT_COLOR)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_title)
	var dismiss: Button = HudStyle.make_small_button("GOT IT")
	dismiss.mouse_filter = Control.MOUSE_FILTER_STOP
	dismiss.pressed.connect(dismiss_card)
	head.add_child(dismiss)
	_text = HudStyle.make_label(12, HudStyle.TEXT_COLOR)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_child(_text)
	_card.visible = false


func _exit_tree() -> void:
	director.dispose()


func setup(catalog: HintCatalog) -> void:
	director.setup(catalog)


## A mission began: its hints may show.
func begin_mission(mission: MissionDef) -> void:
	_hide()
	suspended = false
	director.begin(mission.mission_type if mission != null else &"")


## The mission ended or was left.
func end_mission() -> void:
	director.end()
	_hide()


func _process(delta: float) -> void:
	if not director.active or suspended:
		return
	director.advance(delta)
	if shown != null:
		_shown_for += delta
		if _shown_for >= AUTO_HIDE_SECONDS:
			_hide()
		return
	var due: HintDef = director.next_due()
	if due != null:
		_show(due)


## GOT IT: the card goes.
func dismiss_card() -> void:
	if shown == null:
		return
	_hide()
	Events.ui_feedback.emit(&"hint_dismiss")


## `text` with {command}, {select} and {deselect} filled in for the current mouse
## scheme, and every {key_<action>} with the key bound to it now (KeyBindings).
static func fill(text: String) -> String:
	var classic: bool = Settings.control_scheme == Settings.SCHEME_CLASSIC
	var values: Dictionary = KeyBindings.key_names()
	values["command"] = "Left-click" if classic else "Right-click"
	values["select"] = "Left-click"
	values["deselect"] = "Right-click" if classic else "Left-click empty ground"
	values["pan_keys"] = (
		"%s%s%s%s"
		% [
			KeyBindings.label(&"camera_pan_forward_alt"),
			KeyBindings.label(&"camera_pan_left_alt"),
			KeyBindings.label(&"camera_pan_back_alt"),
			KeyBindings.label(&"camera_pan_right_alt"),
		]
	)
	return text.format(values)


func _show(hint: HintDef) -> void:
	shown = hint
	_shown_for = 0.0
	_title.text = hint.title
	_text.text = fill(hint.text)
	_card.visible = true
	Events.ui_feedback.emit(&"hint_show")


func _hide() -> void:
	shown = null
	if _card != null:
		_card.visible = false
