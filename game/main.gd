class_name Main
extends Node
## The game's flow (PLAN 2.6, Phases 5 and 6): the mission select screen (with the
## settings), the briefing, the mission itself (its map scene with the MissionDef in
## `mission`), the pause menu (Esc or the HUD's MENU: Resume, Settings, Restart, Quit
## to missions; the sim clock and the camera stop), then the debrief with Retry and
## Back to missions. One mission map exists at a time; it is taken out of the tree
## before the next one loads, so nothing leaks between landings. While the mission
## select or a briefing is up, the menu backdrop (a slowly orbiting view of the
## terrain) plays behind it when its scene exists. Tutorial hints show over a mission.

## Seconds between the end of a mission and the debrief (the last blast settles).
const DEBRIEF_DELAY: float = 1.5
## Behind the mission select and the briefing, when the scene exists.
const BACKDROP_SCENE: String = "res://presentation/menu_backdrop.tscn"
const HINT_CATALOG: String = "res://data/hints/catalog.tres"

@export var catalog: MissionCatalog

## The mission map in play, or null.
var map: Node = null
## The mission being played or briefed.
var current: MissionDef = null
## The running mission of `map`, or null.
var runner: Mission = null
## The menu backdrop while menus are shown, or null.
var backdrop: Node = null
## True while the pause menu is open.
var paused: bool = false

var _layer: CanvasLayer
var _select: MissionSelect
var _briefing: BriefingPanel
var _debrief: DebriefPanel
var _pause: PauseMenu
var _settings: SettingsPanel
var _hints: TutorialHints


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = &"Flow"
	_layer.layer = 10
	add_child(_layer)
	_select = MissionSelect.new()
	_select.name = &"MissionSelect"
	_layer.add_child(_select)
	_select.mission_chosen.connect(show_briefing)
	_select.settings_pressed.connect(open_settings)
	_briefing = BriefingPanel.new()
	_briefing.name = &"Briefing"
	_layer.add_child(_briefing)
	_briefing.start_pressed.connect(start_mission)
	_briefing.back_pressed.connect(show_select)
	_debrief = DebriefPanel.new()
	_debrief.name = &"Debrief"
	_layer.add_child(_debrief)
	_debrief.retry_pressed.connect(_on_retry)
	_debrief.back_pressed.connect(show_select)
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
	_pause.quit_pressed.connect(show_select)
	_settings = SettingsPanel.new()
	_settings.name = &"Settings"
	_layer.add_child(_settings)
	Settings.changed.connect(_apply_graphics)
	_select.show_catalog(catalog)
	show_select()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	# Anything in the map that wanted Esc (cancel placement, close the codex) had it.
	if map != null and not paused and not _debrief.visible:
		open_pause()
		get_viewport().set_input_as_handled()


## Back to the mission list (any mission in play is closed).
func show_select() -> void:
	_close_map()
	_show_backdrop()
	_select.visible = true
	_briefing.visible = false
	_debrief.visible = false
	Events.ui_feedback.emit(&"menu_open")


func show_briefing(mission: MissionDef) -> void:
	current = mission
	_show_backdrop()
	_briefing.show_mission(mission)
	_select.visible = false
	_briefing.visible = true
	_debrief.visible = false


## Lands `mission`: loads its map with the mission set and starts it.
func start_mission(mission: MissionDef) -> void:
	_close_map()
	_free_backdrop()
	current = mission
	_select.visible = false
	_briefing.visible = false
	_debrief.visible = false
	if mission == null or mission.map_scene == null:
		push_error("Main: mission has no map scene")
		show_select()
		return
	Events.ui_feedback.emit(&"menu_close")
	map = mission.map_scene.instantiate()
	map.set(&"mission", mission)
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
	_set_map_running(false)
	_pause.open(current.title if current != null else "")
	Events.ui_feedback.emit(&"pause_open")


## Closes the pause menu and lets the mission run on.
func resume() -> void:
	if not paused:
		return
	paused = false
	_settings.visible = false
	_pause.visible = false
	_set_map_running(true)
	Events.ui_feedback.emit(&"pause_close")


## Shows the settings (over the mission select or the pause menu).
func open_settings() -> void:
	_settings.open()


func _on_restart() -> void:
	resume()
	start_mission(current)


func _set_map_running(running: bool) -> void:
	if runner != null and runner.context != null:
		runner.context.sim_clock.paused = not running
	var found: Variant = map.get(&"camera") if map != null else null
	var camera: Node = found if found is Node else null
	if camera != null:
		camera.process_mode = Node.PROCESS_MODE_INHERIT if running else Node.PROCESS_MODE_DISABLED


func _on_mission_finished(result: MissionResult) -> void:
	var played: Node = map
	await get_tree().create_timer(DEBRIEF_DELAY).timeout
	if map != played or map == null:
		return
	if paused:
		resume()
	if runner != null and runner.context != null:
		runner.context.sim_clock.paused = true
	_hints.end_mission()
	_debrief.show_result(result)
	_debrief.visible = true


func _on_retry() -> void:
	start_mission(current)


func _apply_graphics() -> void:
	if map != null:
		GraphicsSettings.apply(map, Settings.quality)
	if backdrop != null:
		GraphicsSettings.apply(backdrop, Settings.quality)


## The menu backdrop behind the select and briefing screens (once it exists).
func _show_backdrop() -> void:
	if backdrop != null or map != null or not ResourceLoader.exists(BACKDROP_SCENE):
		_select.set_see_through(backdrop != null)
		_briefing.set_see_through(backdrop != null)
		return
	var scene: PackedScene = load(BACKDROP_SCENE) as PackedScene
	if scene != null:
		backdrop = scene.instantiate()
		backdrop.name = &"MenuBackdrop"
		add_child(backdrop)
		move_child(backdrop, 0)
		GraphicsSettings.apply(backdrop, Settings.quality)
	_select.set_see_through(backdrop != null)
	_briefing.set_see_through(backdrop != null)


func _free_backdrop() -> void:
	if backdrop == null:
		return
	remove_child(backdrop)
	backdrop.queue_free()
	backdrop = null


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
