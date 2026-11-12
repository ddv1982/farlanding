class_name CommandPanel
extends PanelContainer
## Bottom-centre command panel for the current selection, with a one-line hint of
## what the mouse does right now:
##
## - Fabricators selected: the build menu, one button per building (dimmed with the
##   reason when it cannot be afforded). A click starts placement.
## - A producer building selected: one button per unit. Left click queues one (paid
##   now), right click cancels the last one of that type (refunded). Each button
##   shows how many are queued, and the unit in progress has a progress bar.
## - A building under construction: its progress.
## - Haulers selected: how to send them harvesting.

const PLACE_HINT: String = (
	"Left-click: place  ·  Shift+click: place another  ·  " + "right-click or Esc: cancel"
)
const BUILD_HINT: String = (
	"Pick a building, then left-click the ground  ·  " + "right-click a site to help build"
)
const HAUL_HINT: String = (
	"Right-click an Alloy deposit to harvest it  ·  " + "new Haulers start on their own"
)
const PRODUCE_HINT: String = (
	"Left-click: queue  ·  right-click a button: cancel  ·  " + "right-click ground: rally point"
)
const SITE_HINT: String = "Select Fabricators and right-click the site to help build"

var controller: SelectionController = null
var world: SimWorld = null
var faction: int = 0

var _title: Label
var _buttons: HBoxContainer
var _status: Label
var _progress: ProgressBar
var _hint: Label
var _mode: String = ""
var _entries: Array[Dictionary] = []  # { def, button, caption, badge, bar }


func setup(p_controller: SelectionController, p_world: SimWorld, p_faction: int) -> void:
	controller = p_controller
	world = p_world
	faction = p_faction
	var style := StyleBoxFlat.new()
	style.bg_color = HudStyle.PANEL_COLOR
	style.border_color = HudStyle.ACCENT_COLOR
	style.border_width_top = 2
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10)
	add_theme_stylebox_override(&"panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	add_child(column)
	_title = HudStyle.make_label(11, HudStyle.MUTED_COLOR)
	column.add_child(_title)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 8)
	column.add_child(_buttons)
	_status = HudStyle.make_label(12, HudStyle.TEXT_COLOR)
	column.add_child(_status)
	_progress = HudStyle.make_progress_bar()
	_progress.custom_minimum_size = Vector2(260, 6)
	column.add_child(_progress)
	_hint = HudStyle.make_label(12, HudStyle.MUTED_COLOR)
	column.add_child(_hint)
	visible = false


func _process(_delta: float) -> void:
	if controller == null or world == null:
		return
	var mode: String = _current_mode()
	if mode != _mode:
		_mode = mode
		_rebuild()
	if visible:
		_refresh()


## A key that changes whenever the panel needs different buttons.
func _current_mode() -> String:
	if controller.placement.is_active():
		return "place:%s" % controller.placement.def.id
	var building: Building = controller.selected_building
	if building != null and is_instance_valid(building):
		var stage: String = "site" if building.is_under_construction else "done"
		return "building:%d:%s" % [building.get_instance_id(), stage]
	if not _builders().is_empty():
		var ids: PackedStringArray = []
		for def: BuildingDef in _build_options():
			ids.append(String(def.id))
		return "build:%s" % ",".join(ids)
	if not SelectionRules.able(controller.selection, Harvester.KIND).is_empty():
		return "haul"
	return ""


func _rebuild() -> void:
	for child: Node in _buttons.get_children():
		child.queue_free()
	_entries.clear()
	_status.text = ""
	_status.visible = false
	_progress.visible = false
	visible = _mode != ""
	if _mode == "":
		return
	if _mode.begins_with("place:") or _mode.begins_with("build:"):
		_title.text = "BUILD"
		for def: BuildingDef in _build_options():
			_add_build_button(def)
	elif _mode.begins_with("building:"):
		var building: Building = controller.selected_building
		_title.text = building.def.display_name.to_upper()
		if building.is_operational() and building.producer != null:
			for def: UnitDef in building.producer.options:
				_add_unit_button(def, building)
	elif _mode == "haul":
		_title.text = "HAULERS"
	_buttons.visible = _buttons.get_child_count() > 0


func _refresh() -> void:
	var pile: Stockpile = world.economy.stockpile(faction)
	if _mode.begins_with("place:"):
		var placement: BuildPlacement = controller.placement
		var reason: String = PlacementRules.describe(placement.reason)
		_set_status(
			"Placing %s%s" % [placement.def.display_name, ": " + reason if reason != "" else ""],
			HudStyle.WARNING_COLOR if reason != "" else HudStyle.TEXT_COLOR
		)
		_hint.text = PLACE_HINT
	elif _mode.begins_with("build:"):
		_hint.text = BUILD_HINT
	elif _mode == "haul":
		_hint.text = HAUL_HINT
	elif _mode.begins_with("building:"):
		_refresh_building(controller.selected_building)
	for entry: Dictionary in _entries:
		_refresh_entry(entry, pile)


func _refresh_building(building: Building) -> void:
	if building == null or not is_instance_valid(building):
		return
	if building.is_under_construction:
		_progress.visible = true
		_progress.value = building.construction.progress()
		var builders: int = building.construction.builders
		_set_status(
			(
				"Under construction  %d%%  ·  %d builder%s"
				% [
					roundi(building.construction.progress() * 100.0),
					builders,
					"" if builders == 1 else "s"
				]
			),
			HudStyle.TEXT_COLOR
		)
		_hint.text = SITE_HINT
		return
	var producer: Producer = building.producer
	if producer != null:
		var low: bool = world.economy.stockpile(faction).is_low_power()
		var line: String = "Queue %d / %d" % [producer.queue.size(), producer.limit]
		if producer.current() != null:
			line += (
				"  ·  %s %d%%"
				% [producer.current().display_name, roundi(producer.progress() * 100.0)]
			)
		if low:
			line += "  ·  LOW POWER: %d%% speed" % roundi(world.rules.low_power_rate * 100.0)
		_set_status(line, HudStyle.WARNING_COLOR if low else HudStyle.TEXT_COLOR)
		_hint.text = PRODUCE_HINT
		return
	_set_status(_power_line(building.def), HudStyle.TEXT_COLOR)
	_hint.text = building.def.description


func _refresh_entry(entry: Dictionary, pile: Stockpile) -> void:
	var def: EntityDef = entry["def"]
	var button: Button = entry["button"]
	var shortfall: String = pile.shortfall_text(def.cost_alloy, def.cost_flux)
	button.modulate = Color(1, 1, 1, 0.55) if shortfall != "" else Color.WHITE
	var caption: String = "%s\n%s" % [def.display_name, HudStyle.cost_text(def)]
	if shortfall != "":
		caption += "\n" + shortfall.replace("Need ", "need ")
	if button.text != caption:
		button.text = caption
	var badge: Label = entry.get("badge", null)
	var bar: ProgressBar = entry.get("bar", null)
	var building: Building = controller.selected_building
	if badge == null or building == null or not is_instance_valid(building):
		return
	var producer: Producer = building.producer
	var count: int = producer.count_of(def as UnitDef)
	badge.text = "×%d" % count if count > 0 else ""
	var in_progress: bool = producer.current() == def
	bar.visible = in_progress
	if in_progress:
		bar.value = producer.progress()


func _add_build_button(def: BuildingDef) -> void:
	var button: Button = HudStyle.make_button(def.icon, def.display_name)
	button.tooltip_text = (
		"%s  ·  %s  ·  %d s\n%s\n%s"
		% [
			def.display_name,
			HudStyle.cost_text(def),
			roundi(def.build_time),
			_power_line(def),
			def.description
		]
	)
	button.pressed.connect(_on_build_pressed.bind(def))
	_buttons.add_child(button)
	_entries.append({"def": def, "button": button})


func _add_unit_button(def: UnitDef, building: Building) -> void:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override(&"separation", 2)
	var button: Button = HudStyle.make_button(def.icon, def.display_name)
	button.tooltip_text = (
		"%s  ·  %s  ·  %d s\n%s\nLeft-click: queue one  ·  right-click: cancel the last one"
		% [def.display_name, HudStyle.cost_text(def), roundi(def.build_time), def.description]
	)
	button.pressed.connect(_on_unit_pressed.bind(def, building))
	button.gui_input.connect(_on_unit_button_input.bind(def, building))
	var badge: Label = HudStyle.make_label(14, HudStyle.ACCENT_COLOR)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-28, 2)
	button.add_child(badge)
	holder.add_child(button)
	var bar: ProgressBar = HudStyle.make_progress_bar()
	bar.visible = false
	holder.add_child(bar)
	_buttons.add_child(holder)
	_entries.append({"def": def, "button": button, "badge": badge, "bar": bar})


func _on_build_pressed(def: BuildingDef) -> void:
	if not world.economy.can_afford(faction, def):
		_refuse_unaffordable()
		return
	controller.begin_placement(def)


func _on_unit_pressed(def: UnitDef, building: Building) -> void:
	if not is_instance_valid(building) or building.producer == null:
		return
	if building.producer.check(def) == Producer.QUEUE_FULL:
		Events.ui_feedback.emit(&"invalid")
		return
	if not world.economy.can_afford(faction, def):
		_refuse_unaffordable()
		return
	world.context.command_queue.push(ProduceCommand.new(faction, building, def))


func _on_unit_button_input(event: InputEvent, def: UnitDef, building: Building) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_RIGHT:
		return
	accept_event()
	if not is_instance_valid(building) or building.producer == null:
		return
	if building.producer.count_of(def) == 0:
		Events.ui_feedback.emit(&"invalid")
		return
	world.context.command_queue.push(CancelProductionCommand.new(faction, building, def))


func _refuse_unaffordable() -> void:
	Events.ui_feedback.emit(&"not_enough_resources")
	Events.advisor_alert.emit(&"insufficient_resources")


func _set_status(text: String, color: Color) -> void:
	_status.visible = true
	_status.text = text
	_status.add_theme_color_override(&"font_color", color)


func _builders() -> Array[Unit]:
	return SelectionRules.able(controller.selection, Builder.KIND)


## Buildings the selected builders can place, in menu order, without repeats.
func _build_options() -> Array[BuildingDef]:
	var options: Array[BuildingDef] = []
	for unit: Unit in _builders():
		for entry: EntityDef in unit.def.builds:
			var def: BuildingDef = entry as BuildingDef
			if def != null and def.placeable and not options.has(def):
				options.append(def)
	return options


static func _power_line(def: BuildingDef) -> String:
	if def.power_output > 0:
		return "+%d Power" % def.power_output
	if def.power_use > 0:
		return "Uses %d Power" % def.power_use
	return "No Power needed"
