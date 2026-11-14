class_name Main
extends Node
## The game's flow (PLAN 1, 2.6; Phases 5 to 9). The title screen offers Continue,
## New campaign (after a difficulty choice), Single missions, How to play, Settings,
## Credits and Quit. How to play and the credits are an InfoPanel over any screen;
## the Advisor's subtitles (SubtitleLine) sit under every menu.
##
## Difficulty (Difficulty): a new campaign takes the one chosen on the title and keeps
## it in its state (the Meridian may change it); a single mission is played at the one
## chosen on the mission list, carried in its LandingModifiers and its saves. Single
## missions also run at the game speed of the settings; campaign landings at 1.
##
## Campaign (ADR 0012): the star map (pick an open landing, LAUNCH) and the Meridian
## (overview, tech web, loadout), then the landing's briefing, the mission and the
## debrief; the result is written into the campaign (and autosaved) as the mission
## ends, and Back returns to the star map. Main owns the CampaignSession; the mission
## only sees the LandingModifiers built from it.
##
## Single missions: the mission select, briefing, mission and debrief with Retry and
## Back to missions, as before.
##
## The pause menu (Esc or the HUD's MENU: Resume, Save, Load, Settings, Restart,
## Quit; the sim clock and the camera stop) quits to the star map in a campaign and to
## the mission select otherwise.
##
## When the campaign's last landing is won (ADR 0017), Back from the debrief opens the
## ending screen, which returns to the title; Continue on a finished campaign opens it
## again.
##
## Saved landings (ADR 0013): the quicksave and quickload keys (F5 and F9 unless
## rebound) work in a mission, the pause
## menu saves into and loads from any slot, a campaign landing is autosaved as it
## starts, and the title's Continue picks the newest of the campaign autosave and the
## saved landings. A save that cannot be loaded is refused before anything in play
## is touched. One mission map exists at a time; it is taken out of the tree
## before the next one loads, so nothing leaks between landings. Behind the menus a
## backdrop scene plays when it exists: the menu backdrop (an orbiting view of the
## terrain) behind the title, the mission select and its briefings, the star backdrop
## behind the campaign screens. Tutorial hints show over a mission.

## Seconds between the end of a mission and the debrief (the last blast settles).
const DEBRIEF_DELAY: float = 1.5
## Behind the title, the mission select and its briefings, when the scene exists.
const BACKDROP_SCENE: String = "res://presentation/menu_backdrop.tscn"
## Behind the campaign screens, when the scene exists.
const STAR_BACKDROP_SCENE: String = "res://presentation/campaign/star_backdrop.tscn"
const HINT_CATALOG: String = "res://data/hints/catalog.tres"
const CAMPAIGN: String = "res://data/campaign/kessel_trail.tres"

@export var catalog: MissionCatalog
## The campaign New campaign starts; null loads CAMPAIGN.
@export var campaign_def: CampaignDef

## The mission map in play, or null.
var map: Node = null
## The mission being played or briefed.
var current: MissionDef = null
## The running mission of `map`, or null.
var runner: Mission = null
## The backdrop scene while menus are shown, or null.
var backdrop: Node = null
## True while the pause menu is open.
var paused: bool = false
## The campaign in play, or null (title, single missions).
var campaign: CampaignSession = null
## The campaign screen shown: &"title", &"star_map", &"meridian" (or its tabs), or
## &"" while a landing or the single missions have the screen.
var screen: StringName = &""

var _layer: CanvasLayer
var _title: TitleScreen
var _select: MissionSelect
var _star_map: StarMap
var _meridian: MeridianScreen
var _briefing: BriefingPanel
var _debrief: DebriefPanel
var _ending: EndingScreen
var _pause: PauseMenu
var _settings: SettingsPanel
var _info: InfoPanel
var _subtitles: SubtitleLine
var _hints: TutorialHints
var _slots: SaveLoadPanel
var _notice: SaveNotice
## How the last save or load went, and whether it failed.
var _message: String = ""
var _message_failed: bool = false
var _backdrop_path: String = ""
## The screen the credits were opened over.
var _screen_before_credits: StringName = &""
## The route node of the campaign landing briefed or played.
var _landing_node: StringName = &""


func _ready() -> void:
	Events.campaign_save_failed.connect(_on_campaign_save_failed)
	if campaign_def == null and ResourceLoader.exists(CAMPAIGN):
		campaign_def = load(CAMPAIGN) as CampaignDef
	_layer = CanvasLayer.new()
	_layer.name = &"Flow"
	_layer.layer = 10
	add_child(_layer)
	_title = TitleScreen.new()
	_title.name = &"Title"
	_layer.add_child(_title)
	_title.new_campaign_pressed.connect(new_campaign)
	_title.continue_pressed.connect(continue_campaign)
	_title.missions_pressed.connect(show_select)
	_title.settings_pressed.connect(open_settings)
	_title.how_to_play_pressed.connect(func() -> void: _info.open_how_to_play())
	_title.credits_pressed.connect(open_credits)
	_title.quit_pressed.connect(func() -> void: get_tree().quit())
	_select = MissionSelect.new()
	_select.name = &"MissionSelect"
	_layer.add_child(_select)
	_select.mission_chosen.connect(show_briefing)
	_select.settings_pressed.connect(open_settings)
	_select.back_pressed.connect(show_title)
	_star_map = StarMap.new()
	_star_map.name = &"StarMap"
	_layer.add_child(_star_map)
	_star_map.launch_pressed.connect(launch)
	_star_map.meridian_pressed.connect(show_meridian)
	_star_map.title_pressed.connect(show_title)
	_meridian = MeridianScreen.new()
	_meridian.name = &"Meridian"
	_layer.add_child(_meridian)
	_meridian.star_map_pressed.connect(show_star_map)
	_meridian.tab_shown.connect(_set_screen)
	_briefing = BriefingPanel.new()
	_briefing.name = &"Briefing"
	_layer.add_child(_briefing)
	_briefing.start_pressed.connect(_land)
	_briefing.back_pressed.connect(_back_from_landing)
	_debrief = DebriefPanel.new()
	_debrief.name = &"Debrief"
	_layer.add_child(_debrief)
	_debrief.retry_pressed.connect(_on_retry)
	_debrief.back_pressed.connect(_back_from_landing)
	_ending = EndingScreen.new()
	_ending.name = &"Ending"
	_layer.add_child(_ending)
	_ending.title_pressed.connect(show_title)
	_ending.credits_pressed.connect(open_credits)
	_hints = TutorialHints.new()
	_hints.name = &"TutorialHints"
	_layer.add_child(_hints)
	if ResourceLoader.exists(HINT_CATALOG):
		_hints.setup(load(HINT_CATALOG) as HintCatalog)
	_pause = PauseMenu.new()
	_pause.name = &"PauseMenu"
	_layer.add_child(_pause)
	_pause.resume_pressed.connect(resume)
	_pause.settings_pressed.connect(open_settings)
	_pause.how_to_play_pressed.connect(func() -> void: _info.open_how_to_play())
	_pause.restart_pressed.connect(_on_restart)
	_pause.quit_pressed.connect(_back_from_landing)
	_pause.save_pressed.connect(func() -> void: _slots.open(true))
	_pause.load_pressed.connect(func() -> void: _slots.open(false))
	_slots = SaveLoadPanel.new()
	_slots.name = &"SaveLoad"
	_layer.add_child(_slots)
	_slots.slot_chosen.connect(_on_slot_chosen)
	_notice = SaveNotice.new()
	_notice.name = &"SaveNotice"
	_layer.add_child(_notice)
	_settings = SettingsPanel.new()
	_settings.name = &"Settings"
	_layer.add_child(_settings)
	_info = InfoPanel.new()
	_info.name = &"Info"
	_layer.add_child(_info)
	_info.closed.connect(_on_info_closed)
	# Under the menus: the Advisor's lines over the map (and the debrief).
	_subtitles = SubtitleLine.new()
	_subtitles.name = &"Subtitles"
	_layer.add_child(_subtitles)
	_layer.move_child(_subtitles, 0)
	Settings.changed.connect(_apply_graphics)
	Settings.changed.connect(_apply_speed)
	_select.show_catalog(catalog)
	show_title()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Named actions the player may rebind (KeyBindings; Esc always pauses).
	if key.is_action_pressed(&"quicksave", false, true) and map != null and not paused:
		quicksave()
		get_viewport().set_input_as_handled()
		return
	if key.is_action_pressed(&"quickload", false, true) and map != null and not paused:
		quickload()
		get_viewport().set_input_as_handled()
		return
	if key.keycode != KEY_ESCAPE and not key.is_action_pressed(&"pause_menu", false, true):
		return
	# Anything in the map that wanted Esc (cancel placement, close the codex) had it.
	if map != null and not paused and not _debrief.visible:
		open_pause()
		get_viewport().set_input_as_handled()


## The title screen (any mission in play is closed, any campaign put away).
func show_title() -> void:
	_close_map()
	campaign = null
	_show_only(_title)
	_show_backdrop(BACKDROP_SCENE)
	var has_campaign: bool = campaign_def != null and CampaignSession.has_save()
	_title.open(has_campaign or not SaveSlots.newest().is_empty())
	_set_screen(&"title")


## Starts a new campaign (overwriting the autosave) and opens its star map.
func new_campaign() -> void:
	if campaign_def == null:
		return
	campaign = CampaignSession.new(campaign_def)
	campaign.start_new()
	# The difficulty chosen on the title (remembered in the settings).
	campaign.set_difficulty(Settings.difficulty)
	show_star_map()


## Continues where the player left off: the newest of the campaign autosave (its
## star map) and the saved landings (back into the mission). Stays on the title when
## nothing can be loaded.
func continue_campaign() -> void:
	var newest: Array = SaveSlots.newest()
	if not newest.is_empty():
		var game: SaveGame = newest[1]
		var campaign_time: int = -1
		if campaign_def != null and CampaignSession.has_save():
			campaign_time = FileAccess.get_modified_time(CampaignSession.default_path)
		# Times are whole seconds. On a tie the landing is the later of the two,
		# unless the campaign already holds that landing's result.
		var landing_newer: bool = game.saved_at > campaign_time
		if game.saved_at == campaign_time:
			landing_newer = not _campaign_has_resolved(game)
		if landing_newer:
			var slot: StringName = newest[0]
			if load_game(slot):
				return
			# That landing cannot be loaded: fall back to the campaign itself.
	if campaign_def == null:
		return
	var loaded: CampaignSession = CampaignSession.new(campaign_def)
	if not loaded.load_saved():
		Events.ui_feedback.emit(&"invalid")
		_title.open(false)
		return
	campaign = loaded
	if loaded.state.is_complete():
		# The Trail is done: there is no landing left to go to, only the ending.
		show_ending()
		return
	show_star_map()


## The end of a finished campaign (ADR 0017): what the Beacon Core showed, the
## campaign's numbers, and the way back to the title. Over the star backdrop.
func show_ending() -> void:
	if campaign == null:
		show_title()
		return
	_close_map()
	_show_only(_ending)
	_show_backdrop(STAR_BACKDROP_SCENE)
	_ending.open(campaign.state)
	_set_screen(&"ending")


## Back to the mission list (any mission in play is closed; no campaign).
func show_select() -> void:
	_close_map()
	campaign = null
	_show_only(_select)
	_show_backdrop(BACKDROP_SCENE)
	_set_screen(&"")
	Events.ui_feedback.emit(&"menu_open")


## The campaign's star map (any mission in play is closed).
func show_star_map() -> void:
	if campaign == null:
		show_title()
		return
	_close_map()
	_show_only(_star_map)
	_show_backdrop(STAR_BACKDROP_SCENE)
	_star_map.open(campaign)
	_set_screen(&"star_map")


## The Meridian: overview, tech web and loadout.
func show_meridian() -> void:
	if campaign == null:
		return
	_show_only(_meridian)
	_show_backdrop(STAR_BACKDROP_SCENE)
	_meridian.open(campaign)


## Briefs the campaign landing on `node_id` (it must be open).
func launch(node_id: StringName) -> void:
	if campaign == null or not campaign.select(node_id):
		Events.ui_feedback.emit(&"invalid")
		return
	_landing_node = node_id
	var route_node: RouteNodeDef = campaign.def.node(node_id)
	var preview: LandingModifiers = campaign.preview()
	current = route_node.mission
	_show_only(_briefing)
	_show_backdrop(STAR_BACKDROP_SCENE)
	_briefing.show_mission(current, preview.notes if preview != null else PackedStringArray())
	_set_screen(&"")


## Briefs a single mission.
func show_briefing(mission: MissionDef) -> void:
	current = mission
	_show_only(_briefing)
	_show_backdrop(BACKDROP_SCENE)
	_briefing.show_mission(mission)
	_set_screen(&"")


## Lands `mission`: loads its map with the mission (and the campaign's `modifiers`,
## if any) set and starts it; with `restore` (a map snapshot from a save) the landing
## is restored instead of placed fresh.
func start_mission(
	mission: MissionDef, modifiers: LandingModifiers = null, restore: Dictionary = {}
) -> void:
	_close_map()
	_free_backdrop()
	current = mission
	_show_only(null)
	_set_screen(&"")
	if mission == null or mission.map_scene == null:
		push_error("Main: mission has no map scene")
		show_select()
		return
	Events.ui_feedback.emit(&"menu_close")
	map = mission.map_scene.instantiate()
	map.set(&"mission", mission)
	if modifiers != null:
		map.set(&"modifiers", modifiers)
	if not restore.is_empty():
		map.set(&"restore_state", restore)
	add_child(map)
	# The flow's screens take input before the map's nodes.
	move_child(_layer, -1)
	var found: Variant = map.get(&"runner")
	runner = found if found is Mission else null
	if runner != null:
		runner.finished.connect(_on_mission_finished)
	var found_hud: Variant = map.get(&"hud")
	var hud: Hud = found_hud if found_hud is Hud else null
	if hud != null:
		hud.menu_requested.connect(open_pause)
	_apply_graphics()
	_apply_speed()
	_hints.begin_mission(mission)


## Saves the landing in play into `slot`. False (with a message) when there is no
## landing to save (none, or it is over) or the file cannot be written.
func save_game(slot: StringName) -> bool:
	var problem: String = ""
	var snapshot: Variant = null
	if map == null or runner == null or current == null:
		problem = "There is no landing to save."
	elif runner.result != null:
		problem = "The landing is over."
	elif not map.has_method(&"snapshot"):
		problem = "This map cannot be saved."
	else:
		snapshot = map.call(&"snapshot")
	if problem == "" and snapshot is Dictionary:
		var landing_data: Dictionary = snapshot
		var game: SaveGame = SaveGame.capture(
			current, landing_data, runner.elapsed_seconds(), campaign, _single_difficulty()
		)
		problem = SaveSlots.write(slot, game)
	if problem != "":
		_report(problem, true)
		Events.ui_feedback.emit(&"save_failed")
		return false
	_report("Saved to %s." % SaveSlots.label_of(slot), false)
	Events.campaign_saved.emit(slot)
	Events.ui_feedback.emit(&"save_done")
	return true


## Loads the landing saved in `slot`: its map is built again and restored, a
## campaign landing with its campaign as it was then. False (with a message, and the
## game in play untouched) when the save is missing, damaged, newer or incomplete.
func load_game(slot: StringName) -> bool:
	var game: SaveGame = SaveSlots.read(slot)
	var problem: String = SaveSlots.last_error if game == null else ""
	var mission: MissionDef = game.mission_def() if game != null else null
	if problem == "" and (mission == null or mission.map_scene == null):
		problem = "The mission of this save cannot be loaded."
	var session: CampaignSession = null
	var modifiers: LandingModifiers = null
	if problem == "" and game.kind == SaveGame.KIND_CAMPAIGN:
		session = _session_of(game)
		if session == null:
			problem = "The campaign of this save cannot be read."
		else:
			modifiers = LandingBuilder.build(session.def, session.landing)
	elif problem == "":
		modifiers = single_modifiers(game.difficulty)
	if problem != "":
		_report(problem, true)
		Events.ui_feedback.emit(&"invalid")
		return false
	campaign = session
	var note: String = "Loaded %s." % SaveSlots.label_of(slot)
	if session != null:
		_landing_node = session.landing.node_id
		# A saved landing carries the campaign as it was then. Loading it goes back
		# to that point, and the campaign file follows at once so the two agree.
		session.save()
		note += " The campaign is back where this save was made."
	start_mission(mission, modifiers, game.landing)
	_report(note, false)
	Events.campaign_loaded.emit(slot)
	Events.ui_feedback.emit(&"load_done")
	return true


## What a single mission brings: nothing but the difficulty `level` it is played at.
static func single_modifiers(level: StringName) -> LandingModifiers:
	var modifiers: LandingModifiers = LandingModifiers.new()
	modifiers.difficulty = Difficulty.sanitize(level)
	return modifiers


func quicksave() -> bool:
	return save_game(SaveSlots.QUICKSAVE)


func quickload() -> bool:
	return load_game(SaveSlots.QUICKSAVE)


## Opens the pause menu: the sim clock and the camera stop.
func open_pause() -> void:
	if map == null or paused:
		return
	paused = true
	_hints.suspended = true
	_set_map_running(false)
	var quit_text: String = "QUIT TO STAR MAP" if campaign != null else "QUIT TO MISSIONS"
	_pause.open(current.title if current != null else "", quit_text)
	Events.ui_feedback.emit(&"pause_open")


## Closes the pause menu and lets the mission run on.
func resume() -> void:
	if not paused:
		return
	paused = false
	_hints.suspended = false
	_settings.visible = false
	_slots.visible = false
	_info.visible = false
	_pause.visible = false
	_set_map_running(true)
	Events.ui_feedback.emit(&"pause_close")


## The credits over the title or the ending; the screen is &"credits" meanwhile
## (its music plays).
func open_credits() -> void:
	if screen != &"credits":
		_screen_before_credits = screen
	_info.open_credits()
	_set_screen(&"credits")


## Shows the settings (over the title, the mission select or the pause menu).
func open_settings() -> void:
	_settings.open()


## Starts the briefed mission: a campaign landing gets its modifiers.
## `level`: the difficulty a single mission keeps (a restart); empty takes the
## player's current choice.
func _land(mission: MissionDef, level: StringName = &"") -> void:
	if campaign == null:
		start_mission(mission, single_modifiers(Settings.difficulty if level == &"" else level))
		return
	if campaign.state.current_node != _landing_node and not campaign.select(_landing_node):
		show_star_map()
		return
	var modifiers: LandingModifiers = campaign.begin_landing()
	if modifiers == null:
		show_star_map()
		return
	start_mission(mission, modifiers)
	# The landing autosave: a lost landing can be retried from its first moment.
	if runner != null:
		var snapshot: Variant = map.call(&"snapshot") if map.has_method(&"snapshot") else null
		if snapshot is Dictionary:
			var landing_data: Dictionary = snapshot
			var game: SaveGame = SaveGame.capture(mission, landing_data, 0.0, campaign)
			if SaveSlots.write(SaveSlots.AUTOSAVE, game) == "":
				Events.campaign_saved.emit(SaveSlots.AUTOSAVE)


## Back from a briefing, the debrief or the pause menu: the star map in a campaign,
## the mission select otherwise.
func _back_from_landing() -> void:
	if campaign == null:
		show_select()
		return
	campaign.abandon_landing()
	if campaign.state.is_complete():
		show_ending()
		return
	show_star_map()


func _on_restart() -> void:
	# A restarted single mission keeps the level it was being played at (a loaded
	# save's, which may differ from the level chosen for new missions).
	var level: StringName = _single_difficulty() if runner != null else &""
	resume()
	_land(current, level)


func _set_map_running(running: bool) -> void:
	if runner != null and runner.context != null:
		runner.context.sim_clock.paused = not running
	var found: Variant = map.get(&"camera") if map != null else null
	var camera: Node = found if found is Node else null
	if camera != null:
		camera.process_mode = Node.PROCESS_MODE_INHERIT if running else Node.PROCESS_MODE_DISABLED


func _on_mission_finished(result: MissionResult) -> void:
	var played: Node = map
	# A won mission of the catalog opens the next single mission, also when it was
	# won as a campaign landing (the campaign plays the same missions).
	if result.won and current != null and catalog != null and catalog.missions.has(current):
		Settings.mark_mission_won(current.id)
	# A campaign landing counts the moment it ends, even if the player quits now.
	var banked: int = -1
	if campaign != null and campaign.landing != null:
		banked = campaign.resolve(result)
		_drop_landing_saves()
	await get_tree().create_timer(DEBRIEF_DELAY).timeout
	if map != played or map == null:
		return
	if paused:
		resume()
	if runner != null and runner.context != null:
		runner.context.sim_clock.paused = true
	_hints.end_mission()
	var final: bool = campaign != null and campaign.state.is_complete() and result.won
	_debrief.show_result(result, banked, final)
	_debrief.visible = true


func _on_slot_chosen(slot: StringName, saving: bool) -> void:
	if saving:
		if save_game(slot):
			_slots.refresh()
		_slots.show_status(_message, _message_failed)
		return
	if not load_game(slot):
		_slots.show_status(_message, _message_failed)


## A resolved landing is over: its quicksave and landing autosave would only load
## back into it (and Continue could pick them over the result). Manual slots stay,
## as the player's own way back.
func _drop_landing_saves() -> void:
	for slot: StringName in [SaveSlots.QUICKSAVE, SaveSlots.AUTOSAVE]:
		if not SaveSlots.exists(slot):
			continue
		var game: SaveGame = SaveSlots.read(slot)
		if game != null and game.kind == SaveGame.KIND_CAMPAIGN:
			SaveSlots.remove(slot)


## True when the campaign file already counts the landing of `game` as won.
func _campaign_has_resolved(game: SaveGame) -> bool:
	if game.kind != SaveGame.KIND_CAMPAIGN or game.plan == null or campaign_def == null:
		return false
	var saved: CampaignSession = CampaignSession.new(campaign_def)
	return saved.load_quietly() and saved.state.won.has(game.plan.node_id)


func _on_campaign_save_failed(_slot: StringName) -> void:
	_report("The campaign could not be saved. Changes since the last save may be lost.", true)
	Events.ui_feedback.emit(&"save_failed")


## The campaign a saved landing belongs to, as it was when saved, with the landing in
## play; null when it cannot be read.
func _session_of(game: SaveGame) -> CampaignSession:
	var def: CampaignDef = game.campaign_def()
	if def == null or game.plan == null:
		return null
	var state: CampaignState = CampaignState.from_dict(game.campaign, def)
	if state == null or def.node(game.plan.node_id) == null:
		return null
	var session: CampaignSession = CampaignSession.new(def)
	session.state = state
	session.state.current_node = game.plan.node_id
	session.landing = game.plan
	return session


## Shows how a save or load went (the notice over the map, the slot screen's line).
func _report(text: String, failed: bool) -> void:
	_message = text
	_message_failed = failed
	_notice.show_text(text, failed)
	if failed:
		print("Main: %s" % text)


func _on_info_closed() -> void:
	if screen == &"credits":
		_set_screen(_screen_before_credits)


func _on_retry() -> void:
	_land(current, _single_difficulty() if runner != null else &"")


## Shows `page` (or nothing) of the full-screen menus; hides the others.
func _show_only(page: Control) -> void:
	for other: Control in [_title, _select, _star_map, _meridian, _briefing, _debrief, _ending]:
		other.visible = other == page


func _set_screen(next: StringName) -> void:
	if next == screen:
		return
	screen = next
	Events.campaign_screen_changed.emit(next)


## The difficulty of the single mission in play (Normal otherwise).
func _single_difficulty() -> StringName:
	var level: StringName = &""
	if runner != null and runner.modifiers != null:
		level = runner.modifiers.difficulty
	return Difficulty.sanitize(level)


## A single mission runs at the game speed the player chose; a campaign landing at 1.
func _apply_speed() -> void:
	if runner != null and runner.context != null:
		runner.context.sim_clock.speed = Settings.game_speed if campaign == null else 1.0


func _apply_graphics() -> void:
	if map != null:
		GraphicsSettings.apply(map, Settings.quality)
	if backdrop != null:
		GraphicsSettings.apply(backdrop, Settings.quality)


## The backdrop scene at `path` behind the menus, once it exists (another one in its
## place is freed first).
func _show_backdrop(path: String) -> void:
	if backdrop != null and _backdrop_path != path:
		_free_backdrop()
	if backdrop == null and map == null and ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene != null:
			backdrop = scene.instantiate()
			backdrop.name = &"Backdrop"
			add_child(backdrop)
			move_child(backdrop, 0)
			_backdrop_path = path
			GraphicsSettings.apply(backdrop, Settings.quality)
	_title.set_see_through(backdrop != null)
	_select.set_see_through(backdrop != null)
	_star_map.set_see_through(backdrop != null)
	_meridian.set_see_through(backdrop != null)
	_briefing.set_see_through(backdrop != null)
	_ending.set_see_through(backdrop != null)


func _free_backdrop() -> void:
	if backdrop == null:
		return
	remove_child(backdrop)
	backdrop.queue_free()
	backdrop = null
	_backdrop_path = ""


func _close_map() -> void:
	if paused:
		paused = false
		_pause.visible = false
		_settings.visible = false
		_slots.visible = false
		_info.visible = false
		Events.ui_feedback.emit(&"pause_close")
	_hints.end_mission()
	runner = null
	if map == null:
		return
	remove_child(map)
	map.queue_free()
	map = null
