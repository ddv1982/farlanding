class_name Hud
extends CanvasLayer
## In-mission HUD: the resource bar (top), the command panel (bottom centre: build
## menu, production, field options, hints), a selection panel with one chip per
## type, the minimap (bottom right) with the controls panel (F1) above it, the codex
## (button or C) and the menu button (top right; the pause menu holds the settings,
## including the mouse scheme), the planet indicator under them (Kessel: the dust
## storm and its countdown), the mission's objectives (top left, with the enemy alert
## meter when the mission has one) and a debug overlay (F3). The end of a mission is
## shown by the debrief (ui/debrief_panel.gd).
## Built in code from HudStyle so every panel reads as the same survey-instrument
## family.

## The MENU button was pressed (Main opens the pause menu).
signal menu_requested

## Controls panel text per mouse scheme (Settings.control_scheme).
const HINT_CLASSIC: String = (
	"MOUSE    classic (Command & Conquer): left click does it all\n"
	+ "LEFT     own unit or building: select  ·  drag: box  ·  double-click: all of type\n"
	+ "         units selected: ground move  ·  enemy in sight attack  ·  ? scan\n"
	+ "         deposit harvest (Haulers)  ·  own site help build (Fabricators)\n"
	+ "         building selected: ground sets the rally point\n"
	+ "RIGHT    deselect  ·  while placing or aiming: cancel (or Esc)\n"
	+ "SHIFT    add to selection  ·  queue orders  ·  place several  ·  X stop\n"
	+ "GROUPS   Ctrl+1-9 store  ·  1-9 recall, twice to centre\n"
	+ "CAMERA   WASD/arrows/edge/MMB pan  ·  wheel zoom  ·  Q/E turn\n"
	+ "MAP      left: look there (drag)  ·  right: move selected units there\n"
	+ "CODEX    C or the button top right  ·  COMBAT  armed units fire by themselves\n"
	+ "MENU     Esc: pause, settings (mouse scheme, audio, display), restart, quit"
)
const HINT_MODERN: String = (
	"MOUSE    modern: left selects, right commands\n"
	+ "LEFT     select: click, drag, double-click type  ·  building: click it\n"
	+ "         enemy in sight: attack  ·  buttons: build, queue units\n"
	+ "RIGHT    move  ·  enemy in sight: attack  ·  ? site: scan (Surveyors)\n"
	+ "         deposit: harvest (Haulers)  ·  site: help build (Fabricators)\n"
	+ "         building selected: rally point  ·  unit button: cancel one\n"
	+ "         while placing or aiming: cancel (or Esc)\n"
	+ "SHIFT    add to selection  ·  queue orders  ·  place several  ·  X stop\n"
	+ "GROUPS   Ctrl+1-9 store  ·  1-9 recall, twice to centre\n"
	+ "CAMERA   WASD/arrows/edge/MMB pan  ·  wheel zoom  ·  Q/E turn\n"
	+ "MAP      left: look there (drag)  ·  right: move selected units there\n"
	+ "CODEX    C or the button top right  ·  COMBAT  armed units fire by themselves\n"
	+ "MENU     Esc: pause, settings (mouse scheme, audio, display), restart, quit"
)
const MARGIN := HudStyle.MARGIN

## The mission's world: economy for the resource bar, last sim-tick cost for the
## debug overlay.
@export var world: SimWorld
## Where build and production buttons send their requests.
@export var selection_controller: SelectionController
@export var player_faction: int = 0
## The camera the minimap moves and outlines.
@export var camera: RtsCamera
## World X/Z area the minimap shows.
@export var map_area: Rect2 = Rect2(-120.0, -120.0, 240.0, 240.0)

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
var _corner: VBoxContainer
var _minimap: Minimap
var _objectives: ObjectivesPanel
var _hint: Label
var _codex: CodexPanel
var _codex_button: Button
var _menu_button: Button
var _planet: PlanetIndicator


func _ready() -> void:
	_build_selection_panel()
	_build_hint()
	_build_debug()
	_build_top_right()
	_codex = CodexPanel.new()
	add_child(_codex)
	_codex.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_codex.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_codex.grow_vertical = Control.GROW_DIRECTION_BOTH
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()
	_objectives = ObjectivesPanel.new()
	_objectives.name = &"Objectives"
	add_child(_objectives)
	_place(_objectives, Control.PRESET_TOP_LEFT)
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
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F1:
		_hint_panel.visible = not _hint_panel.visible
		_hint_toggle.visible = not _hint_panel.visible
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_C and not key.ctrl_pressed and not key.meta_pressed:
		toggle_codex()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and _codex.visible:
		_codex.close_panel()
		get_viewport().set_input_as_handled()


## Shows the alert meter of the enemy `faction` under the objectives.
func show_alert_meter(faction: int) -> void:
	_objectives.show_alert_meter(faction)


## Opens the codex with the player's entries, or closes it.
func toggle_codex() -> void:
	if _codex.visible:
		_codex.close_panel()
		return
	var entries: Array[DiscoveryDef] = []
	if world != null and world.discovery != null:
		entries = world.discovery.codex(player_faction)
	_codex.open_panel(entries)


## Switches between the classic and modern mouse schemes (saved in the settings).
func toggle_control_scheme() -> void:
	var next: StringName = (
		Settings.SCHEME_MODERN
		if Settings.control_scheme == Settings.SCHEME_CLASSIC
		else Settings.SCHEME_CLASSIC
	)
	Settings.set_control_scheme(next)
	Events.ui_feedback.emit(&"click")


## Asks for the pause menu.
func request_menu() -> void:
	Events.ui_feedback.emit(&"click")
	menu_requested.emit()


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
		lines.append("Projectiles %d" % world.combat.projectiles.size())
		if world.vision != null:
			lines.append("Vision update %.2f ms" % (world.vision.last_update_usec / 1000.0))
		if world.stealth != null:
			lines.append("Stealth %.2f ms" % (world.stealth.last_tick_usec / 1000.0))
		if world.planet != null:
			lines.append("Storm %.2f" % world.conditions.storm_intensity)
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
	_planet.world = world
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
	_minimap = Minimap.new()
	_minimap.name = &"Minimap"
	_minimap.setup(world, camera, selection_controller, player_faction, map_area)
	_corner.add_child(_minimap)
	for objective: Objective in _objectives.known():
		_minimap.track_objective(objective)


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


## Bottom-right column: the controls panel (F1) or its toggle, above the minimap.
func _build_hint() -> void:
	_corner = VBoxContainer.new()
	_corner.alignment = BoxContainer.ALIGNMENT_END
	_corner.add_theme_constant_override(&"separation", 6)
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_corner)
	_place(_corner, Control.PRESET_BOTTOM_RIGHT)
	_hint_panel = HudStyle.make_panel()
	_hint = _make_label(12, HudStyle.TEXT_COLOR, HINT_CLASSIC)
	_hint_panel.add_child(_hint)
	_hint_panel.visible = false
	_corner.add_child(_hint_panel)
	_hint_toggle = _make_label(11, HudStyle.MUTED_COLOR, "F1  CONTROLS")
	_hint_toggle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_corner.add_child(_hint_toggle)


## Top right: the codex and menu buttons, the planet indicator below them.
func _build_top_right() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(row)
	_codex_button = HudStyle.make_small_button("CODEX  (C)")
	_codex_button.tooltip_text = "What the expedition has found on this landing."
	_codex_button.pressed.connect(toggle_codex)
	row.add_child(_codex_button)
	_menu_button = HudStyle.make_small_button("MENU  (Esc)")
	_menu_button.tooltip_text = "Pause: resume, settings (mouse, audio, display), restart, quit."
	_menu_button.pressed.connect(request_menu)
	row.add_child(_menu_button)
	_planet = PlanetIndicator.new()
	_planet.name = &"PlanetIndicator"
	_planet.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_planet)


func _on_settings_changed() -> void:
	var classic: bool = Settings.control_scheme == Settings.SCHEME_CLASSIC
	_hint.text = HINT_CLASSIC if classic else HINT_MODERN


func _build_debug() -> void:
	_debug_panel = _make_panel(Control.PRESET_CENTER_LEFT)
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
		else (
			Control.GROW_DIRECTION_BOTH
			if preset == Control.PRESET_CENTER_LEFT
			else Control.GROW_DIRECTION_BEGIN
		)
	)


static func _frame_ms() -> float:
	return Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
