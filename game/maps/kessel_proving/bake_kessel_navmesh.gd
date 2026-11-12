class_name BakeKesselNavmesh
extends SceneTree
## Rebuilds `kessel_proving_navmesh.res` from the terrain collider. Run after the
## terrain changes:
##   godot --headless --path game -s res://maps/kessel_proving/bake_kessel_navmesh.gd

const VISUALS: String = "res://maps/kessel_proving/kessel_visuals.tscn"
const OUTPUT: String = "res://maps/kessel_proving/kessel_proving_navmesh.res"
## A point on the main basin floor (the player start); every island not connected
## to it is dropped.
const KEEP_POINT: Vector3 = Vector3(-80.0, 0.0, 85.0)

var _visuals: Node


func _initialize() -> void:
	var packed: PackedScene = load(VISUALS)
	_visuals = packed.instantiate()
	root.add_child(_visuals)


# The scene is only inside the tree once the first frame starts.
func _process(_delta: float) -> bool:
	var visuals: Node = _visuals
	var started: int = Time.get_ticks_msec()
	var baked: NavigationMesh = NavmeshTools.bake_from_colliders(visuals)
	var kept: NavigationMesh = NavmeshTools.keep_island(
		NavmeshTools.remove_nonmanifold_edges(baked), KEEP_POINT
	)
	print(
		(
			"bake: %d polygons / %d vertices baked, %d polygons / %d vertices kept, %d ms"
			% [
				baked.get_polygon_count(),
				baked.get_vertices().size(),
				kept.get_polygon_count(),
				kept.get_vertices().size(),
				Time.get_ticks_msec() - started,
			]
		)
	)
	var error: Error = ResourceSaver.save(kept, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	visuals.free()
	quit(0 if error == OK else 1)
	return true
