class_name SubtitleLine
extends Control
## The Advisor's lines written on screen (`Events.subtitle`): bottom centre, above
## the command card, white on a dark band so it reads over any terrain. One line at a
## time, each for as long as it is spoken (at least MIN_SECONDS); lines that come
## while one shows wait their turn, a repeat of a line already waiting is dropped, and
## when more than MAX_WAITING wait the oldest go (they are stale by then). Off with
## `Settings.subtitles`; `Settings.subtitle_size` picks normal or large text.

const MIN_SECONDS: float = 1.5
const MAX_SECONDS: float = 8.0
const MAX_WAITING: int = 3
## Pixels from the bottom of the screen to the band's bottom: above the command card.
const BOTTOM_GAP: float = 236.0
const FONT_SIZES: Dictionary[StringName, int] = {&"normal": 16, &"large": 22}
## The widest the text runs before it wraps.
const MAX_TEXT_WIDTH: float = 680.0
const BAND := Color(0.02, 0.025, 0.035, 0.78)
const SPEAKERS: Dictionary[StringName, String] = {&"advisor": "ADVISOR"}

## Lines waiting: [speaker, text, seconds].
var _waiting: Array[Array] = []
var _left: float = 0.0
var _band: PanelContainer
var _speaker: Label
var _text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_band = PanelContainer.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BAND
	style.set_corner_radius_all(3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_band.add_theme_stylebox_override(&"panel", style)
	add_child(_band)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	_band.add_child(row)
	_speaker = HudStyle.make_label(12, HudStyle.ACCENT_COLOR)
	_speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_speaker)
	_text = HudStyle.make_label(16, Color.WHITE)
	_text.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_text.add_theme_constant_override(&"outline_size", 4)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_text)
	_band.visible = false
	Events.subtitle.connect(show_line)
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()


func _process(delta: float) -> void:
	advance(delta)


## Queues the line `text` of `speaker`, shown for `seconds` (ignored with subtitles
## off, when empty, or when the same line already shows or waits).
func show_line(speaker: StringName, text: String, seconds: float) -> void:
	if not Settings.subtitles or text.strip_edges() == "":
		return
	if _band.visible and _text.text == text:
		return
	for line: Array in _waiting:
		if line[1] == text:
			return
	_waiting.append([speaker, text, clampf(seconds, MIN_SECONDS, MAX_SECONDS)])
	while _waiting.size() > MAX_WAITING:
		_waiting.pop_front()
	if not _band.visible:
		_next()


## Lets `delta` seconds pass: the line ends when its time is up and the next shows.
func advance(delta: float) -> void:
	if not _band.visible:
		return
	_left -= delta
	if _left <= 0.0:
		_next()


## The line showing ("" when none).
func current_text() -> String:
	return _text.text if _band.visible else ""


## Lines waiting their turn.
func waiting_count() -> int:
	return _waiting.size()


## The font size of the text now.
func font_size() -> int:
	return _text.get_theme_font_size(&"font_size")


## Clears the line showing and every line waiting.
func clear() -> void:
	_waiting.clear()
	_band.visible = false
	_text.text = ""


func _next() -> void:
	if _waiting.is_empty():
		_band.visible = false
		_text.text = ""
		return
	var line: Array = _waiting.pop_front()
	var speaker: StringName = line[0]
	_speaker.text = SPEAKERS.get(speaker, String(speaker).to_upper())
	_text.text = line[1]
	_left = line[2]
	_band.visible = true
	_place.call_deferred()


func _place() -> void:
	var font: Font = _text.get_theme_font(&"font")
	var width: float = (
		font.get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size()).x
	)
	_text.custom_minimum_size.x = minf(ceilf(width) + 2.0, MAX_TEXT_WIDTH)
	_band.reset_size()
	var screen: Vector2 = size
	_band.position = Vector2((screen.x - _band.size.x) * 0.5, screen.y - BOTTOM_GAP - _band.size.y)


func _on_settings_changed() -> void:
	if not Settings.subtitles:
		clear()
	var size_id: StringName = Settings.subtitle_size
	var font: int = FONT_SIZES.get(size_id, FONT_SIZES[&"normal"])
	_text.add_theme_font_size_override(&"font_size", font)
	_speaker.add_theme_font_size_override(&"font_size", font - 4)
	if _band.visible:
		_place.call_deferred()
