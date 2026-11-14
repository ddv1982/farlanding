extends GutTest
## The menus fit a short window: what lists a variable amount scrolls (vertically
## only), the heading and the buttons stay inside the window, text stays inside its
## card, and Esc leaves the mission select (not while the settings are over it).

const CATALOG: String = "res://data/missions/catalog.tres"
## Short enough that the mission list cannot fit (the default window is 648 high;
## at the largest interface size, 130 %, it shows 498 px of interface).
const SHORT: Vector2i = Vector2i(1152, 420)
const TALL: Vector2i = Vector2i(1152, 2000)

var _guard: SettingsGuard = SettingsGuard.new()
var _saved_size: Vector2i
var _saved_scale: float = 1.0
var _catalog: MissionCatalog


func before_each() -> void:
	_guard.take()
	_saved_size = get_tree().root.size
	_saved_scale = get_tree().root.content_scale_factor
	_catalog = load(CATALOG)


func after_each() -> void:
	get_tree().root.size = _saved_size
	get_tree().root.content_scale_factor = _saved_scale
	_guard.restore()


func test_the_footer_stays_in_a_short_window_and_only_the_cards_scroll() -> void:
	var select: MissionSelect = await _mission_select(SHORT)
	assert_gt(select.card_count(), 7, "enough cards to overflow")
	var view: Rect2 = select.get_viewport_rect()
	for button: Control in select.footer().get_children():
		_assert_inside(button, view, "footer button")
	_assert_inside(select.picker(), view, "difficulty picker")
	var scroll: ScrollContainer = select.card_scroll()
	_assert_inside(scroll, view, "card list")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_true(scroll.get_v_scroll_bar().visible, "the cards scroll")
	assert_false(scroll.get_h_scroll_bar().visible, "never sideways")


func test_the_largest_interface_size_keeps_the_footer_in_view() -> void:
	get_tree().root.content_scale_factor = 1.3
	var select: MissionSelect = await _mission_select(Vector2i(1152, 648))
	var view: Rect2 = select.get_viewport_rect()
	for button: Control in select.footer().get_children():
		_assert_inside(button, view, "footer button at 130 %")


func test_the_mouse_wheel_scrolls_the_cards() -> void:
	var select: MissionSelect = await _mission_select(SHORT)
	var scroll: ScrollContainer = select.card_scroll()
	assert_eq(scroll.scroll_vertical, 0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = scroll.get_global_rect().get_center()
	wheel.global_position = wheel.position
	get_viewport().push_input(wheel)
	var release: InputEventMouseButton = wheel.duplicate()
	release.pressed = false
	get_viewport().push_input(release)
	await wait_physics_frames(2)
	assert_gt(scroll.scroll_vertical, 0, "a wheel over a card scrolls the list")


func test_with_room_to_spare_nothing_scrolls_and_the_column_is_centred() -> void:
	var select: MissionSelect = await _mission_select(TALL)
	var scroll: ScrollContainer = select.card_scroll()
	assert_false(scroll.get_v_scroll_bar().visible)
	var cards: Control = scroll.get_child(0) as Control
	assert_almost_eq(scroll.size.y, cards.get_combined_minimum_size().y, 1.0)
	var column: Control = scroll.get_parent() as Control
	var view: Rect2 = select.get_viewport_rect()
	assert_almost_eq(column.get_global_rect().get_center().y, view.get_center().y, 1.0)
	assert_almost_eq(column.get_global_rect().get_center().x, view.get_center().x, 1.0)


func test_a_long_summary_wraps_inside_its_card() -> void:
	var select: MissionSelect = await _mission_select(TALL)
	var cards: Array[Node] = select.card_scroll().get_child(0).get_children()
	var longest: int = 0
	for i: int in cards.size():
		if _catalog.missions[i].summary.length() > _catalog.missions[longest].summary.length():
			longest = i
	for card: Node in cards:
		var button: Button = card as Button
		var summary: Label = _summary_of(button)
		var card_rect: Rect2 = button.get_global_rect()
		assert_true(
			card_rect.encloses(summary.get_global_rect()), "%s stays in its card" % summary.text
		)
		assert_lte(summary.get_line_count(), 2, "at most two lines: " + summary.text)
		assert_almost_eq(button.size.x, MissionSelect.CARD_WIDTH, 0.5)
	var long_card: Button = cards[longest] as Button
	assert_eq(_summary_of(long_card).get_line_count(), 2, "the longest summary wraps")
	assert_gt(long_card.size.y, MissionSelect.CARD_HEIGHT - 0.5)


func test_a_card_grows_with_a_summary_longer_than_two_lines() -> void:
	var mission: MissionDef = _catalog.missions[0].duplicate() as MissionDef
	mission.summary = "A summary far longer than usual."
	for i: int in 5:
		mission.summary += " It keeps going for another clause or two."
	var catalog := MissionCatalog.new()
	catalog.missions.append(mission)
	var select := MissionSelect.new()
	add_child_autofree(select)
	select.show_catalog(catalog)
	await wait_physics_frames(3)
	var button: Button = select.card_scroll().get_child(0).get_child(0) as Button
	var summary: Label = _summary_of(button)
	assert_gt(summary.get_line_count(), 2)
	assert_gt(button.size.y, MissionSelect.CARD_HEIGHT)
	assert_true(button.get_global_rect().encloses(summary.get_global_rect()))


func test_escape_goes_back_like_the_back_button() -> void:
	var select: MissionSelect = await _mission_select(TALL)
	watch_signals(select)
	_press_escape()
	assert_signal_emit_count(select, "back_pressed", 1)
	select.visible = false
	_press_escape()
	assert_signal_emit_count(select, "back_pressed", 1, "not while hidden")


func test_escape_closes_the_settings_first() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var select := MissionSelect.new()
	parent.add_child(select)
	var settings := SettingsPanel.new()
	parent.add_child(settings)
	await wait_physics_frames(1)
	settings.open()
	watch_signals(select)
	watch_signals(settings)
	_press_escape()
	assert_signal_emit_count(settings, "closed", 1)
	assert_signal_emit_count(select, "back_pressed", 0, "the settings had the Esc")
	assert_false(settings.visible)
	_press_escape()
	assert_signal_emit_count(select, "back_pressed", 1)


func test_every_menu_keeps_its_buttons_in_a_short_window() -> void:
	# The default window at the largest interface size, and a short window at 100 %.
	for setup: Array in [[Vector2i(1152, 648), 1.3], [SHORT, 1.0]]:
		var window: Vector2i = setup[0]
		var scale: float = setup[1]
		get_tree().root.size = window
		get_tree().root.content_scale_factor = scale
		var what: String = "%s at %d %%" % [window, roundi(scale * 100.0)]
		for screen: Control in _screens():
			await wait_physics_frames(3)
			_assert_buttons_inside(screen, "%s, %s" % [screen.name, what])
			screen.queue_free()
		var meridian := MeridianScreen.new()
		meridian.name = &"Meridian"
		add_child_autofree(meridian)
		var session := CampaignSession.new(
			load("res://data/campaign/kessel_trail.tres") as CampaignDef
		)
		session.start_new()
		meridian.open(session)
		for tab: StringName in [
			MeridianScreen.TAB_OVERVIEW, MeridianScreen.TAB_TECH, MeridianScreen.TAB_LOADOUT
		]:
			meridian.show_tab(tab)
			await wait_physics_frames(3)
			_assert_buttons_inside(meridian, "Meridian %s, %s" % [tab, what])
		meridian.queue_free()


## Every menu, opened with its longest content.
func _screens() -> Array[Control]:
	var screens: Array[Control] = []
	var select := MissionSelect.new()
	select.name = &"MissionSelect"
	add_child_autofree(select)
	select.show_catalog(_catalog)
	screens.append(select)
	var title := TitleScreen.new()
	title.name = &"Title"
	add_child_autofree(title)
	title.open(true)
	screens.append(title)
	var briefing := BriefingPanel.new()
	briefing.name = &"Briefing"
	add_child_autofree(briefing)
	var longest: MissionDef = _catalog.missions[0]
	for mission: MissionDef in _catalog.missions:
		if mission.briefing.length() > longest.briefing.length():
			longest = mission
	var carried := PackedStringArray()
	for i: int in 6:
		carried.append("Something the Meridian sends down with the landing, number %d" % i)
	briefing.show_mission(longest, carried)
	screens.append(briefing)
	var debrief := DebriefPanel.new()
	debrief.name = &"Debrief"
	add_child_autofree(debrief)
	var result := MissionResult.new()
	result.title = longest.title
	result.difficulty = Difficulty.NORMAL
	for i: int in 8:
		result.objectives.append(
			{"title": "Objective %d" % i, "kind": &"primary", "state": &"done"}
		)
	debrief.show_result(result, 120)
	screens.append(debrief)
	var ending := EndingScreen.new()
	ending.name = &"Ending"
	add_child_autofree(ending)
	ending.open(null)
	screens.append(ending)
	var settings := SettingsPanel.new()
	settings.name = &"Settings"
	add_child_autofree(settings)
	settings.open()
	screens.append(settings)
	var info := InfoPanel.new()
	info.name = &"Info"
	add_child_autofree(info)
	info.open_how_to_play()
	screens.append(info)
	var slots := SaveLoadPanel.new()
	slots.name = &"SaveLoad"
	add_child_autofree(slots)
	slots.open(true)
	screens.append(slots)
	return screens


## Every shown button of `screen` that is not in a scroll area, and every shown
## scroll area, is inside the window.
func _assert_buttons_inside(screen: Control, what: String) -> void:
	var view: Rect2 = screen.get_viewport_rect()
	var checked: int = 0
	for node: Node in screen.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if not button.is_visible_in_tree() or _in_scroll(button, screen):
			continue
		_assert_inside(button, view, "%s: %s" % [what, button.text])
		checked += 1
	for node: Node in screen.find_children("*", "ScrollContainer", true, false):
		var scroll: ScrollContainer = node as ScrollContainer
		if scroll.is_visible_in_tree() and not _in_scroll(scroll, screen):
			_assert_inside(scroll, view, "%s: scroll area" % what)
			checked += 1
	assert_gt(checked, 0, "%s has something to check" % what)


static func _in_scroll(node: Node, screen: Node) -> bool:
	var parent: Node = node.get_parent()
	while parent != null and parent != screen:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func _mission_select(window: Vector2i) -> MissionSelect:
	get_tree().root.size = window
	var select := MissionSelect.new()
	add_child_autofree(select)
	select.show_catalog(_catalog)
	await wait_physics_frames(3)
	return select


func _summary_of(card: Button) -> Label:
	var text: VBoxContainer = card.get_child(0).get_child(0) as VBoxContainer
	return text.get_child(2) as Label


func _press_escape() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	get_viewport().push_input(key)
	var release: InputEventKey = key.duplicate()
	release.pressed = false
	get_viewport().push_input(release)


func _assert_inside(control: Control, view: Rect2, what: String) -> void:
	var rect: Rect2 = control.get_global_rect()
	assert_true(view.grow(0.5).encloses(rect), "%s %s inside %s" % [what, rect, view])
