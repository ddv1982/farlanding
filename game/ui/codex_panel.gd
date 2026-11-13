class_name CodexPanel
extends PanelContainer
## The codex: every discovery the player has made, newest first, with its codex
## text. A list of titles on the left, the chosen entry on the right. Opened and
## closed from the HUD (button or C). Fills from the Discovery system when it opens
## and from `Events.codex_entry_added` while the mission runs.

## Type label and colour per discovery type.
const TYPE_NAMES: Dictionary[StringName, String] = {
	DiscoveryDef.GEOLOGICAL: "GEOLOGICAL",
	DiscoveryDef.BIOLOGICAL: "BIOLOGICAL",
	DiscoveryDef.ANTECEDENT: "ANTECEDENT",
	DiscoveryDef.ENEMY: "ENEMY",
}
const EMPTY_TEXT: String = (
	"No entries yet.\n\n" + "Select a Surveyor and click a ? on the map to scan it."
)

var _entries: Array[DiscoveryDef] = []
var _list: ItemList
var _title: Label
var _type: Label
var _text: Label


func _init() -> void:
	add_theme_stylebox_override(&"panel", HudStyle.panel_style())
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(620, 340)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading: Label = HudStyle.make_label(13, HudStyle.ACCENT_COLOR, "CODEX")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close: Button = HudStyle.make_small_button("Close  (C)")
	close.pressed.connect(close_panel)
	header.add_child(close)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(210, 0)
	_list.focus_mode = Control.FOCUS_NONE
	_list.add_theme_font_size_override(&"font_size", 12)
	_list.add_theme_color_override(&"font_color", HudStyle.TEXT_COLOR)
	_list.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_list.item_selected.connect(_show_entry)
	row.add_child(_list)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override(&"separation", 6)
	row.add_child(page)
	_type = HudStyle.make_label(11, HudStyle.MUTED_COLOR)
	page.add_child(_type)
	_title = HudStyle.make_label(18, HudStyle.TEXT_COLOR)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_title)
	_text = HudStyle.make_label(13, HudStyle.TEXT_COLOR)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(360, 0)
	page.add_child(_text)
	visible = false
	Events.codex_entry_added.connect(_on_entry_added)


## Shows the panel with `entries` (oldest first, as the Discovery system keeps them).
func open_panel(entries: Array[DiscoveryDef]) -> void:
	_entries = entries.duplicate()
	_rebuild()
	visible = true
	Events.ui_feedback.emit(&"codex_open")


func close_panel() -> void:
	if not visible:
		return
	visible = false
	Events.ui_feedback.emit(&"codex_close")


func entry_count() -> int:
	return _entries.size()


func _on_entry_added(entry: Resource) -> void:
	var def: DiscoveryDef = entry as DiscoveryDef
	if def == null or _entries.has(def):
		return
	_entries.append(def)
	if visible:
		_rebuild()


func _rebuild() -> void:
	_list.clear()
	for i: int in range(_entries.size() - 1, -1, -1):
		var def: DiscoveryDef = _entries[i]
		var index: int = _list.add_item(_title_of(def))
		_list.set_item_custom_fg_color(index, def.color.lerp(HudStyle.TEXT_COLOR, 0.35))
		_list.set_item_metadata(index, i)
	if _entries.is_empty():
		_type.text = ""
		_title.text = "Nothing found yet"
		_text.text = EMPTY_TEXT
		return
	_list.select(0)
	_show_entry(0)


func _show_entry(index: int) -> void:
	var entry_index: int = _list.get_item_metadata(index)
	var def: DiscoveryDef = _entries[entry_index]
	_type.text = "%s  ·  %s" % [TYPE_NAMES.get(def.discovery_type, "UNKNOWN"), def.display_name]
	_type.add_theme_color_override(&"font_color", def.color)
	_title.text = _title_of(def)
	_text.text = def.codex_text


static func _title_of(def: DiscoveryDef) -> String:
	return def.codex_title if def.codex_title != "" else def.display_name
