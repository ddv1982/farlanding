class_name ResourceBar
extends PanelContainer
## Top resource bar for the player's faction: Alloy, Flux, Intel and Power (used /
## produced).
## Power turns to the warning colour, with a LOW POWER note, while more is used than
## produced. Updates from `Events.resources_changed`, `Events.intel_changed` and
## `Events.power_changed`.

var faction: int = 0

var _alloy: Label
var _flux: Label
var _intel: Label
var _power: Label
var _low_power: Label


## Builds the bar and shows the faction's current stockpile from `economy` (if any).
func setup(p_faction: int, economy: Economy) -> void:
	faction = p_faction
	var style := StyleBoxFlat.new()
	style.bg_color = HudStyle.PANEL_COLOR
	style.border_color = HudStyle.ACCENT_COLOR
	style.border_width_bottom = 2
	style.set_corner_radius_all(3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override(&"panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 22)
	add_child(row)
	_alloy = _add_entry(row, "ALLOY", HudStyle.ALLOY_COLOR)
	_flux = _add_entry(row, "FLUX", HudStyle.FLUX_COLOR)
	_intel = _add_entry(row, "INTEL", HudStyle.INTEL_COLOR)
	_intel.tooltip_text = "Earned only by scanning discoveries. Spent at the Survey Lab."
	_intel.mouse_filter = Control.MOUSE_FILTER_PASS
	_power = _add_entry(row, "POWER", HudStyle.POWER_COLOR)
	_low_power = HudStyle.make_label(12, HudStyle.WARNING_COLOR, "LOW POWER: production slowed")
	_low_power.visible = false
	row.add_child(_low_power)
	_power.tooltip_text = "Power used / produced. Build Reactors when it runs short."
	_power.mouse_filter = Control.MOUSE_FILTER_PASS
	Events.resources_changed.connect(_on_resources_changed)
	Events.power_changed.connect(_on_power_changed)
	Events.intel_changed.connect(_on_intel_changed)
	if economy != null:
		var pile: Stockpile = economy.stockpile(faction)
		_on_resources_changed(faction, pile.alloy, pile.flux)
		_on_intel_changed(faction, pile.intel)
		_on_power_changed(faction, pile.power_produced, pile.power_used)


func _add_entry(row: HBoxContainer, title: String, color: Color) -> Label:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override(&"separation", 6)
	entry.add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, title))
	var value := HudStyle.make_label(16, color, "0")
	entry.add_child(value)
	row.add_child(entry)
	return value


func _on_resources_changed(p_faction: int, alloy: int, flux: int) -> void:
	if p_faction != faction:
		return
	_alloy.text = str(alloy)
	_flux.text = str(flux)


func _on_intel_changed(p_faction: int, intel: int) -> void:
	if p_faction == faction:
		_intel.text = str(intel)


## The Intel shown now (tests).
func intel_text() -> String:
	return _intel.text


func _on_power_changed(p_faction: int, produced: int, used: int) -> void:
	if p_faction != faction:
		return
	var low: bool = used > produced
	_power.text = "%d / %d" % [used, produced]
	_power.add_theme_color_override(
		&"font_color", HudStyle.WARNING_COLOR if low else HudStyle.POWER_COLOR
	)
	_low_power.visible = low
