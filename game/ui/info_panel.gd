class_name InfoPanel
extends Control
## A page of reading over whatever is behind it: "How to play" (from the title and
## the pause menu; the keys and mouse buttons named are the player's own, for the
## mouse scheme in use) and the credits (from the title and after the ending). Back
## (or Esc) closes it and emits `closed`.

signal closed

const BACKDROP := Color(0.0, 0.0, 0.0, 0.6)
const WIDTH: float = 640.0
## Height of the page of text (it scrolls when longer, and gives up height on a
## short window so Back stays in view).
const HEIGHT: float = 520.0
## Space kept free above and below the panel, px.
const SCREEN_MARGIN: float = 16.0
const PAGE_HOW_TO_PLAY: StringName = &"how_to_play"
const PAGE_CREDITS: StringName = &"credits"
const GAME_NAME: String = "Farlanding"

## The page shown (PAGE_*), or &"" before one was opened.
var page: StringName = &""

var _kicker: Label
var _heading: Label
var _body: Label
var _scroll: ScrollContainer


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
	var column := FitColumn.new(8)
	column.custom_minimum_size = Vector2(WIDTH, 0)
	column.outer_margin = (
		SCREEN_MARGIN * 2 + panel.get_theme_stylebox(&"panel").get_minimum_size().y
	)
	panel.add_child(column)
	_kicker = HudStyle.make_label(11, HudStyle.ACCENT_COLOR, "THE CONCORD SURVEY")
	column.add_child(_kicker)
	_heading = HudStyle.make_label(26, HudStyle.TEXT_COLOR)
	column.add_child(_heading)
	_body = HudStyle.make_label(13, HudStyle.TEXT_COLOR)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = column.add_scroll(_body, HEIGHT)
	_scroll.custom_minimum_size = Vector2(WIDTH, 0)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var back: Button = HudStyle.make_small_button("BACK  (Esc)")
	back.custom_minimum_size = Vector2(120, 32)
	back.pressed.connect(close)
	buttons.add_child(back)
	column.add_child(buttons)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## Opens "How to play" for the mouse scheme in use.
func open_how_to_play() -> void:
	_open(PAGE_HOW_TO_PLAY, "How to play", how_to_play_text(Settings.control_scheme))
	Events.ui_feedback.emit(&"click")


## Opens the credits.
func open_credits() -> void:
	_open(PAGE_CREDITS, "Credits", credits_text())
	Events.ui_feedback.emit(&"credits_open")


func close() -> void:
	if not visible:
		return
	visible = false
	Events.ui_feedback.emit(&"click")
	closed.emit()


## The text shown (tests).
func body_text() -> String:
	return _body.text if _body != null else ""


## "How to play" for `scheme` (Settings.SCHEMES), naming the keys bound now.
static func how_to_play_text(scheme: StringName) -> String:
	var classic: bool = scheme == Settings.SCHEME_CLASSIC
	var command: String = "left-click" if classic else "right-click"
	var deselect: String = "Right-click" if classic else "Left-click empty ground"
	var pan: String = (
		"%s%s%s%s"
		% [
			KeyBindings.label(&"camera_pan_forward_alt"),
			KeyBindings.label(&"camera_pan_left_alt"),
			KeyBindings.label(&"camera_pan_back_alt"),
			KeyBindings.label(&"camera_pan_right_alt"),
		]
	)
	var lines: PackedStringArray = [
		"THE GOAL",
		(
			"You command the Concord survey expedition. Each landing has objectives (top"
			+ " left): the primary ones win it, optional ones bring more. Scan Antecedent"
			+ " sites for Intel, the currency of the Meridian's tech web."
		),
		"",
		"THE CAMERA",
		(
			"Pan with %s or the arrow keys, at the screen edge or by dragging with the" % pan
			+ (
				" middle button. The wheel zooms; %s and %s turn. Left-click the minimap to"
				% [
					KeyBindings.label(&"camera_rotate_left"),
					KeyBindings.label(&"camera_rotate_right")
				]
			)
			+ " look there."
		),
		"",
		"SELECTING AND ORDERS  (%s mouse)" % ("classic" if classic else "modern"),
		(
			"Left-click a unit or building to select it; drag a box round several;"
			+ " double-click selects all of a type. %s to deselect." % deselect
		),
		(
			"With units selected, %s the ground to move, an enemy to attack, an Alloy" % command
			+ " deposit to harvest (Haulers), a signal to scan (Surveyors), a building site"
			+ " to help build (Fabricators). Shift adds to the selection and queues orders;"
			+ " %s stops." % KeyBindings.label(&"order_stop")
		),
		"",
		"BUILDING AND TRAINING",
		(
			"Select a Fabricator, pick a building in the command panel (bottom) and %s" % command
			+ " the ground to place it. Most buildings need a Reactor's power. Select a"
			+ " production building (the Lander first) and click a unit to train it; Alloy"
			+ " is paid up front. With the building selected, %s the ground to set its" % command
			+ " rally point."
		),
		"",
		"ECONOMY",
		(
			"Haulers mine Alloy and carry it to a Refinery or the Lander; they go to work"
			+ " by themselves. Flux comes from vents with a Flux Tap. Intel comes from"
			+ " scans and is banked for the Meridian when a landing is won."
		),
		"",
		"KEYS",
		(
			(
				"Ctrl + a group key (%s-%s) stores a control group, the key recalls it (twice to"
				% [KeyBindings.label(&"control_group_1"), KeyBindings.label(&"control_group_9")]
			)
			+ " centre on it)."
			+ (
				" %s codex  ·  %s all controls  ·  %s quicksave  ·  %s quickload  ·  Esc pause."
				% [
					KeyBindings.label(&"codex"),
					KeyBindings.label(&"controls_help"),
					KeyBindings.label(&"quicksave"),
					KeyBindings.label(&"quickload"),
				]
			)
		),
		(
			"Every key can be changed under Settings > Keys; the mouse scheme under"
			+ " Settings > General."
		),
		"",
		"FIELD NOTES",
		(
			"Notes appear the first time you meet something new. Settings > General >"
			+ " Reset hints shows them all again."
		),
	]
	return "\n".join(lines)


## The credits: the game, its makers, the tools and the notices their licences ask
## for, and where the sound comes from.
static func credits_text() -> String:
	var lines: PackedStringArray = [
		GAME_NAME.to_upper(),
		"Design and development: The Farlanding project",
		"",
		"AUDIO",
		(
			"All sound and music is synthesised by the scripts in audio_src: no samples"
			+ " and no third-party recordings."
		),
		"",
		"MADE WITH",
		"Godot Engine (godotengine.org), MIT licence. The notice it requires follows.",
		(
			"Blender (blender.org), GNU GPL. The models are made by scripts run in"
			+ " Blender; Blender's licence does not extend to what it makes."
		),
		'GUT, the Godot Unit Test framework, by Tom "Butch" Wesley and contributors, MIT licence.',
		"gdtoolkit (gdformat, gdlint), by Pawel Lampe and contributors, MIT licence.",
		(
			"The interface text uses the font built into Godot Engine (Open Sans), SIL"
			+ " Open Font Licence 1.1, among the engine's third-party notices."
		),
		"",
		"GODOT ENGINE LICENCE",
		Engine.get_license_text().strip_edges(),
		"",
		"GODOT ENGINE THIRD-PARTY NOTICES",
		(
			"Godot Engine includes third-party components under their own licences"
			+ " (FreeType, HarfBuzz, ICU, Zstandard and others); their texts ship with"
			+ " the engine and are listed at godotengine.org/license."
		),
	]
	return "\n".join(lines)


func _open(p_page: StringName, heading: String, text: String) -> void:
	page = p_page
	_heading.text = heading
	_body.text = text
	_scroll.scroll_vertical = 0
	visible = true
