class_name Main
extends Node
## The game's flow (PLAN 1, 2.6; Phases 5 to 7). The title screen offers New campaign,
## Continue, Single missions, Settings and Quit.
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
## The pause menu (Esc or the HUD's MENU: Resume, Settings, Restart, Quit; the sim
## clock and the camera stop) quits to the star map in a campaign and to the mission
## select otherwise. One mission map exists at a time; it is taken out of the tree
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
var _pause: PauseMenu
var _settings: SettingsPanel
var _hints: TutorialHints
var _backdrop_path: String = ""
## The route node of the campaign landing briefed or played.
var _landing_node: StringName = &""


func _ready() -> void:
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
	_pause.restart_pressed.connect(_on_restart)
	_pause.quit_pressed.connect(_back_from_landing)
	_settings = SettingsPanel.new()
	_settings.name = &"Settings"
	_layer.add_child(_settings)
	Settings.changed.connect(_apply_graphics)
	_select.show_catalog(catalog)
	show_title()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
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
	_title.open(campaign_def != null and CampaignSession.has_save())
	_set_screen(&"title")


## Starts a new campaign (overwriting the autosave) and opens its star map.
func new_campaign() -> void:
	if campaign_def == null:
		return
	campaign = CampaignSession.new(campaign_def)
	campaign.start_new()
	show_star_map()


## Loads the autosave and opens its star map; stays on the title when it cannot.
func continue_campaign() -> void:
	if campaign_def == null:
		return
	var loaded: CampaignSession = CampaignSession.new(campaign_def)
	if not loaded.load_saved():
		Events.ui_feedback.emit(&"invalid")
		_title.open(false)
		return
	campaign = loaded
	show_star_map()


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
## if any) set and starts it.
func start_mission(mission: MissionDef, modifiers: LandingModifiers = null) -> void:
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
	_hints.begin_mission(mission)


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
	_pause.visible = false
	_set_map_running(true)
	Events.ui_feedback.emit(&"pause_close")


## Shows the settings (over the title, the mission select or the pause menu).
func open_settings() -> void:
	_settings.open()


## Starts the briefed mission: a campaign landing gets its modifiers.
func _land(mission: MissionDef) -> void:
	if campaign == null:
		start_mission(mission)
		return
	if campaign.state.current_node != _landing_node and not campaign.select(_landing_node):
		show_star_map()
		return
	var modifiers: LandingModifiers = campaign.begin_landing()
	if modifiers == null:
		show_star_map()
		return
	start_mission(mission, modifiers)


## Back from a briefing, the debrief or the pause menu: the star map in a campaign,
## the mission select otherwise.
func _back_from_landing() -> void:
	if campaign == null:
		show_select()
		return
	campaign.abandon_landing()
	show_star_map()


func _on_restart() -> void:
	resume()
	_land(current)


func _set_map_running(running: bool) -> void:
	if runner != null and runner.context != null:
		runner.context.sim_clock.paused = not running
	var found: Variant = map.get(&"camera") if map != null else null
	var camera: Node = found if found is Node else null
	if camera != null:
		camera.process_mode = Node.PROCESS_MODE_INHERIT if running else Node.PROCESS_MODE_DISABLED


func _on_mission_finished(result: MissionResult) -> void:
	var played: Node = map
	# A campaign landing counts the moment it ends, even if the player quits now.
	var banked: int = -1
	if campaign != null and campaign.landing != null:
		banked = campaign.resolve(result)
	await get_tree().create_timer(DEBRIEF_DELAY).timeout
	if map != played or map == null:
		return
	if paused:
		resume()
	if runner != null and runner.context != null:
		runner.context.sim_clock.paused = true
	_hints.end_mission()
	_debrief.show_result(result, banked)
	_debrief.visible = true


func _on_retry() -> void:
	_land(current)


## Shows `page` (or nothing) of the full-screen menus; hides the others.
func _show_only(page: Control) -> void:
	for other: Control in [_title, _select, _star_map, _meridian, _briefing, _debrief]:
		other.visible = other == page


func _set_screen(next: StringName) -> void:
	if next == screen:
		return
	screen = next
	Events.campaign_screen_changed.emit(next)


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
		Events.ui_feedback.emit(&"pause_close")
	_hints.end_mission()
	runner = null
	if map == null:
		return
	remove_child(map)
	map.queue_free()
	map = null
