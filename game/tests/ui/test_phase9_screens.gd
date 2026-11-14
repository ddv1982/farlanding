extends GutTest
## Phase 9 player-facing systems: the difficulty the player chooses (where it is
## picked, where it is stored, what it changes), the team colour palettes, the
## subtitle line, the settings tabs and the KEYS page, How to play and the credits,
## and the minimap's right click per mouse scheme.

const CAMPAIGN: String = "res://data/campaign/kessel_trail.tres"
const SAVE: String = "user://test_phase9_campaign.json"
const CONQUEST: MissionDef = preload("res://data/missions/conquest.tres")

var _guard: SettingsGuard = SettingsGuard.new()
var _saved_default: String = ""


func before_each() -> void:
	_guard.take()
	_saved_default = CampaignSession.default_path
	CampaignSession.default_path = SAVE


func after_each() -> void:
	_guard.restore()
	CampaignSession.default_path = _saved_default
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_the_choice_shifts_the_designed_level_by_one_step() -> void:
	assert_eq(Difficulty.effective(Difficulty.EASY, Difficulty.NORMAL), Difficulty.EASY)
	assert_eq(Difficulty.effective(Difficulty.NORMAL, Difficulty.HARD), Difficulty.HARD)
	assert_eq(Difficulty.effective(Difficulty.NORMAL, Difficulty.EASY), Difficulty.EASY)
	assert_eq(Difficulty.effective(Difficulty.HARD, Difficulty.HARD), Difficulty.HARD)
	assert_eq(Difficulty.effective(Difficulty.EASY, Difficulty.EASY), Difficulty.EASY)
	assert_eq(Difficulty.effective(Difficulty.HARD, &""), Difficulty.HARD, "as designed")
	assert_eq(Difficulty.sanitize("nonsense"), Difficulty.NORMAL)
	assert_eq(Difficulty.sanitize(null), Difficulty.NORMAL)


func test_every_level_picks_the_commanders_own_resource() -> void:
	var mission: MissionDef = CONQUEST
	var profile: CommanderProfile = mission.commander_profile
	for level: StringName in Difficulty.LEVELS:
		assert_eq(profile.difficulty(level).id, level, String(level))


func test_the_campaign_stores_the_difficulty_and_its_saves_carry_it() -> void:
	var def: CampaignDef = load(CAMPAIGN)
	var session: CampaignSession = CampaignSession.new(def)
	session.start_new()
	assert_eq(session.state.difficulty, Difficulty.NORMAL)
	assert_true(session.set_difficulty(Difficulty.HARD))
	assert_false(session.set_difficulty(&"impossible"))
	var loaded: CampaignSession = CampaignSession.new(def)
	assert_true(loaded.load_quietly())
	assert_eq(loaded.state.difficulty, Difficulty.HARD)
	var plan: LandingPlan = LandingPlan.from_state(loaded.state, def.start_node)
	assert_eq(plan.difficulty, Difficulty.HARD)
	var copy: LandingPlan = LandingPlan.from_dict(plan.to_dict())
	assert_eq(copy.difficulty, Difficulty.HARD)
	assert_eq(LandingBuilder.build(def, copy).difficulty, Difficulty.HARD)


func test_an_old_campaign_save_plays_on_normal() -> void:
	var def: CampaignDef = load(CAMPAIGN)
	var data: Dictionary = CampaignState.new(def).to_dict()
	data.erase("difficulty")
	assert_eq(CampaignState.from_dict(data, def).difficulty, Difficulty.NORMAL)
	var mission: MissionDef = CONQUEST
	var game: Dictionary = SaveGame.capture(mission, _landing(), 1.0, null).to_dict()
	game.erase("difficulty")
	assert_eq(SaveGame.from_dict(game).difficulty, Difficulty.NORMAL)


func test_a_single_mission_save_keeps_its_difficulty() -> void:
	var mission: MissionDef = CONQUEST
	var game: SaveGame = SaveGame.capture(mission, _landing(), 12.0, null, Difficulty.EASY)
	var copy: SaveGame = SaveGame.from_dict(game.to_dict())
	assert_eq(copy.difficulty, Difficulty.EASY)
	assert_eq(Main.single_modifiers(copy.difficulty).difficulty, Difficulty.EASY)


func test_the_mission_plays_its_commander_at_the_shifted_level() -> void:
	var mission: Mission = autofree(Mission.new())
	mission.def = CONQUEST
	mission.modifiers = Main.single_modifiers(Difficulty.HARD)
	var designed: StringName = StringName(mission.def.enemy_difficulty)
	assert_eq(mission.commander_level(), Difficulty.effective(designed, Difficulty.HARD))
	mission.modifiers = null
	assert_eq(mission.commander_level(), Difficulty.sanitize(designed))


func test_the_picker_reports_and_marks_the_choice_without_colour_alone() -> void:
	var picker: DifficultyPicker = DifficultyPicker.new()
	add_child_autofree(picker)
	watch_signals(picker)
	picker.button_for(Difficulty.HARD).pressed.emit()
	assert_signal_emitted_with_parameters(picker, "chosen", [Difficulty.HARD])
	assert_true(picker.button_for(Difficulty.HARD).text.begins_with("»"))
	assert_false(picker.button_for(Difficulty.EASY).text.begins_with("»"))


func test_the_title_asks_for_the_difficulty_of_a_new_campaign() -> void:
	var title: TitleScreen = TitleScreen.new()
	add_child_autofree(title)
	title.open(false)
	title.show_new_campaign()
	title.picker().button_for(Difficulty.EASY).pressed.emit()
	assert_eq(Settings.difficulty, Difficulty.EASY, "remembered for next time")


func test_the_meridian_changes_the_difficulty_between_landings() -> void:
	var def: CampaignDef = load(CAMPAIGN)
	var session: CampaignSession = CampaignSession.new(def)
	session.start_new()
	var meridian: MeridianScreen = MeridianScreen.new()
	add_child_autofree(meridian)
	meridian.open(session)
	meridian.picker().button_for(Difficulty.HARD).pressed.emit()
	assert_eq(session.state.difficulty, Difficulty.HARD)


func test_debrief_and_ending_show_the_difficulty() -> void:
	var debrief: DebriefPanel = DebriefPanel.new()
	add_child_autofree(debrief)
	var result: MissionResult = MissionResult.new()
	result.title = "A landing"
	result.difficulty = Difficulty.HARD
	debrief.show_result(result)
	var texts: PackedStringArray = []
	for child: Node in debrief._stats.get_children():
		var label: Label = child as Label
		if label != null:
			texts.append(label.text)
	assert_has(texts, "Hard")
	var def: CampaignDef = load(CAMPAIGN)
	var state: CampaignState = CampaignState.new(def)
	state.difficulty = Difficulty.EASY
	assert_string_contains(EndingScreen.stats_text(state), "Difficulty  Easy")


func test_palettes_differ_in_brightness_as_well_as_hue() -> void:
	for palette: StringName in TeamColors.PALETTES:
		var colors: Array = TeamColors.PALETTES[palette]
		var player_color: Color = colors[TeamColors.PLAYER]
		var hostile_color: Color = colors[TeamColors.HOSTILE]
		var player: float = TeamColors.luminance(player_color)
		var hostile: float = TeamColors.luminance(hostile_color)
		if palette != &"default":
			assert_gt(
				absf(player - hostile), 0.1, "%s: player and enemy differ in luminance" % palette
			)
		assert_true(TeamColors.LABELS.has(palette))
		assert_true(TeamColors.SHOTS.has(palette))
		assert_true(TeamColors.MARKERS.has(palette))
	assert_eq(TeamColors.PALETTES.size(), Settings.PALETTES.size())


func test_team_colours_follow_the_setting() -> void:
	Settings.set_option(&"colour_palette", Settings.PALETTE_RED_GREEN)
	assert_eq(TeamColors.for_faction(TeamColors.HOSTILE), TeamColors.PALETTES[&"red_green"][1])
	assert_eq(TeamColors.shot_color(TeamColors.HOSTILE), TeamColors.SHOTS[&"red_green"][1])
	Settings.set_option(&"colour_palette", Settings.PALETTE_DEFAULT)
	assert_eq(TeamColors.for_faction(TeamColors.HOSTILE), TeamColors.PALETTES[&"default"][1])


func test_subtitles_queue_drop_repeats_and_follow_the_settings() -> void:
	Settings.subtitles = true
	Settings.subtitle_size = &"normal"
	var line: SubtitleLine = SubtitleLine.new()
	add_child_autofree(line)
	Events.subtitle.emit(&"advisor", "Contact.", 2.0)
	Events.subtitle.emit(&"advisor", "Deposit depleted.", 2.0)
	Events.subtitle.emit(&"advisor", "Deposit depleted.", 2.0)
	assert_eq(line.current_text(), "Contact.")
	assert_eq(line.waiting_count(), 1, "a repeat is dropped")
	line.advance(2.1)
	assert_eq(line.current_text(), "Deposit depleted.")
	line.advance(2.1)
	assert_eq(line.current_text(), "")
	for index: int in 6:
		line.show_line(&"advisor", "Line %d" % index, 3.0)
	assert_eq(line.waiting_count(), SubtitleLine.MAX_WAITING, "old lines go")
	Settings.set_option(&"subtitle_size", &"large")
	assert_eq(line.font_size(), SubtitleLine.FONT_SIZES[&"large"])
	Settings.set_option(&"subtitles", false)
	assert_eq(line.current_text(), "", "off clears the line")
	line.show_line(&"advisor", "Unheard.", 2.0)
	assert_eq(line.current_text(), "")


func test_settings_tabs_and_the_keys_page() -> void:
	Settings.set_control_scheme(Settings.SCHEME_CLASSIC)
	var panel: SettingsPanel = SettingsPanel.new()
	add_child_autofree(panel)
	panel.open()
	assert_eq(panel.tab, SettingsPanel.TAB_GENERAL)
	panel.show_tab(SettingsPanel.TAB_KEYS)
	var keys: KeyBindingsPage = panel.keys_page()
	assert_true(keys.is_visible_in_tree())
	keys.listen(&"codex")
	assert_eq(keys.button_for(&"codex").text, "PRESS A KEY…")
	keys.press_key(_key(KEY_F9))
	assert_string_contains(keys.status_text(), "Quickload")
	assert_eq(KeyBindings.label(&"codex"), "C", "a clash changes nothing yet")
	keys.press_key(_key(KEY_F9))
	assert_eq(KeyBindings.label(&"codex"), "F9", "pressed again: swapped")
	assert_eq(KeyBindings.label(&"quickload"), "C")
	assert_eq(keys.listening, &"")
	keys.reset_to_defaults()
	assert_eq(keys.button_for(&"codex").text, "C")
	panel.show_tab(SettingsPanel.TAB_ACCESS)
	panel._palette.item_selected.emit(2)
	assert_eq(Settings.colour_palette, Settings.PALETTES[2])


func test_how_to_play_and_credits() -> void:
	var info: InfoPanel = InfoPanel.new()
	add_child_autofree(info)
	info.open_how_to_play()
	assert_true(info.visible)
	for topic: String in ["THE CAMERA", "SELECTING", "BUILDING", "ECONOMY", "KEYS"]:
		assert_string_contains(info.body_text(), topic)
	assert_string_contains(
		InfoPanel.how_to_play_text(Settings.SCHEME_MODERN), "right-click the ground"
	)
	assert_string_contains(
		InfoPanel.how_to_play_text(Settings.SCHEME_CLASSIC), "left-click the ground"
	)
	info.open_credits()
	var credits: String = info.body_text()
	for part: String in ["FARLANDING", "The Farlanding project", "Godot Engine", "Blender", "GUT"]:
		assert_string_contains(credits, part)
	assert_string_contains(credits, "gdtoolkit")
	assert_string_contains(credits, "no samples")
	assert_string_contains(credits, "Permission is hereby granted", "Godot's licence text")
	assert_false(credits.contains("@"), "no email addresses")
	watch_signals(info)
	info.close()
	assert_signal_emitted(info, "closed")


func test_the_minimap_right_click_follows_the_scheme() -> void:
	assert_false(Minimap.right_click_orders(Settings.SCHEME_CLASSIC))
	assert_true(Minimap.right_click_orders(Settings.SCHEME_MODERN))


func test_every_targeted_order_has_its_own_hover_cursor() -> void:
	var seen: Array[StringName] = []
	for action: StringName in SelectionController.CURSOR_FOR_ACTION:
		var kind: StringName = SelectionController.CURSOR_FOR_ACTION[action]
		assert_false(seen.has(kind), "%s shares a cursor" % action)
		seen.append(kind)
		assert_false(CursorIcons.build_image(kind).is_invisible(), String(kind))


## The least landing snapshot a save accepts.
static func _landing() -> Dictionary:
	return {"world": {"version": 1}}


static func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event
