class_name SettingsPanel
extends Control
## The settings screen (reached from the mission select and the pause menu): volumes,
## mouse scheme, edge-pan and pan speed, window and render quality, and "Reset hints".
## Every control writes straight through the `Settings` autoload (which saves).
## Back (or Esc) emits `closed`.

## The player left the settings.
signal closed

const BACKDROP := Color(0.0, 0.0, 0.0, 0.55)
const WIDTH: float = 520.0
## Seconds between two slider ticks (the sound), however fast the slider moves.
const TICK_GAP: float = 0.06
const VOLUME_LABELS: Dictionary[StringName, String] = {
	&"master_volume": "Master",
	&"music_volume": "Music",
	&"sfx_volume": "Effects",
	&"ui_volume": "Interface",
}
const QUALITY_LABELS: Dictionary[StringName, String] = {
	&"low": "Low  (no shadows or glow)",
	&"medium": "Medium",
	&"high": "High",
}

var _volume_sliders: Dictionary[StringName, HSlider] = {}
var _scheme: OptionButton
var _edge_pan: CheckButton
var _pan_speed: HSlider
var _fullscreen: CheckButton
var _quality: OptionButton
var _render_scale: HSlider
var _reset_hints: Button
var _hint_note: Label
var _last_tick: float = -1.0
var _syncing: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = BACKDROP
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = HudStyle.make_panel()
	panel.add_theme_stylebox_override(&"panel", HudStyle.solid_panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)
	column.add_child(HudStyle.make_label(11, HudStyle.ACCENT_COLOR, "THE CONCORD SURVEY"))
	column.add_child(HudStyle.make_label(26, HudStyle.TEXT_COLOR, "Settings"))
	_section(column, "AUDIO")
	for key: StringName in Settings.VOLUMES:
		var slider: HSlider = _slider(0.0, 1.0, 0.01)
		slider.value_changed.connect(_on_volume_changed.bind(key))
		_volume_sliders[key] = slider
		_row(column, VOLUME_LABELS[key], slider)
	_section(column, "CONTROLS")
	_scheme = _options(["Classic  (left click does it all)", "Modern  (right click commands)"])
	_scheme.item_selected.connect(_on_scheme_selected)
	_row(column, "Mouse", _scheme)
	_edge_pan = _check()
	_edge_pan.toggled.connect(_on_edge_pan_toggled)
	_row(column, "Edge pan", _edge_pan)
	_pan_speed = _slider(Settings.MIN_PAN_SPEED, Settings.MAX_PAN_SPEED, 0.05)
	_pan_speed.value_changed.connect(_on_pan_speed_changed)
	_row(column, "Pan speed", _pan_speed)
	_section(column, "DISPLAY")
	_fullscreen = _check()
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_row(column, "Fullscreen", _fullscreen)
	var names: Array[String] = []
	for preset: StringName in Settings.QUALITIES:
		names.append(QUALITY_LABELS[preset])
	_quality = _options(names)
	_quality.item_selected.connect(_on_quality_selected)
	_row(column, "Quality", _quality)
	_render_scale = _slider(Settings.MIN_RENDER_SCALE, 1.0, 0.05)
	_render_scale.value_changed.connect(_on_render_scale_changed)
	_row(column, "Resolution", _render_scale)
	_section(column, "TUTORIAL")
	_reset_hints = HudStyle.make_small_button("RESET HINTS")
	_reset_hints.pressed.connect(_on_reset_hints)
	_hint_note = HudStyle.make_label(11, HudStyle.MUTED_COLOR)
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override(&"separation", 10)
	hint_row.add_child(_reset_hints)
	hint_row.add_child(_hint_note)
	column.add_child(hint_row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var back: Button = HudStyle.make_small_button("BACK  (Esc)")
	back.custom_minimum_size = Vector2(120, 32)
	back.pressed.connect(close)
	buttons.add_child(back)
	column.add_child(buttons)
	Settings.changed.connect(sync_from_settings)
	sync_from_settings()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## Shows the panel with the current settings.
func open() -> void:
	sync_from_settings()
	visible = true
	Events.ui_feedback.emit(&"click")


func close() -> void:
	if not visible:
		return
	visible = false
	Events.ui_feedback.emit(&"click")
	closed.emit()


## Puts every control at its setting (without writing back).
func sync_from_settings() -> void:
	if _scheme == null:
		return
	_syncing = true
	for key: StringName in _volume_sliders:
		var value: float = Settings.get(key)
		_volume_sliders[key].value = value
	_scheme.selected = Settings.SCHEMES.find(Settings.control_scheme)
	_edge_pan.button_pressed = Settings.edge_pan
	_pan_speed.value = Settings.pan_speed
	_fullscreen.button_pressed = Settings.fullscreen
	_quality.selected = Settings.QUALITIES.find(Settings.quality)
	_render_scale.value = Settings.render_scale
	var seen: int = Settings.hints_seen.size()
	_hint_note.text = "%d seen" % seen if seen > 0 else "all hints will show"
	_reset_hints.disabled = seen == 0
	_syncing = false


func _on_volume_changed(value: float, key: StringName) -> void:
	if _syncing:
		return
	Settings.set_volume(key, value)
	_tick()


func _on_scheme_selected(index: int) -> void:
	if not _syncing:
		Settings.set_control_scheme(Settings.SCHEMES[index])
		Events.ui_feedback.emit(&"toggle")


func _on_edge_pan_toggled(on: bool) -> void:
	if not _syncing:
		Settings.set_edge_pan(on)
		Events.ui_feedback.emit(&"toggle")


func _on_pan_speed_changed(value: float) -> void:
	if not _syncing:
		Settings.set_pan_speed(value)
		_tick()


func _on_fullscreen_toggled(on: bool) -> void:
	if not _syncing:
		Settings.set_fullscreen(on)
		Events.ui_feedback.emit(&"toggle")


func _on_quality_selected(index: int) -> void:
	if not _syncing:
		Settings.set_quality(Settings.QUALITIES[index])
		Events.ui_feedback.emit(&"toggle")


func _on_render_scale_changed(value: float) -> void:
	if not _syncing:
		Settings.set_render_scale(value)
		_tick()


func _on_reset_hints() -> void:
	Settings.reset_hints()
	Events.ui_feedback.emit(&"click")


func _tick() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_tick < TICK_GAP:
		return
	_last_tick = now
	Events.ui_feedback.emit(&"slider_tick")


func _section(column: VBoxContainer, title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	column.add_child(gap)
	column.add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, title))


func _row(column: VBoxContainer, caption: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var label: Label = HudStyle.make_label(13, HudStyle.TEXT_COLOR, caption)
	label.custom_minimum_size = Vector2(130, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	column.add_child(row)


static func _slider(low: float, high: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(200, 20)
	slider.focus_mode = Control.FOCUS_NONE
	return slider


static func _check() -> CheckButton:
	var check := CheckButton.new()
	check.focus_mode = Control.FOCUS_NONE
	return check


static func _options(items: Array[String]) -> OptionButton:
	var options := OptionButton.new()
	options.focus_mode = Control.FOCUS_NONE
	options.add_theme_font_size_override(&"font_size", 12)
	for item: String in items:
		options.add_item(item)
	return options
