class_name PlacementRules
extends RefCounted
## Where a building may stand. Pure: the ground is asked through two callables so
## tests can use flat ground.
##
## A spot is refused when the footprint (plus `rules.building_gap`) overlaps another
## building, overlaps a resource node, leaves the map, stands on unwalkable or too
## steep ground, or — for a building that needs a vent — is not on a free Flux vent.

const OK: StringName = &""
const OUT_OF_BOUNDS: StringName = &"out_of_bounds"
const BLOCKED: StringName = &"blocked"
const ON_RESOURCE: StringName = &"on_resource"
const NEEDS_VENT: StringName = &"needs_vent"
const VENT_TAKEN: StringName = &"vent_taken"
const UNWALKABLE: StringName = &"unwalkable"
const TOO_STEEP: StringName = &"too_steep"
## Spacing of the ground samples over a footprint, in metres.
const SAMPLE_STEP: float = 1.5
## A building that needs a vent must stand this close to the vent's centre.
const VENT_TOLERANCE: float = 0.5

## Footprints of every building standing or under construction (world X/Z).
var footprints: Array[Rect2] = []
var nodes: Array[ResourceNode] = []
## Area buildings may be placed in (world X/Z).
var bounds: Rect2 = Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6)
## `func(point: Vector3) -> bool`: terrain walkability (buildings ignored).
var is_walkable: Callable = func(_point: Vector3) -> bool: return true
## `func(x: float, z: float) -> float`: ground height.
var height_at: Callable = func(_x: float, _z: float) -> float: return 0.0
var rules: EconomyRules = EconomyRules.new()


## Player-facing explanation of a refusal reason.
static func describe(reason: StringName) -> String:
	match reason:
		OUT_OF_BOUNDS:
			return "Outside the landing zone"
		BLOCKED:
			return "Too close to another building"
		ON_RESOURCE:
			return "A deposit or vent is in the way"
		NEEDS_VENT:
			return "Must be built on a Flux vent"
		VENT_TAKEN:
			return "This vent is already tapped"
		UNWALKABLE:
			return "The ground here is impassable"
		TOO_STEEP:
			return "The ground here is too steep"
	return ""


## Where a building of `def` would stand for a cursor at `cursor`: snapped to a
## half-metre grid, or onto the centre of the nearest free vent within
## `rules.vent_snap_distance` for buildings that need one.
func snap(def: BuildingDef, cursor: Vector3) -> Vector3:
	if def.requires_resource != &"":
		var best: ResourceNode = null
		var best_distance: float = rules.vent_snap_distance
		for node: ResourceNode in nodes:
			if node.resource() != def.requires_resource or not node.is_free_vent():
				continue
			var distance: float = _flat(node.position - cursor).length()
			if distance <= best_distance:
				best = node
				best_distance = distance
		if best != null:
			return best.position
	return Vector3(snappedf(cursor.x, 0.5), cursor.y, snappedf(cursor.z, 0.5))


## Why `def` cannot stand at `at`, or OK.
func check(def: BuildingDef, at: Vector3) -> StringName:
	var area: Rect2 = def.world_footprint(at)
	if not bounds.encloses(area):
		return OUT_OF_BOUNDS
	var spaced: Rect2 = area.grow(rules.building_gap)
	for other: Rect2 in footprints:
		if spaced.intersects(other):
			return BLOCKED
	var vent_reason: StringName = _check_nodes(def, at, area)
	if vent_reason != OK:
		return vent_reason
	return _check_ground(area)


## The vent `def` would tap at `at`, or null.
func vent_at(def: BuildingDef, at: Vector3) -> ResourceNode:
	if def.requires_resource == &"":
		return null
	for node: ResourceNode in nodes:
		if (
			node.resource() == def.requires_resource
			and _flat(node.position - at).length() <= VENT_TOLERANCE
		):
			return node
	return null


func _check_nodes(def: BuildingDef, at: Vector3, area: Rect2) -> StringName:
	var vent: ResourceNode = vent_at(def, at)
	if def.requires_resource != &"":
		if vent == null:
			return NEEDS_VENT
		if not vent.is_free_vent():
			return VENT_TAKEN
	for node: ResourceNode in nodes:
		if node == vent or node.def == null:
			continue
		if _circle_hits_rect(node.position, node.def.radius, area):
			return ON_RESOURCE
	return OK


func _check_ground(area: Rect2) -> StringName:
	var columns: int = maxi(ceili(area.size.x / SAMPLE_STEP), 1)
	var rows: int = maxi(ceili(area.size.y / SAMPLE_STEP), 1)
	var lowest: float = INF
	var highest: float = -INF
	for row: int in rows + 1:
		for column: int in columns + 1:
			var x: float = area.position.x + area.size.x * column / columns
			var z: float = area.position.y + area.size.y * row / rows
			var point: Vector3 = Vector3(x, 0.0, z)
			var walkable: bool = is_walkable.call(point)
			if not walkable:
				return UNWALKABLE
			var height: float = height_at.call(x, z)
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	var span: float = maxf(minf(area.size.x, area.size.y), 0.1)
	if rad_to_deg(atan((highest - lowest) / span)) > rules.max_slope:
		return TOO_STEEP
	return OK


static func _circle_hits_rect(centre: Vector3, radius: float, area: Rect2) -> bool:
	var nearest: Vector2 = Vector2(
		clampf(centre.x, area.position.x, area.end.x), clampf(centre.z, area.position.y, area.end.y)
	)
	return nearest.distance_to(Vector2(centre.x, centre.z)) < radius


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
