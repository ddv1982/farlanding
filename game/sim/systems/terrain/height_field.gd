class_name HeightField
extends RefCounted
## Terrain height on a regular XZ grid with bilinear sampling. Built once per map
## (from the terrain collider) so units can follow the ground without a physics body
## or a per-unit raycast.

## World X/Z of sample (0, 0).
var origin: Vector2 = Vector2.ZERO
## Distance between samples in metres.
var spacing: float = 1.0
var columns: int = 0
var rows: int = 0
## Row-major heights, `rows * columns` long.
var heights: PackedFloat32Array = PackedFloat32Array()


func _init(
	p_origin: Vector2 = Vector2.ZERO,
	p_spacing: float = 1.0,
	p_columns: int = 0,
	p_rows: int = 0,
	p_heights: PackedFloat32Array = PackedFloat32Array(),
) -> void:
	origin = p_origin
	spacing = p_spacing
	columns = p_columns
	rows = p_rows
	heights = p_heights
	if heights.size() != rows * columns:
		heights.resize(rows * columns)


## Height at world (x, z), bilinear between samples, clamped at the edges.
## Returns 0 for an empty field.
func sample(x: float, z: float) -> float:
	if columns == 0 or rows == 0:
		return 0.0
	var gx: float = clampf((x - origin.x) / spacing, 0.0, columns - 1.0)
	var gz: float = clampf((z - origin.y) / spacing, 0.0, rows - 1.0)
	var x0: int = mini(int(gx), columns - 1)
	var z0: int = mini(int(gz), rows - 1)
	var x1: int = mini(x0 + 1, columns - 1)
	var z1: int = mini(z0 + 1, rows - 1)
	var fx: float = gx - x0
	var fz: float = gz - z0
	var top: float = lerpf(heights[z0 * columns + x0], heights[z0 * columns + x1], fx)
	var bottom: float = lerpf(heights[z1 * columns + x0], heights[z1 * columns + x1], fx)
	return lerpf(top, bottom, fz)


## Builds a field over `area` (world X/Z) by casting rays down onto the colliders in
## `space` (all collision layers in `mask`). Misses read as 0.
static func from_physics(
	space: PhysicsDirectSpaceState3D, area: Rect2, p_spacing: float, mask: int = 0xFFFFFFFF
) -> HeightField:
	var p_columns: int = int(area.size.x / p_spacing) + 1
	var p_rows: int = int(area.size.y / p_spacing) + 1
	var field: HeightField = HeightField.new(area.position, p_spacing, p_columns, p_rows)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.collision_mask = mask
	for row: int in p_rows:
		var z: float = area.position.y + row * p_spacing
		for column: int in p_columns:
			var x: float = area.position.x + column * p_spacing
			query.from = Vector3(x, 500.0, z)
			query.to = Vector3(x, -500.0, z)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				var point: Vector3 = hit["position"]
				field.heights[row * p_columns + column] = point.y
	return field
