class_name Main
extends Node
## The game's flow (PLAN 2.6, Phase 5): the mission select screen, the briefing,
## the mission itself (its map scene with the MissionDef in `mission`), then the
## debrief with Retry and Back to missions. One mission map exists at a time; it is
## taken out of the tree before the next one loads, so nothing leaks between landings.

## Seconds between the end of a mission and the debrief (the last blast settles).
const DEBRIEF_DELAY: float = 1.5

@export var catalog: MissionCatalog

## The mission map in play, or null.
var map: Node = null
## The mission being played or briefed.
var current: MissionDef = null
## The running mission of `map`, or null.
var runner: Mission = null

var _layer: CanvasLayer
var _select: MissionSelect
var _briefing: BriefingPanel
var _debrief: DebriefPanel


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = &"Flow"
	_layer.layer = 10
	add_child(_layer)
	_select = MissionSelect.new()
	_select.name = &"MissionSelect"
	_layer.add_child(_select)
	_select.mission_chosen.connect(show_briefing)
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
	_select.show_catalog(catalog)
	show_select()


## Back to the mission list (any mission in play is closed).
func show_select() -> void:
	_close_map()
	_select.visible = true
	_briefing.visible = false
	_debrief.visible = false


func show_briefing(mission: MissionDef) -> void:
	current = mission
	_briefing.show_mission(mission)
	_select.visible = false
	_briefing.visible = true
	_debrief.visible = false


## Lands `mission`: loads its map with the mission set and starts it.
func start_mission(mission: MissionDef) -> void:
	_close_map()
	current = mission
	_select.visible = false
	_briefing.visible = false
	_debrief.visible = false
	if mission == null or mission.map_scene == null:
		push_error("Main: mission has no map scene")
		show_select()
		return
	map = mission.map_scene.instantiate()
	map.set(&"mission", mission)
	add_child(map)
	var found: Variant = map.get(&"runner")
	runner = found if found is Mission else null
	if runner != null:
		runner.finished.connect(_on_mission_finished)


func _on_mission_finished(result: MissionResult) -> void:
	var played: Node = map
	await get_tree().create_timer(DEBRIEF_DELAY).timeout
	if map != played or map == null:
		return
	if runner != null and runner.context != null:
		runner.context.sim_clock.paused = true
	_debrief.show_result(result)
	_debrief.visible = true


func _on_retry() -> void:
	start_mission(current)


func _close_map() -> void:
	runner = null
	if map == null:
		return
	remove_child(map)
	map.queue_free()
	map = null
