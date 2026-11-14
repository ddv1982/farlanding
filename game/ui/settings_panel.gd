class_name SettingsPanel
extends Control
## The settings screen (reached from the title, the mission select and the pause
## menu), in three tabs. GENERAL: volumes, mouse scheme, edge-pan and pan speed,
## window and render quality, and "Reset hints". ACCESSIBILITY: team colour palette,
## subtitles and their size, UI scale, fewer flashes, sticky Shift, and the game
## speed of single missions. KEYS: every key, rebindable (KeyBindingsPage). Every
## control writes straight through the `Settings` autoload (which saves). Back (or
## Esc) emits `closed`.

## The player left the settings.
signal closed

const BACKDROP := Color(0.0, 0.0, 0.0, 0.55)
const WIDTH: float = 540.0
## Height of a tab's page (it scrolls when longer).
const PAGE_HEIGHT: float = 400.0
const TAB_GENERAL: StringName = &"general"
const TAB_ACCESS: StringName = &"accessibility"
const TAB_KEYS: StringName = &"keys"
const TABS: Array[StringName] = [TAB_GENERAL, TAB_ACCESS, TAB_KEYS]
const TAB_LABELS: Dictionary[StringName, String] = {
	TAB_GENERAL: "GENERAL",
	TAB_ACCESS: "ACCESSIBILITY",
	TAB_KEYS: "KEYS",
}
## Seconds between two slider ticks (the sound), however fast the slider moves.
const TICK_GAP: float = 0.06
const VOLUME_LABELS: Dictionary[StringName, String] = {
	&"master_volume": "Master",
	&"music_volume": "Music",
	&"sfx_volume": "Effects",
	&"ambience_volume": "Ambience",
	&"voice_volume": "Voice  (Advisor)",
	&"ui_volume": "Interface",
}
const QUALITY_LABELS: Dictionary[StringName, String] = {
	&"low": "Low  (no shadows or glow)",
	&"medium": "Medium",
	&"high": "High",
}

## The tab shown (TABS).
var tab: StringName = TAB_GENERAL

var _volume_sliders: Dictionary[StringName, HSlider] = {}
var _scheme: OptionButton
var _edge_pan: CheckButton
var _pan_speed: HSlider
var _fullscreen: CheckButton
var _quality: OptionButton
var _render_scale: HSlider
var _reset_hints: Button
var _hint_note: Label
var _palette: OptionButton
var _subtitles: CheckButton
var _subtitle_size: OptionButton
var _ui_scale: OptionButton
var _reduce_flashes: CheckButton
var _sticky_shift: CheckButton
var _game_speed: OptionButton
var _keys: KeyBindingsPage
var _pages: Dictionary[StringName, Control] = {}
var _tab_buttons: Dictionary[StringName, Button] = {}
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
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 6)
	column.add_child(tabs)
	for tab_id: StringName in TABS:
		var tab_button: Button = HudStyle.make_small_button(TAB_LABELS[tab_id])
		tab_button.custom_minimum_size = Vector2(130, 30)
		tab_button.pressed.connect(_on_tab_pressed.bind(tab_id))
		tabs.add_child(tab_button)
		_tab_buttons[tab_id] = tab_button
	_build_general(_page(column, TAB_GENERAL))
	_build_accessibility(_page(column, TAB_ACCESS))
	_keys = KeyBindingsPage.new()
	_page(column, TAB_KEYS).add_child(_keys)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var back: Button = HudStyle.make_small_button("BACK  (Esc)")
	back.custom_minimum_size = Vector2(120, 32)
	back.pressed.connect(close)
	buttons.add_child(back)
	column.add_child(buttons)
	Settings.changed.connect(sync_from_settings)
	sync_from_settings()
	show_tab(TAB_GENERAL, false)
	visible = false


func _build_general(column: VBoxContainer) -> void:
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


func _build_accessibility(column: VBoxContainer) -> void:
	_section(column, "SEEING")
	var palettes: Array[String] = []
	for id: StringName in Settings.PALETTES:
		palettes.append(TeamColors.LABELS[id])
	_palette = _options(palettes)
	_palette.item_selected.connect(
		func(index: int) -> void: _set_option(&"colour_palette", Settings.PALETTES[index])
	)
	_row(column, "Team colours", _palette)
	var scales: Array[String] = []
	for scale: float in Settings.UI_SCALES:
		scales.append("%d%%" % roundi(scale * 100.0))
	_ui_scale = _options(scales)
	_ui_scale.item_selected.connect(
		func(index: int) -> void: _set_option(&"ui_scale", Settings.UI_SCALES[index])
	)
	_row(column, "Interface size", _ui_scale)
	_reduce_flashes = _check()
	_reduce_flashes.toggled.connect(func(on: bool) -> void: _set_option(&"reduce_flashes", on))
	_row(column, "Fewer flashes", _reduce_flashes)
	_section(column, "HEARING")
	_subtitles = _check()
	_subtitles.toggled.connect(func(on: bool) -> void: _set_option(&"subtitles", on))
	_row(column, "Subtitles", _subtitles)
	_subtitle_size = _options(["Normal", "Large"])
	_subtitle_size.item_selected.connect(
		func(index: int) -> void: _set_option(&"subtitle_size", Settings.SUBTITLE_SIZES[index])
	)
	_row(column, "Subtitle size", _subtitle_size)
	_section(column, "PLAYING")
	_sticky_shift = _check()
	_sticky_shift.toggled.connect(func(on: bool) -> void: _set_option(&"sticky_shift", on))
	_row(column, "Sticky Shift", _sticky_shift)
	var speeds: Array[String] = []
	for speed: float in Settings.GAME_SPEEDS:
		speeds.append("%s×" % str(speed))
	_game_speed = _options(speeds)
	_game_speed.item_selected.connect(
		func(index: int) -> void: _set_option(&"game_speed", Settings.GAME_SPEEDS[index])
	)
	_row(column, "Game speed", _game_speed)
	var note: Label = HudStyle.make_label(
		11,
		HudStyle.MUTED_COLOR,
		"Game speed applies to single missions; campaign landings run at 1×."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)


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
	show_tab(TAB_GENERAL, false)
	visible = true
	Events.ui_feedback.emit(&"click")


func close() -> void:
	if not visible:
		return
	visible = false
	Events.ui_feedback.emit(&"click")
	closed.emit()


## Shows the tab `tab_id` (TABS); `sound` plays the tab sound.
func show_tab(tab_id: StringName, sound: bool = true) -> void:
	if not TABS.has(tab_id):
		return
	tab = tab_id
	for id: StringName in _pages:
		_pages[id].visible = id == tab_id
		var button: Button = _tab_buttons[id]
		button.text = ("» " if id == tab_id else "") + TAB_LABELS[id]
		button.add_theme_color_override(
			&"font_color", HudStyle.ACCENT_COLOR if id == tab_id else HudStyle.TEXT_COLOR
		)
	if _keys != null:
		_keys.cancel()
	if sound:
		Events.ui_feedback.emit(&"tab_changed")


## The KEYS page (tests).
func keys_page() -> KeyBindingsPage:
	return _keys


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
	_palette.selected = maxi(Settings.PALETTES.find(Settings.colour_palette), 0)
	_ui_scale.selected = maxi(Settings.UI_SCALES.find(Settings.ui_scale), 0)
	_reduce_flashes.button_pressed = Settings.reduce_flashes
	_subtitles.button_pressed = Settings.subtitles
	_subtitle_size.selected = maxi(Settings.SUBTITLE_SIZES.find(Settings.subtitle_size), 0)
	_subtitle_size.disabled = not Settings.subtitles
	_sticky_shift.button_pressed = Settings.sticky_shift
	_game_speed.selected = maxi(Settings.GAME_SPEEDS.find(Settings.game_speed), 0)
	if _keys != null:
		_keys.refresh()
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


func _on_tab_pressed(tab_id: StringName) -> void:
	if tab_id != tab:
		show_tab(tab_id)


func _set_option(key: StringName, value: Variant) -> void:
	if not _syncing and Settings.set_option(key, value):
		Events.ui_feedback.emit(&"toggle")


func _on_reset_hints() -> void:
	Settings.reset_hints()
	Events.ui_feedback.emit(&"click")


func _tick() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_tick < TICK_GAP:
		return
	_last_tick = now
	Events.ui_feedback.emit(&"slider_tick")


## A tab's page: a scrolling column under the tab row.
func _page(parent: VBoxContainer, tab_id: StringName) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH, PAGE_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	_pages[tab_id] = scroll
	return column


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
