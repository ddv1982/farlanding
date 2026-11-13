class_name LoadoutView
extends VBoxContainer
## The loadout for the next landing: one row per slot, one button per option. Options
## whose techs are not owned yet show why and cannot be picked.

var session: CampaignSession = null

var _rows: VBoxContainer
## "<slot>/<option>" -> its button.
var _buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	add_theme_constant_override(&"separation", 12)
	add_child(
		HudStyle.make_label(
			13,
			HudStyle.MUTED_COLOR,
			"What the Lander carries down besides the mission's own crew. Applied at every launch."
		)
	)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 16)
	add_child(_rows)


## Shows the slots of `p_session`.
func show_session(p_session: CampaignSession) -> void:
	session = p_session
	for child: Node in _rows.get_children():
		child.queue_free()
	_buttons.clear()
	for slot: LoadoutSlotDef in session.def.loadout_slots:
		if slot != null:
			_rows.add_child(_make_slot(slot))
	refresh()


## Re-reads which options are picked and which can be.
func refresh() -> void:
	if session == null:
		return
	for slot: LoadoutSlotDef in session.def.loadout_slots:
		if slot == null:
			continue
		var picked: LoadoutOptionDef = session.state.loadout_option(slot.id)
		for option: LoadoutOptionDef in slot.options:
			var button: Button = _buttons.get(_key(slot.id, option.id), null)
			if button == null:
				continue
			var allowed: bool = session.state.can_choose(slot.id, option.id)
			button.disabled = not allowed
			var chosen: bool = picked == option
			button.add_theme_color_override(
				&"font_color", HudStyle.ACCENT_COLOR if chosen else HudStyle.TEXT_COLOR
			)
			var mark: String = "●  " if chosen else ""
			var lock: String = "" if allowed else "\nneeds " + _tech_names(option)
			button.text = "%s%s\n%s%s" % [mark, option.title, option.description, lock]


## Picks `option_id` for `slot_id`. True if it was allowed.
func choose(slot_id: StringName, option_id: StringName) -> bool:
	if session == null or not session.choose_loadout(slot_id, option_id):
		Events.ui_feedback.emit(&"invalid")
		return false
	Events.ui_feedback.emit(&"loadout_change")
	refresh()
	return true


## The button of an option (tests), or null.
func button_of(slot_id: StringName, option_id: StringName) -> Button:
	return _buttons.get(_key(slot_id, option_id), null)


func _make_slot(slot: LoadoutSlotDef) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	column.add_child(HudStyle.make_label(12, HudStyle.ACCENT_COLOR, slot.title.to_upper()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	column.add_child(row)
	for option: LoadoutOptionDef in slot.options:
		if option == null:
			continue
		var button: Button = HudStyle.make_small_button(option.title)
		button.custom_minimum_size = Vector2(230, 84)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_color_override(&"font_disabled_color", HudStyle.LOCKED_COLOR)
		button.pressed.connect(func() -> void: choose(slot.id, option.id))
		row.add_child(button)
		_buttons[_key(slot.id, option.id)] = button
	return column


func _tech_names(option: LoadoutOptionDef) -> String:
	var names: PackedStringArray = []
	for tech_id: StringName in option.requires_tech:
		var tech: TechDef = session.def.tech(tech_id)
		names.append(tech.title if tech != null else String(tech_id))
	return ", ".join(names)


static func _key(slot_id: StringName, option_id: StringName) -> StringName:
	return StringName("%s/%s" % [slot_id, option_id])
