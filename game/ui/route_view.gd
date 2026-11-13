class_name RouteView
extends Control
## The campaign route drawn on the star map: one round button per route node at its
## map position (planet icon, or a placeholder), the links to the nodes it leads to,
## each coloured by its state (locked, open, won, closed) and the picked node ringed.

## The mouse moved onto a node (`node_id`), or off every node (&"").
signal node_hovered(node_id: StringName)
## A node was clicked.
signal node_pressed(node_id: StringName)

const NODE_SIZE: float = 56.0
const PLANET_ICON: String = "res://assets/icons/planet_%s.png"

var session: CampaignSession = null

## Node id -> its button.
var _buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)


## Builds the node buttons for `p_session`'s campaign.
func show_session(p_session: CampaignSession) -> void:
	session = p_session
	for child: Node in get_children():
		child.queue_free()
	_buttons.clear()
	if session == null:
		return
	for route_node: RouteNodeDef in session.def.nodes:
		if route_node != null:
			_buttons[route_node.id] = _make_node(route_node)
	refresh()


## Recolours every node and link from the campaign state.
func refresh() -> void:
	if session == null:
		return
	for node_id: StringName in _buttons:
		var button: Button = _buttons[node_id]
		var state: StringName = session.state.node_state(node_id)
		var color: Color = _color(node_id)
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			button.add_theme_stylebox_override(style_name, _node_style(color, style_name))
		button.tooltip_text = ""
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
			if state == CampaignState.NODE_OPEN
			else Control.CURSOR_ARROW
		)
	_layout()
	queue_redraw()


## The button of `node_id` (tests), or null.
func button_of(node_id: StringName) -> Button:
	return _buttons.get(node_id, null)


## Where node `node_id` sits in this control, in pixels.
func node_point(node_id: StringName) -> Vector2:
	var route_node: RouteNodeDef = session.def.node(node_id) if session != null else null
	if route_node == null:
		return Vector2.ZERO
	var inner: Vector2 = size - Vector2(NODE_SIZE, NODE_SIZE) * 2.0
	return Vector2(NODE_SIZE, NODE_SIZE) + route_node.map_position * inner


func _draw() -> void:
	if session == null:
		return
	for route_node: RouteNodeDef in session.def.nodes:
		if route_node == null:
			continue
		var from: Vector2 = node_point(route_node.id)
		for next: StringName in route_node.leads_to:
			if session.def.node(next) == null:
				continue
			var reached: bool = session.state.won.has(route_node.id)
			var color: Color = HudStyle.OPEN_COLOR if reached else HudStyle.LINK_COLOR
			if session.state.node_state(next) == CampaignState.NODE_CLOSED:
				color = Color(HudStyle.LOCKED_COLOR, 0.3)
			draw_line(from, node_point(next), color, 2.0, true)


func _layout() -> void:
	for node_id: StringName in _buttons:
		var button: Button = _buttons[node_id]
		button.position = node_point(node_id) - button.size / 2.0
	queue_redraw()


func _make_node(route_node: RouteNodeDef) -> Button:
	var button := Button.new()
	button.name = String(route_node.id)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	add_child(button)
	var planet_id: String = String(route_node.planet.id) if route_node.planet != null else ""
	var letter: String = route_node.title.substr(0, 1) if route_node.title != "" else "?"
	var icon: Control = HudStyle.make_icon(
		PLANET_ICON % planet_id, NODE_SIZE - 14.0, HudStyle.TEXT_COLOR, letter
	)
	button.add_child(icon)
	icon.position = Vector2(7, 7)
	var caption: Label = HudStyle.make_label(12, HudStyle.TEXT_COLOR, route_node.title)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.custom_minimum_size = Vector2(160, 0)
	button.add_child(caption)
	caption.position = Vector2(NODE_SIZE / 2.0 - 80.0, NODE_SIZE + 4.0)
	if route_node.placeholder:
		var tag: Label = HudStyle.make_label(10, HudStyle.MUTED_COLOR, "PLACEHOLDER")
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.custom_minimum_size = Vector2(160, 0)
		button.add_child(tag)
		tag.position = Vector2(NODE_SIZE / 2.0 - 80.0, NODE_SIZE + 20.0)
	button.mouse_entered.connect(func() -> void: node_hovered.emit(route_node.id))
	button.mouse_exited.connect(func() -> void: node_hovered.emit(&""))
	button.pressed.connect(func() -> void: node_pressed.emit(route_node.id))
	return button


func _color(node_id: StringName) -> Color:
	if session.state.current_node == node_id:
		return HudStyle.CURRENT_COLOR
	return HudStyle.campaign_state_color(session.state.node_state(node_id))


static func _node_style(color: Color, style_name: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill: float = 0.32 if style_name == &"hover" else 0.16
	style.bg_color = Color(color, fill)
	style.border_color = color
	style.set_border_width_all(3 if style_name == &"hover" else 2)
	style.set_corner_radius_all(int(NODE_SIZE / 2.0))
	return style
