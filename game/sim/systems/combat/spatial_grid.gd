class_name SpatialGrid
extends RefCounted
## Buckets entities by ground cell so "who is near this point" touches only a few
## cells instead of every entity. Rebuilt once per sim tick by Combat (cheap: one
## insert per entity); queried by target acquisition and splash damage.

var cell_size: float = 16.0

var _cells: Dictionary[Vector2i, Array] = {}
var _count: int = 0


func _init(p_cell_size: float = 16.0) -> void:
	cell_size = maxf(p_cell_size, 0.5)


func clear() -> void:
	_cells.clear()
	_count = 0


func size() -> int:
	return _count


func insert(entity: Node3D, at: Vector3) -> void:
	var cell: Vector2i = cell_of(at)
	if not _cells.has(cell):
		_cells[cell] = []
	_cells[cell].append(entity)
	_count += 1


## Entities in every cell touched by the square around `center` (`radius` each way).
## Callers check the exact distance.
func query(center: Vector3, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var low: Vector2i = cell_of(center - Vector3(radius, 0.0, radius))
	var high: Vector2i = cell_of(center + Vector3(radius, 0.0, radius))
	for z: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var bucket: Variant = _cells.get(Vector2i(x, z))
			if bucket == null:
				continue
			var entries: Array = bucket
			for entry: Variant in entries:
				var entity: Node3D = entry
				result.append(entity)
	return result


func cell_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / cell_size), floori(at.z / cell_size))
