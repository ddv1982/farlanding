class_name BuildPlacement
extends Node
## Placement mode: a translucent ghost of the chosen building follows the cursor,
## coloured by whether the spot is valid. Left click places (the cost is paid when
## the command runs), Shift+left click places and keeps placing, right click or Esc
## cancels. Owned by the SelectionController, which routes the clicks here.

## Placement started (`def` set) or ended (`def` null).
signal changed(def: BuildingDef)

## The building being placed, or null when not placing.
var def: BuildingDef = null
## Who will build it.
var builders: Array[Unit] = []
## Where it would stand now, and whether it may.
var spot: Vector3 = Vector3.INF
var reason: StringName = PlacementRules.OK

var _world: SimWorld = null
var _ghost: PlacementGhost = null


func is_active() -> bool:
	return def != null


## Starts placing `p_def` for `p_builders`.
func begin(p_def: BuildingDef, p_builders: Array[Unit], world: SimWorld) -> void:
	cancel()
	def = p_def
	builders = p_builders.duplicate()
	_world = world
	if def.model != null:
		_ghost = PlacementGhost.create(def.model)
		_ghost.visible = false
		world.add_child(_ghost)
	changed.emit(def)


## Ends placement without placing anything.
func cancel() -> void:
	if def == null:
		return
	def = null
	builders.clear()
	spot = Vector3.INF
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	changed.emit(null)


## Moves the ghost to the ground point under the cursor (Vector3.INF: off the map).
func update(ground: Vector3) -> void:
	if def == null:
		return
	if ground == Vector3.INF:
		spot = Vector3.INF
		reason = PlacementRules.OUT_OF_BOUNDS
		if _ghost != null:
			_ghost.visible = false
		return
	var rules: PlacementRules = _world.placement_rules()
	spot = rules.snap(def, ground)
	reason = rules.check(def, spot)
	if _world.heights != null:
		spot.y = _world.heights.sample(spot.x, spot.z)
	if _ghost != null:
		_ghost.visible = true
		_ghost.position = spot
		_ghost.set_valid(reason == PlacementRules.OK)


## Tries to place at the current spot. Returns the command to push, or null after
## giving feedback for a refused spot or an unaffordable cost.
func confirm(faction: int, queued: bool) -> PlaceBuildingCommand:
	if def == null:
		return null
	if spot == Vector3.INF or reason != PlacementRules.OK:
		Events.ui_feedback.emit(&"placement_invalid")
		return null
	if not _world.economy.can_afford(faction, def):
		Events.ui_feedback.emit(&"not_enough_resources")
		Events.advisor_alert.emit(&"insufficient_resources")
		return null
	var receivers: Array[Node3D] = []
	for unit: Unit in builders:
		if is_instance_valid(unit) and unit.is_inside_tree():
			receivers.append(unit)
	if receivers.is_empty():
		cancel()
		return null
	var command: PlaceBuildingCommand = PlaceBuildingCommand.new(
		faction, receivers, def, spot, queued
	)
	if not queued:
		cancel()
	return command


func _exit_tree() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
