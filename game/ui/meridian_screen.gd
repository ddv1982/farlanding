class_name MeridianScreen
extends MenuScreen
## Aboard the Meridian (PLAN 1): the ship's overview (banked Intel, landings made, the
## codex, what the next landing will bring, and the campaign's difficulty, which may
## change here between landings), the tech web and the loadout, as tabs. STAR MAP
## goes back.

signal star_map_pressed
## A tab was shown: TAB_OVERVIEW (&"meridian"), TAB_TECH (&"tech_web") or TAB_LOADOUT
## (&"loadout"), the campaign screen names.
signal tab_shown(tab_id: StringName)

const TAB_OVERVIEW: StringName = &"meridian"
const TAB_TECH: StringName = &"tech_web"
const TAB_LOADOUT: StringName = &"loadout"

var session: CampaignSession = null
## The tab shown: TAB_OVERVIEW, TAB_TECH or TAB_LOADOUT.
var tab: StringName = TAB_OVERVIEW

var _intel: Label
var _pages: Dictionary[StringName, Control] = {}
var _tab_buttons: Dictionary[StringName, Button] = {}
var _overview_text: Label
var _overview: VBoxContainer
var _picker: DifficultyPicker
var _tech: TechWebView
var _loadout: LoadoutView


func _build() -> void:
	var frame: MarginContainer = _make_frame(28)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 14)
	frame.add_child(rows)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 10)
	rows.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(HudStyle.make_label(12, HudStyle.ACCENT_COLOR, "EXPEDITION CARRIER"))
	heading.add_child(HudStyle.make_label(28, HudStyle.TEXT_COLOR, "Meridian"))
	_intel = HudStyle.make_label(16, HudStyle.INTEL_COLOR)
	header.add_child(_intel)
	for entry: Array in [
		[TAB_OVERVIEW, "OVERVIEW"], [TAB_TECH, "TECH WEB"], [TAB_LOADOUT, "LOADOUT"]
	]:
		var tab_id: StringName = entry[0]
		var tab_text: String = entry[1]
		var button: Button = HudStyle.make_menu_button(tab_text, 130.0)
		button.pressed.connect(show_tab.bind(tab_id))
		header.add_child(button)
		_tab_buttons[tab_id] = button
	var back: Button = HudStyle.make_menu_button("STAR MAP", 130.0)
	back.pressed.connect(_on_back)
	header.add_child(back)
	var body := PanelContainer.new()
	body.add_theme_stylebox_override(&"panel", HudStyle.panel_style())
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(body)
	_overview = VBoxContainer.new()
	_overview.add_theme_constant_override(&"separation", 14)
	_overview_text = HudStyle.make_label(14, HudStyle.TEXT_COLOR)
	_overview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overview_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overview.add_child(_overview_text)
	_picker = DifficultyPicker.new()
	_picker.chosen.connect(_on_difficulty_chosen)
	_overview.add_child(_picker)
	_tech = TechWebView.new()
	_tech.name = &"TechWeb"
	_tech.tech_bought.connect(func(_id: StringName) -> void: _refresh_header())
	_loadout = LoadoutView.new()
	_loadout.name = &"Loadout"
	for page: Array in [[TAB_OVERVIEW, _overview], [TAB_TECH, _tech], [TAB_LOADOUT, _loadout]]:
		var page_id: StringName = page[0]
		var control: Control = page[1]
		body.add_child(control)
		_pages[page_id] = control


## Shows the Meridian of `p_session` on the overview.
func open(p_session: CampaignSession) -> void:
	session = p_session
	_tech.show_session(session)
	_loadout.show_session(session)
	visible = true
	show_tab(TAB_OVERVIEW)


## Switches to `tab_id` (TAB_OVERVIEW, TAB_TECH or TAB_LOADOUT); `tab_shown` tells Main.
func show_tab(tab_id: StringName) -> void:
	if not _pages.has(tab_id):
		return
	tab = tab_id
	for page_id: StringName in _pages:
		_pages[page_id].visible = page_id == tab_id
		_tab_buttons[page_id].add_theme_color_override(
			&"font_color", HudStyle.ACCENT_COLOR if page_id == tab_id else HudStyle.TEXT_COLOR
		)
	_refresh_header()
	match tab_id:
		TAB_TECH:
			_tech.refresh()
			Events.ui_feedback.emit(&"tech_open")
		TAB_LOADOUT:
			_loadout.refresh()
			Events.ui_feedback.emit(&"loadout_open")
		_:
			_overview_text.text = overview_text()
			if session != null:
				_picker.set_level(session.state.difficulty)
			Events.ui_feedback.emit(&"click")
	tab_shown.emit(tab_id)


## The tech web page (tests).
func tech_web() -> TechWebView:
	return _tech


## The loadout page (tests).
func loadout() -> LoadoutView:
	return _loadout


## The overview: landings, codex, techs, and what the next landing starts with.
func overview_text() -> String:
	if session == null:
		return ""
	var state: CampaignState = session.state
	var lines: PackedStringArray = []
	lines.append(
		(
			"Landings surveyed: %d    Techs owned: %d / %d    Codex entries: %d"
			% [
				state.won.size(),
				state.techs.size(),
				session.def.techs.size(),
				state.discoveries.size()
			]
		)
	)
	lines.append("")
	lines.append("NEXT LANDING STARTS WITH")
	var preview: LandingModifiers = LandingBuilder.build(
		session.def, LandingPlan.from_state(state, state.current_node)
	)
	if preview.notes.is_empty():
		lines.append("·  The standard crew and stores.")
	for note: String in preview.notes:
		lines.append("·  " + note)
	var locked: PackedStringArray = []
	for id: StringName in preview.perks.locked:
		locked.append(LandingBuilder.pretty(id))
	if not locked.is_empty():
		lines.append("·  Not cleared yet: " + ", ".join(locked))
	return "\n".join(lines)


## The difficulty choice (tests).
func picker() -> DifficultyPicker:
	return _picker


func _on_difficulty_chosen(level: StringName) -> void:
	if session != null:
		session.set_difficulty(level)
		Settings.set_option(&"difficulty", level)
		_picker.set_level(session.state.difficulty)


func _refresh_header() -> void:
	if session != null:
		_intel.text = "%d Intel banked" % session.state.intel


func _on_back() -> void:
	Events.ui_feedback.emit(&"click")
	star_map_pressed.emit()
