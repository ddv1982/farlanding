class_name ObjectivesPanel
extends PanelContainer
## Top-left list of the mission's known objectives, following the objective events:
## a coloured mark per objective (primary amber, secondary cyan; green when done, red
## when failed), its title, its progress line and any countdown. Below it, when the
## mission has one, the enemy's alert meter (Unaware, Suspicious, Alerted). Reads
## only `Events` and the Objective it is handed.

const PRIMARY_COLOR := Color(1.0, 0.82, 0.35)
const SECONDARY_COLOR := Color(0.4, 0.9, 1.0)
const DONE_COLOR := Color(0.45, 1.0, 0.55)
const FAILED_COLOR := Color(1.0, 0.3, 0.22)
const ALERT_COLORS: Dictionary[StringName, Color] = {
	&"unaware": Color(0.55, 0.9, 1.0),
	&"suspicious": Color(1.0, 0.72, 0.15),
	&"alerted": Color(1.0, 0.2, 0.12),
}

var _rows: VBoxContainer
var _alert_row: HBoxContainer
var _alert_value: Label
var _alert_faction: int = -1
## Objective -> { mark, title, progress }
var _entries: Dictionary[Objective, Dictionary] = {}
var _tick: int = 0


func _ready() -> void:
	add_theme_stylebox_override(&"panel", HudStyle.panel_style())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(280, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	add_child(column)
	column.add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, "OBJECTIVES"))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	column.add_child(_rows)
	_alert_row = HBoxContainer.new()
	_alert_row.add_theme_constant_override(&"separation", 8)
	_alert_row.add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, "COMBINE ALERT"))
	_alert_value = HudStyle.make_label(13, ALERT_COLORS[&"unaware"], "UNAWARE")
	_alert_row.add_child(_alert_value)
	_alert_row.visible = false
	column.add_child(_alert_row)
	visible = false
	Events.mission_started.connect(clear)
	Events.objective_added.connect(_on_objective_changed)
	Events.objective_updated.connect(_on_objective_changed)
	Events.objective_completed.connect(_on_objective_changed)
	Events.objective_failed.connect(_on_objective_changed)
	Events.alert_level_changed.connect(_on_alert_level_changed)
	Events.sim_ticked.connect(func(tick: int) -> void: _tick = tick)


func _process(_delta: float) -> void:
	for objective: Objective in _entries:
		if objective.countdown_tick >= 0 and objective.is_active():
			_show_progress(objective)


## Forgets every objective (a new mission began).
func clear() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	_entries.clear()
	_alert_row.visible = false
	_alert_faction = -1
	visible = false


## Shows the alert meter of `faction` (Unaware until it changes).
func show_alert_meter(faction: int) -> void:
	_alert_faction = faction
	_alert_row.visible = true
	_set_alert(&"unaware")
	visible = true


## Number of objectives listed (tests).
func row_count() -> int:
	return _entries.size()


## The objectives listed, in no particular order.
func known() -> Array[Objective]:
	var result: Array[Objective] = []
	result.assign(_entries.keys())
	return result


func _on_objective_changed(objective: RefCounted) -> void:
	var changed: Objective = objective as Objective
	if changed == null or not changed.is_known:
		return
	if not _entries.has(changed):
		_add_row(changed)
	var entry: Dictionary = _entries[changed]
	var mark: ColorRect = entry["mark"]
	var title: Label = entry["title"]
	var primary: bool = changed.kind == Objective.KIND_PRIMARY
	var base: Color = PRIMARY_COLOR if primary else SECONDARY_COLOR
	var label: String = changed.title + ("" if primary else "  (optional)")
	match changed.state:
		Objective.STATE_DONE:
			mark.color = DONE_COLOR
			title.text = "%s  ·  done" % label
			title.add_theme_color_override(&"font_color", HudStyle.MUTED_COLOR)
		Objective.STATE_FAILED:
			mark.color = FAILED_COLOR
			title.text = "%s  ·  failed" % label
			title.add_theme_color_override(&"font_color", FAILED_COLOR)
		_:
			mark.color = base
			title.text = label
			title.add_theme_color_override(&"font_color", HudStyle.TEXT_COLOR)
	_show_progress(changed)
	visible = true


func _add_row(objective: Objective) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var mark := ColorRect.new()
	mark.custom_minimum_size = Vector2(8, 8)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := MarginContainer.new()
	holder.add_theme_constant_override(&"margin_top", 5)
	holder.add_child(mark)
	row.add_child(holder)
	var text := VBoxContainer.new()
	text.add_theme_constant_override(&"separation", 0)
	var title: Label = HudStyle.make_label(13, HudStyle.TEXT_COLOR, objective.title)
	text.add_child(title)
	var progress: Label = HudStyle.make_label(11, HudStyle.MUTED_COLOR)
	text.add_child(progress)
	row.add_child(text)
	_rows.add_child(row)
	_entries[objective] = {"mark": mark, "title": title, "progress": progress}


func _show_progress(objective: Objective) -> void:
	var progress: Label = _entries[objective]["progress"]
	var parts: PackedStringArray = []
	if objective.progress_text != "":
		parts.append(objective.progress_text)
	if objective.countdown_tick >= 0 and objective.is_active():
		var left: String = MissionResult.clock_text(objective.seconds_left(_tick))
		parts.append(("%s left" if objective.countdown_fails else "hold %s") % left)
	progress.text = "  ·  ".join(parts)
	progress.visible = not parts.is_empty()


func _on_alert_level_changed(faction: int, level: StringName, _previous: StringName) -> void:
	if faction == _alert_faction:
		_set_alert(level)


func _set_alert(level: StringName) -> void:
	_alert_value.text = String(level).to_upper()
	var color: Color = ALERT_COLORS.get(level, HudStyle.TEXT_COLOR)
	_alert_value.add_theme_color_override(&"font_color", color)
