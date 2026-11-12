class_name Hud
extends CanvasLayer
## In-mission HUD: the resource bar (top), the command panel (bottom centre: build
## menu, production, hints), a selection panel with one chip per type, a controls
## panel (F1) and a debug overlay (F3). Built in code from HudStyle so every panel
## reads as the same survey-instrument family.

const HINT: String = (
	"LEFT     select: click, drag, double-click type  ·  building: click it\n"
	+ "         enemy: attack  ·  buttons: build, queue units\n"
	+ "RIGHT    move  ·  enemy: attack  ·  deposit: harvest (Haulers)\n"
	+ "         site: help build (Fabricators)  ·  building selected: rally point\n"
	+ "         unit button: cancel one  ·  while placing: cancel (or Esc)\n"
	+ "SHIFT    add to selection  ·  queue orders  ·  place several  ·  X stop\n"
	+ "GROUPS   Ctrl+1-9 store  ·  1-9 recall, twice to centre\n"
	+ "CAMERA   WASD/arrows/edge/MMB pan  ·  wheel zoom  ·  Q/E turn"
)
const MARGIN := HudStyle.MARGIN

## The mission's world: economy for the resource bar, last sim-tick cost for the
## debug overlay.
@export var world: SimWorld
## Where build and production buttons send their requests.
@export var selection_controller: SelectionController
@export var player_faction: int = 0

var _selection_panel: PanelContainer
var _selection_title: Label
var _chips: HBoxContainer
var _hint_panel: PanelContainer
var _hint_toggle: Label
var _debug_panel: PanelContainer
var _debug: Label
var _tick: int = 0
var _resource_bar: ResourceBar
var _command_panel: CommandPanel


func _ready() -> void:
	_build_selection_panel()
	_build_hint()
	_build_debug()
	# The world sets up its economy in the map's _ready, after this HUD's.
	_build_economy_panels.call_deferred()
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
		"Buildings %d" % get_tree().get_nodes_in_group(Building.GROUP).size(),
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


## One entry per unit or building type in first-seen order: { name, count, icon }.
static func group_by_type(entities: Array[Node3D]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var index_by_name: Dictionary[String, int] = {}
	for entity: Node3D in entities:
		var type_name: String = "Unit"
		var icon: Texture2D = null
		var value: Variant = entity.get(&"def") if is_instance_valid(entity) else null
		if value is EntityDef:
			var def: EntityDef = value
			type_name = def.display_name
			icon = def.icon
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


func _build_economy_panels() -> void:
	var economy: Economy = world.economy if world != null else null
	_resource_bar = ResourceBar.new()
	_resource_bar.setup(player_faction, economy)
	add_child(_resource_bar)
	_resource_bar.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 6
	)
	_resource_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if selection_controller == null or world == null:
		return
	_command_panel = CommandPanel.new()
	_command_panel.setup(selection_controller, world, player_faction)
	add_child(_command_panel)
	_command_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MARGIN
	)
	_command_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_command_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_selection_panel() -> void:
	_selection_panel = _make_panel(Control.PRESET_BOTTOM_LEFT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_selection_panel.add_child(column)
	_selection_title = _make_label(11, HudStyle.MUTED_COLOR)
	column.add_child(_selection_title)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override(&"separation", 14)
	column.add_child(_chips)


func _build_hint() -> void:
	_hint_panel = _make_panel(Control.PRESET_BOTTOM_RIGHT)
	_hint_panel.add_child(_make_label(12, HudStyle.TEXT_COLOR, HINT))
	_hint_panel.visible = false
	_hint_toggle = _make_label(11, HudStyle.MUTED_COLOR, "F1  CONTROLS")
	add_child(_hint_toggle)
	_place(_hint_toggle, Control.PRESET_BOTTOM_RIGHT)


func _build_debug() -> void:
	_debug_panel = _make_panel(Control.PRESET_TOP_LEFT)
	_debug = _make_label(12, HudStyle.TEXT_COLOR)
	_debug_panel.add_child(_debug)
	_debug_panel.visible = false


func _make_chip(type_name: String, count: int, icon: Texture2D) -> Control:
	var chip := VBoxContainer.new()
	chip.add_theme_constant_override(&"separation", 0)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2.ONE * HudStyle.ICON_SIZE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.add_child(picture)
	var caption := _make_label(12, HudStyle.TEXT_COLOR, "%d  %s" % [count, type_name])
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(caption)
	return chip


func _make_panel(preset: Control.LayoutPreset) -> PanelContainer:
	var panel: PanelContainer = HudStyle.make_panel()
	add_child(panel)
	_place(panel, preset)
	return panel


func _make_label(font_size: int, color: Color, text: String = "") -> Label:
	return HudStyle.make_label(font_size, color, text)


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
