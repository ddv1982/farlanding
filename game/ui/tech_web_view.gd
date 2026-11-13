class_name TechWebView
extends HBoxContainer
## The Meridian's tech web (PLAN 1): every TechDef as a card laid out from its grid
## position, links to the techs it requires, each card coloured by its state (locked,
## available, affordable, owned). Hovering or clicking a card shows its details;
## BUY spends banked Intel on it.

## A tech was bought.
signal tech_bought(tech_id: StringName)

const CELL: Vector2 = Vector2(236, 88)
const CARD: Vector2 = Vector2(212, 80)
const ICON_PATH: String = "res://assets/icons/tech_%s.png"
const STATE_NAMES: Dictionary[StringName, String] = {
	&"locked": "LOCKED",
	&"available": "NEED MORE INTEL",
	&"affordable": "AVAILABLE",
	&"owned": "OWNED",
}

var session: CampaignSession = null
## The tech shown in the details panel, or &"".
var shown_tech: StringName = &""

var _web: Control
var _cards: Dictionary[StringName, Button] = {}
var _title: Label
var _state: Label
var _text: Label
var _needs: Label
var _buy: Button


func _ready() -> void:
	add_theme_constant_override(&"separation", 18)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_web = Control.new()
	_web.name = &"Web"
	_web.draw.connect(_draw_links)
	scroll.add_child(_web)
	add_child(_build_details())


## Shows the web of `p_session`.
func show_session(p_session: CampaignSession) -> void:
	session = p_session
	for child: Node in _web.get_children():
		child.queue_free()
	_cards.clear()
	var extent: Vector2 = Vector2.ZERO
	for tech: TechDef in session.def.techs:
		if tech == null:
			continue
		var card: Button = _make_card(tech)
		_cards[tech.id] = card
		extent = extent.max(card.position + CARD)
	_web.custom_minimum_size = extent + Vector2(16, 16)
	refresh()


## Re-reads every card's state and the details panel.
func refresh() -> void:
	if session == null:
		return
	for tech_id: StringName in _cards:
		var card: Button = _cards[tech_id]
		var tech: TechDef = session.def.tech(tech_id)
		var state: StringName = session.state.tech_state(tech_id)
		var color: Color = HudStyle.campaign_state_color(state)
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
			card.add_theme_stylebox_override(style_name, _card_style(color, style_name))
		card.text = "%s\n%s" % [tech.title, _cost_line(tech, state)]
		card.add_theme_color_override(&"font_color", HudStyle.TEXT_COLOR)
	_web.queue_redraw()
	_show(shown_tech)


## Tries to buy `tech_id`; plays the buy or denied feedback. True if bought.
func buy(tech_id: StringName) -> bool:
	if session == null or not session.buy(tech_id):
		Events.ui_feedback.emit(&"tech_denied")
		return false
	Events.ui_feedback.emit(&"tech_buy")
	tech_bought.emit(tech_id)
	refresh()
	return true


## The card of `tech_id` (tests), or null.
func card_of(tech_id: StringName) -> Button:
	return _cards.get(tech_id, null)


func _build_details() -> PanelContainer:
	var panel: PanelContainer = HudStyle.make_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(340, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)
	_title = HudStyle.make_label(22, HudStyle.TEXT_COLOR, "Pick a tech")
	column.add_child(_title)
	_state = HudStyle.make_label(11, HudStyle.ACCENT_COLOR)
	column.add_child(_state)
	_text = HudStyle.make_label(13, HudStyle.TEXT_COLOR)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(310, 0)
	column.add_child(_text)
	_needs = HudStyle.make_label(12, HudStyle.MUTED_COLOR)
	_needs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_needs.custom_minimum_size = Vector2(310, 0)
	column.add_child(_needs)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_buy = HudStyle.make_menu_button("BUY", 300.0)
	_buy.add_theme_color_override(&"font_color", HudStyle.ACCENT_COLOR)
	_buy.pressed.connect(func() -> void: buy(shown_tech))
	column.add_child(_buy)
	return panel


func _make_card(tech: TechDef) -> Button:
	var card: Button = HudStyle.make_small_button(tech.title)
	card.name = String(tech.id)
	card.custom_minimum_size = CARD
	card.size = CARD
	card.position = Vector2(tech.grid) * CELL + Vector2(8, 8)
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_font_size_override(&"font_size", 12)
	card.add_theme_constant_override(&"h_separation", 8)
	card.icon = HudStyle.optional_icon(ICON_PATH % tech.id)
	card.expand_icon = card.icon != null
	card.add_theme_constant_override(&"icon_max_width", 48)
	if card.icon == null:
		var letter: String = tech.branch.substr(0, 1).to_upper()
		var swatch: Control = HudStyle.make_icon("", 30.0, HudStyle.MUTED_COLOR, letter)
		card.add_child(swatch)
		swatch.position = Vector2(CARD.x - 38.0, 8.0)
	card.mouse_entered.connect(_on_card_hovered.bind(tech.id))
	card.pressed.connect(_on_card_pressed.bind(tech.id))
	_web.add_child(card)
	return card


func _draw_links() -> void:
	if session == null:
		return
	for tech: TechDef in session.def.techs:
		if tech == null or not _cards.has(tech.id):
			continue
		var to: Vector2 = _cards[tech.id].position + Vector2(0.0, CARD.y / 2.0)
		for needed: StringName in tech.requires:
			if not _cards.has(needed):
				continue
			var from: Vector2 = _cards[needed].position + Vector2(CARD.x, CARD.y / 2.0)
			var owned: bool = session.state.techs.has(needed)
			var color: Color = HudStyle.WON_COLOR if owned else HudStyle.LINK_COLOR
			_web.draw_line(from, to, color, 2.0, true)


func _show(tech_id: StringName) -> void:
	shown_tech = tech_id
	var tech: TechDef = session.def.tech(tech_id) if session != null else null
	_buy.visible = tech != null
	if tech == null:
		_title.text = "Pick a tech"
		_state.text = "%d Intel banked" % session.state.intel if session != null else ""
		_text.text = "Spend Intel the landings bring home. Techs stay for the whole campaign."
		_needs.text = ""
		return
	var state: StringName = session.state.tech_state(tech_id)
	_title.text = tech.title
	_state.text = (
		"%s  ·  %d Intel  ·  %d banked"
		% [STATE_NAMES.get(state, ""), tech.intel_cost, session.state.intel]
	)
	_text.text = tech.description
	_needs.text = _needs_text(tech)
	_buy.disabled = state != CampaignState.TECH_AFFORDABLE
	_buy.text = (
		"OWNED" if state == CampaignState.TECH_OWNED else "BUY  ·  %d INTEL" % tech.intel_cost
	)


func _needs_text(tech: TechDef) -> String:
	var lines: PackedStringArray = []
	for needed: StringName in tech.requires:
		var other: TechDef = session.def.tech(needed)
		var mark: String = "✓" if session.state.techs.has(needed) else "·"
		lines.append("%s Needs %s" % [mark, other.title if other != null else String(needed)])
	if tech.requires_discovery != &"":
		var found: bool = session.state.discoveries.has(tech.requires_discovery)
		lines.append(
			(
				"%s Needs an Antecedent find: %s"
				% ["✓" if found else "·", LandingBuilder.pretty(tech.requires_discovery)]
			)
		)
	return "\n".join(lines)


static func _cost_line(tech: TechDef, state: StringName) -> String:
	if state == CampaignState.TECH_OWNED:
		return "OWNED"
	if state == CampaignState.TECH_LOCKED:
		return "%d Intel  ·  locked" % tech.intel_cost
	return "%d Intel" % tech.intel_cost


static func _card_style(color: Color, style_name: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		HudStyle.BUTTON_HOVER_COLOR if style_name == &"hover" else HudStyle.BUTTON_COLOR
	)
	style.border_color = color
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	return style


func _on_card_hovered(tech_id: StringName) -> void:
	Events.ui_feedback.emit(&"tech_hover")
	_show(tech_id)


func _on_card_pressed(tech_id: StringName) -> void:
	Events.ui_feedback.emit(&"click")
	_show(tech_id)
