class_name StarMap
extends MenuScreen
## Aboard the Meridian: the star map (PLAN 1). The route of landings with their
## states; hovering a node shows its orbital scan (planet, its rule, mission type,
## the `?` signals the scan charted), clicking an open node picks it and LAUNCH goes
## to its briefing. MERIDIAN opens the tech web and loadout.

## LAUNCH on the picked node.
signal launch_pressed(node_id: StringName)
signal meridian_pressed
signal title_pressed

const STATE_NAMES: Dictionary[StringName, String] = {
	&"locked": "OUT OF RANGE",
	&"open": "OPEN",
	&"won": "SURVEYED",
	&"closed": "ROUTE NOT TAKEN",
}

var session: CampaignSession = null
## The node whose scan is shown (hovered, else picked), or &"".
var shown_node: StringName = &""

var _route: RouteView
var _intel: Label
var _scan_title: Label
var _scan_planet: Label
var _scan_rule: Label
var _scan_mission: Label
var _scan_signals: Label
var _scan_text: Label
var _scan_notes: Label
var _scan_state: Label
var _launch: Button


func _build() -> void:
	var frame: MarginContainer = _make_frame(28)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 14)
	frame.add_child(rows)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 14)
	rows.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(HudStyle.make_label(12, HudStyle.ACCENT_COLOR, "THE MERIDIAN  ·  STAR MAP"))
	heading.add_child(HudStyle.make_label(28, HudStyle.TEXT_COLOR, "The Kessel Trail"))
	_intel = HudStyle.make_label(16, HudStyle.INTEL_COLOR)
	header.add_child(_intel)
	var meridian: Button = HudStyle.make_menu_button("MERIDIAN", 150.0)
	meridian.pressed.connect(_on_meridian)
	header.add_child(meridian)
	var title: Button = HudStyle.make_menu_button("TITLE", 110.0)
	title.pressed.connect(_on_title)
	header.add_child(title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 18)
	rows.add_child(body)
	_route = RouteView.new()
	_route.name = &"Route"
	_route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_route)
	_route.node_hovered.connect(_on_node_hovered)
	_route.node_pressed.connect(pick)
	body.add_child(_build_scan_panel())


## Shows the map of `p_session`.
func open(p_session: CampaignSession) -> void:
	session = p_session
	_route.show_session(session)
	visible = true
	refresh()
	Events.ui_feedback.emit(&"map_open")


## Re-reads the campaign state (Intel, node states, the picked node).
func refresh() -> void:
	if session == null:
		return
	_intel.text = "%d Intel banked" % session.state.intel
	_route.refresh()
	_show_scan(session.state.current_node)


## Picks `node_id` if it is open. Returns true if it was picked.
func pick(node_id: StringName) -> bool:
	if session == null or not session.select(node_id):
		return false
	Events.ui_feedback.emit(&"map_node_select")
	refresh()
	return true


## The route view (tests).
func route() -> RouteView:
	return _route


func _build_scan_panel() -> PanelContainer:
	var panel: PanelContainer = HudStyle.make_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(360, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)
	column.add_child(HudStyle.make_label(11, HudStyle.MUTED_COLOR, "ORBITAL SCAN"))
	_scan_title = HudStyle.make_label(24, HudStyle.TEXT_COLOR, "Pick a landing")
	column.add_child(_scan_title)
	_scan_state = HudStyle.make_label(11, HudStyle.ACCENT_COLOR)
	column.add_child(_scan_state)
	_scan_planet = HudStyle.make_label(15, HudStyle.TEXT_COLOR)
	column.add_child(_scan_planet)
	_scan_rule = _wrapped(13, HudStyle.MUTED_COLOR)
	column.add_child(_scan_rule)
	_scan_mission = HudStyle.make_label(13, HudStyle.TEXT_COLOR)
	column.add_child(_scan_mission)
	_scan_signals = HudStyle.make_label(13, HudStyle.INTEL_COLOR)
	column.add_child(_scan_signals)
	_scan_text = _wrapped(13, HudStyle.TEXT_COLOR)
	column.add_child(_scan_text)
	_scan_notes = _wrapped(12, HudStyle.MUTED_COLOR)
	column.add_child(_scan_notes)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_launch = HudStyle.make_menu_button("LAUNCH", 320.0)
	_launch.add_theme_color_override(&"font_color", HudStyle.ACCENT_COLOR)
	_launch.pressed.connect(_on_launch)
	column.add_child(_launch)
	return panel


func _show_scan(node_id: StringName) -> void:
	shown_node = node_id
	var picked: StringName = session.state.current_node if session != null else &""
	_launch.disabled = (
		picked == &"" or session.state.node_state(picked) != CampaignState.NODE_OPEN
	)
	_launch.text = "LAUNCH" if not _launch.disabled else "PICK AN OPEN LANDING"
	var route_node: RouteNodeDef = session.def.node(node_id) if session != null else null
	for label: Label in [
		_scan_planet, _scan_rule, _scan_mission, _scan_signals, _scan_text, _scan_notes
	]:
		label.visible = route_node != null
	_scan_state.visible = route_node != null
	if route_node == null:
		_scan_title.text = "Pick a landing"
		return
	_scan_title.text = route_node.title
	_scan_state.text = STATE_NAMES.get(session.state.node_state(node_id), "")
	if route_node.placeholder:
		_scan_state.text += "  ·  PLACEHOLDER LANDING"
	var planet: PlanetDef = route_node.planet
	_scan_planet.text = planet.display_name if planet != null else "Unknown world"
	_scan_rule.text = _rule_text(planet)
	var mission: MissionDef = route_node.mission
	_scan_mission.text = (
		"%s  ·  %s" % [MissionSelect.type_name(mission), mission.title] if mission != null else ""
	)
	_scan_signals.text = _signals_text(mission)
	_scan_text.text = route_node.scan_summary
	_scan_notes.text = route_node.intel_notes


func _signals_text(mission: MissionDef) -> String:
	var sites: Array[DiscoveryDef] = OrbitalScan.charted_sites(mission)
	var known: int = 0
	for site: DiscoveryDef in sites:
		if session.state.discoveries.has(site.id):
			known += 1
	var text: String = "%d unresolved ? signals" % sites.size()
	if known > 0:
		text += "  (%d match codex entries)" % known
	return text


static func _rule_text(planet: PlanetDef) -> String:
	if planet == null:
		return ""
	var lines: PackedStringArray = []
	if planet.summary != "":
		lines.append(planet.summary)
	if planet.rule != null and planet.rule.summary != "":
		lines.append("Rule: " + planet.rule.summary)
	elif planet.rule == null:
		lines.append("Rule: none surveyed yet.")
	return "\n".join(lines)


static func _wrapped(font_size: int, color: Color) -> Label:
	var label: Label = HudStyle.make_label(font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(330, 0)
	return label


func _on_node_hovered(node_id: StringName) -> void:
	if session == null:
		return
	if node_id != &"":
		Events.ui_feedback.emit(&"map_node_hover")
		_show_scan(node_id)
	else:
		_show_scan(session.state.current_node)


func _on_launch() -> void:
	if session == null or _launch.disabled:
		return
	Events.ui_feedback.emit(&"map_launch")
	launch_pressed.emit(session.state.current_node)


func _on_meridian() -> void:
	Events.ui_feedback.emit(&"click")
	meridian_pressed.emit()


func _on_title() -> void:
	Events.ui_feedback.emit(&"click")
	title_pressed.emit()
