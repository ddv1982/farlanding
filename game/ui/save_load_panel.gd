class_name SaveLoadPanel
extends Control
## The save and load screen over the pause menu (ADR 0013): one row per slot (the
## quicksave, the landing autosave, three manual slots) with the mission title, the
## time played and the date, or "Empty". Saving offers every slot but the autosave;
## loading only the slots that hold a usable save (a damaged or newer save shows
## why it cannot be loaded). A status line shows how the last save or load went.
## Back (or Esc) emits `closed`. Main does the saving and loading.

## The player picked `slot`: `saving` is true to save into it, false to load it.
signal slot_chosen(slot: StringName, saving: bool)
## The player left the screen.
signal closed

const BACKDROP := Color(0.0, 0.0, 0.0, 0.55)
const WIDTH: float = 520.0

## True while it offers saving, false while loading.
var saving: bool = true

var _heading: Label
var _rows: VBoxContainer
var _status: Label
var _buttons: Dictionary[StringName, Button] = {}


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
	_heading = HudStyle.make_label(26, HudStyle.TEXT_COLOR, "Save")
	column.add_child(_heading)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	column.add_child(_rows)
	for slot: StringName in SaveSlots.slots():
		var button: Button = HudStyle.make_small_button("")
		button.custom_minimum_size = Vector2(WIDTH, 46)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override(&"font_size", 13)
		button.pressed.connect(_on_slot_pressed.bind(slot))
		_rows.add_child(button)
		_buttons[slot] = button
	_status = HudStyle.make_label(12, HudStyle.MUTED_COLOR, "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_child(_status)
	var back: Button = HudStyle.make_small_button("BACK  (Esc)")
	back.custom_minimum_size = Vector2(WIDTH, 36)
	back.pressed.connect(close)
	column.add_child(back)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## Opens for saving (`p_saving`) or loading, with the slots as they are on disk now.
func open(p_saving: bool) -> void:
	saving = p_saving
	_heading.text = "Save" if saving else "Load"
	_status.text = ""
	refresh()
	visible = true
	Events.ui_feedback.emit(&"click")


func close() -> void:
	if not visible:
		return
	visible = false
	Events.ui_feedback.emit(&"click")
	closed.emit()


## Shows how the last save or load went.
func show_status(text: String, failed: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override(
		&"font_color", HudStyle.WARNING_COLOR if failed else HudStyle.MUTED_COLOR
	)


## Re-reads every slot.
func refresh() -> void:
	for slot: StringName in _buttons:
		var button: Button = _buttons[slot]
		var line: String = SaveSlots.label_of(slot).to_upper()
		var usable: bool = false
		if not SaveSlots.exists(slot):
			line += "   —   Empty"
		else:
			var game: SaveGame = SaveSlots.read(slot)
			if game == null:
				line += "   —   " + SaveSlots.last_error
			else:
				usable = true
				line += (
					"   —   %s\n%s played, saved %s"
					% [game.title, format_played(game.seconds), format_date(game.saved_at)]
				)
		button.text = line
		if saving:
			button.disabled = not SaveSlots.writable_slots().has(slot)
		else:
			button.disabled = not usable
	SaveSlots.last_error = ""


## "12:05" or "1:02:05" for `seconds` of play.
static func format_played(seconds: float) -> String:
	var total: int = floori(seconds)
	var hours: int = floori(seconds / 3600.0)
	var minutes: int = floori(seconds / 60.0) % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, total % 60]
	return "%d:%02d" % [minutes, total % 60]


## The local date and time of a Unix time, e.g. "2026-11-13 14:05".
static func format_date(unix: int) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var local: Dictionary = Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return (
		"%04d-%02d-%02d %02d:%02d"
		% [
			local.get("year", 0),
			local.get("month", 0),
			local.get("day", 0),
			local.get("hour", 0),
			local.get("minute", 0),
		]
	)


func _on_slot_pressed(slot: StringName) -> void:
	Events.ui_feedback.emit(&"click")
	slot_chosen.emit(slot, saving)
