class_name Hud
extends CanvasLayer
## Minimal HUD: selection summary, controls hint and an F3 debug overlay. Plain
## labels; styling comes later.

const HINT: String = (
	"LMB select / drag box · Shift add · double-click same type · Ctrl+1-9 store, 1-9 recall\n"
	+ "RMB move (Shift queue) · A + LMB attack-move · S stop · Esc cancel\n"
	+ "Arrows / edges / MMB drag pan (WASD when nothing selected) · wheel zoom · Q/E rotate · F3 debug"
)

## Optional: shows the last sim-tick cost in the debug overlay.
@export var world: SimWorld

var _summary: Label
var _hint: Label
var _debug: Label
var _tick: int = 0


func _ready() -> void:
	_summary = _make_label(16, Control.PRESET_BOTTOM_LEFT)
	_hint = _make_label(12, Control.PRESET_BOTTOM_RIGHT)
	_hint.text = HINT
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(1, 1, 1, 0.75)
	_debug = _make_label(14, Control.PRESET_TOP_LEFT)
	_debug.visible = false
	Events.selection_changed.connect(_on_selection_changed)
	Events.sim_ticked.connect(func(tick: int) -> void: _tick = tick)
	_on_selection_changed([])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		_debug.visible = not _debug.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _debug.visible:
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
	var counts: Dictionary[String, int] = {}
	var order: PackedStringArray = []
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		var type_name: String = "Unit"
		if unit != null and unit.def != null:
			type_name = unit.def.display_name
		if not counts.has(type_name):
			counts[type_name] = 0
			order.append(type_name)
		counts[type_name] += 1
	var parts: PackedStringArray = []
	for type_name: String in order:
		parts.append("%d %s" % [counts[type_name], type_name])
	return "%d selected: %s" % [entities.size(), ", ".join(parts)]


func _on_selection_changed(entities: Array[Node3D]) -> void:
	_summary.text = summarize(entities)


func _make_label(font_size: int, preset: Control.LayoutPreset) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 12)
	label.grow_horizontal = (
		Control.GROW_DIRECTION_BEGIN
		if preset == Control.PRESET_BOTTOM_RIGHT
		else Control.GROW_DIRECTION_END
	)
	label.grow_vertical = (
		Control.GROW_DIRECTION_END
		if preset == Control.PRESET_TOP_LEFT
		else Control.GROW_DIRECTION_BEGIN
	)
	return label


static func _frame_ms() -> float:
	return Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
