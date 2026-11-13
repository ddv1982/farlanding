class_name PatrolRoute
extends Resource
## A guard post as data: the guards it posts and the route they walk, waypoint by
## waypoint, pausing (and looking around) at each. One waypoint = a stationary
## sentry facing `facing`. Driven by the AI's PatrolBehaviour through the normal
## command path.

@export var id: StringName = &""
## The guard type, and how many walk the route together.
@export var unit: UnitDef
@export_range(1, 12, 1) var count: int = 1
## World X/Z points; Y is ignored (placed on the ground).
@export var waypoints: PackedVector3Array = PackedVector3Array()
## Seconds to wait at each waypoint (missing entries use `default_pause`).
@export var pauses: PackedFloat32Array = PackedFloat32Array()
@export_range(0.0, 60.0, 0.5, "suffix:s") var default_pause: float = 2.0
## True: after the last waypoint walk back to the first (a loop); false: walk the
## route back the way it came (ping-pong).
@export var loop: bool = true
## Direction a stationary sentry looks (and every guard faces at spawn).
@export var facing: Vector3 = Vector3(0.0, 0.0, 1.0)


## Seconds to wait at waypoint `index`.
func pause_at(index: int) -> float:
	return pauses[index] if index >= 0 and index < pauses.size() else default_pause


## The waypoint after `index` when walking in `direction` (+1 or -1). Returns
## Vector2i(next index, next direction).
func next_index(index: int, direction: int) -> Vector2i:
	var size: int = waypoints.size()
	if size <= 1:
		return Vector2i(0, 1)
	if loop:
		return Vector2i(posmod(index + 1, size), 1)
	var next: int = index + direction
	if next < 0 or next >= size:
		direction = -direction
		next = index + direction
	return Vector2i(next, direction)
