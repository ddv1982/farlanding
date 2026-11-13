class_name PlanetIndicator
extends PanelContainer
## The planet rule's gauge under the HUD's top-right buttons (ADR 0011): on Kessel
## Reach the dust storm, "CLEAR", a countdown once one is announced, then a bar of
## its strength. It reads the world's PlanetRuleSystem through its generic
## `indicator_*` methods, so any later planet rule shows here without UI changes.
## Hidden when the mission's planet has no rule.

const CALM_COLOR := Color(0.62, 0.68, 0.74)
const STORM_COLOR := Color(0.93, 0.62, 0.30)

## The mission's world (set by the HUD once the world is set up).
var world: SimWorld = null

var _title: Label
var _status: Label
var _bar: ProgressBar
var _fill: StyleBoxFlat
var _tick: int = 0


func _ready() -> void:
	add_theme_stylebox_override(&"panel", HudStyle.panel_style())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	column.add_child(row)
	_title = HudStyle.make_label(11, HudStyle.MUTED_COLOR)
	row.add_child(_title)
	_status = HudStyle.make_label(13, CALM_COLOR)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_status)
	_bar = HudStyle.make_progress_bar()
	_fill = StyleBoxFlat.new()
	_fill.bg_color = STORM_COLOR
	_bar.add_theme_stylebox_override(&"fill", _fill)
	column.add_child(_bar)
	visible = false
	Events.sim_ticked.connect(func(tick: int) -> void: _tick = tick)


func _process(_delta: float) -> void:
	var rule: PlanetRuleSystem = world.planet if world != null else null
	var title: String = rule.indicator_title() if rule != null else ""
	visible = title != ""
	if not visible:
		return
	_title.text = title
	_status.text = rule.indicator_text(_tick)
	var alarm: bool = rule.indicator_alarm()
	_status.add_theme_color_override(&"font_color", STORM_COLOR if alarm else CALM_COLOR)
	_bar.value = rule.indicator_level()
	_bar.visible = rule.indicator_level() > 0.0
