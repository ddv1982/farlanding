class_name Hud
extends CanvasLayer
## In-mission HUD: a selection panel with one chip per unit type, a controls
## panel (F1) and a debug overlay (F3). Built in code from one small set of
## styles so every panel reads as the same survey-instrument family.

const HINT: String = (
	"SELECT   LMB click or drag  ·  Shift add  ·  double-click same type\n"
	+ "GROUPS   Ctrl+1-9 store  ·  1-9 recall  ·  press twice to centre\n"
	+ "ORDERS   RMB move  ·  Shift queue  ·  A then LMB attack-move  ·  S stop\n"
	+ "CAMERA   arrows, screen edge or MMB drag  ·  wheel zoom  ·  Q/E rotate\n"
	+ "         WASD pans when nothing is selected"
)
const PANEL_COLOR := Color(0.055, 0.07, 0.09, 0.84)
const ACCENT_COLOR := Color(0.93, 0.36, 0.05)
const TEXT_COLOR := Color(0.90, 0.92, 0.94)
const MUTED_COLOR := Color(0.62, 0.68, 0.74)
const MARGIN := 14
const ICON_SIZE := 52

## Optional: shows the last sim-tick cost in the debug overlay.
@export var world: SimWorld

var _selection_panel: PanelContainer
var _selection_title: Label
var _chips: HBoxContainer
var _hint_panel: PanelContainer
var _hint_toggle: Label
var _debug_panel: PanelContainer
var _debug: Label
var _tick: int = 0


func _ready() -> void:
	_build_selection_panel()
	_build_hint()
	_build_debug()
	Events.selection_changed.connect(_on_selection_changed)
	Events.sim_ticked.connect(func(tick: int) -> void: _tick = tick)
	_on_selection_changed([])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		_debug_panel.visible = not _debug_panel.visible
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F1:
		_hint_panel.visible = not _hint_panel.visible
		_hint_toggle.visible = not _hint_panel.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _debug_panel.visible:
		return
	var lines: PackedStringArray = [
		"FPS %d  (frame %.1f ms)" % [Engine.get_frames_per_second(), _frame_ms()],
		"Units %d" % get_tree().get_nodes_in_group(Unit.GROUP).size(),
		"Sim tick %d" % _tick,
	]
	if world != null:
		lines.append("Sim tick cost %.2f ms" % (world.last_tick_usec / 1000.0))
	_debug.text = "\n".join(lines)


## Summary text for a selection, e.g. "3 selected: 2 Ranger, 1 Bulwark".
static func summarize(entities: Array[Node3D]) -> String:
	if entities.is_empty():
		return "Nothing selected"
	var parts: PackedStringArray = []
	for group: Dictionary in group_by_type(entities):
		parts.append("%d %s" % [group["count"], group["name"]])
	return "%d selected: %s" % [entities.size(), ", ".join(parts)]


## One entry per unit type in first-seen order: { name, count, icon }.
static func group_by_type(entities: Array[Node3D]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var index_by_name: Dictionary[String, int] = {}
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		var type_name: String = "Unit"
		var icon: Texture2D = null
		if unit != null and unit.def != null:
			type_name = unit.def.display_name
			icon = unit.def.icon
		if not index_by_name.has(type_name):
			index_by_name[type_name] = groups.size()
			groups.append({"name": type_name, "count": 0, "icon": icon})
		var group: Dictionary = groups[index_by_name[type_name]]
		var count: int = group["count"]
		group["count"] = count + 1
	return groups


func _on_selection_changed(entities: Array[Node3D]) -> void:
	_selection_panel.visible = not entities.is_empty()
	_selection_title.text = "SELECTED  ·  %d" % entities.size()
	for chip: Node in _chips.get_children():
		chip.queue_free()
	for group: Dictionary in group_by_type(entities):
		var type_name: String = group["name"]
		var count: int = group["count"]
		var icon: Texture2D = group["icon"]
		_chips.add_child(_make_chip(type_name, count, icon))


func _build_selection_panel() -> void:
	_selection_panel = _make_panel(Control.PRESET_BOTTOM_LEFT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_selection_panel.add_child(column)
	_selection_title = _make_label(11, MUTED_COLOR)
	column.add_child(_selection_title)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override(&"separation", 14)
	column.add_child(_chips)


func _build_hint() -> void:
	_hint_panel = _make_panel(Control.PRESET_BOTTOM_RIGHT)
	_hint_panel.add_child(_make_label(12, TEXT_COLOR, HINT))
	_hint_panel.visible = false
	_hint_toggle = _make_label(11, MUTED_COLOR, "F1  CONTROLS")
	add_child(_hint_toggle)
	_place(_hint_toggle, Control.PRESET_BOTTOM_RIGHT)


func _build_debug() -> void:
	_debug_panel = _make_panel(Control.PRESET_TOP_LEFT)
	_debug = _make_label(12, TEXT_COLOR)
	_debug_panel.add_child(_debug)
	_debug_panel.visible = false


func _make_chip(type_name: String, count: int, icon: Texture2D) -> Control:
	var chip := VBoxContainer.new()
	chip.add_theme_constant_override(&"separation", 0)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2.ONE * ICON_SIZE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.add_child(picture)
	var caption := _make_label(12, TEXT_COLOR, "%d  %s" % [count, type_name])
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(caption)
	return chip


func _make_panel(preset: Control.LayoutPreset) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = ACCENT_COLOR
	style.border_width_top = 2
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_place(panel, preset)
	return panel


func _make_label(font_size: int, color: Color, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Pins a control to a screen corner and makes it grow away from that corner.
func _place(control: Control, preset: Control.LayoutPreset) -> void:
	control.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, MARGIN)
	control.grow_horizontal = (
		Control.GROW_DIRECTION_BEGIN
		if preset == Control.PRESET_BOTTOM_RIGHT
		else Control.GROW_DIRECTION_END
	)
	control.grow_vertical = (
		Control.GROW_DIRECTION_END
		if preset == Control.PRESET_TOP_LEFT
		else Control.GROW_DIRECTION_BEGIN
	)


static func _frame_ms() -> float:
	return Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
