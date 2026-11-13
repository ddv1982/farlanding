class_name BakeEmberfallNavmesh
extends SceneTree
## Rebuilds `emberfall_caldera_navmesh.res` from the terrain collider (ADR 0015). Run
## after the terrain changes:
##   godot --headless --path game -s res://maps/emberfall_caldera/bake_emberfall_navmesh.gd
## One stage, no sea: ground below CLIP (a little above the lava's surface) is cut
## from the source geometry, so the lava rivers are never walkable, for ground and
## hovering units alike (a map without a sea gives hovering units the same navmesh).

const VISUALS: String = "res://maps/emberfall_caldera/emberfall_visuals.tscn"
const OUTPUT: String = "res://maps/emberfall_caldera/emberfall_caldera_navmesh.res"
## The lava's surface (the terrain recipe's LAVA_LEVEL) ...
const LAVA_LEVEL: float = -0.9
## ... and the cut: the river banks below this stay off the navmesh too.
const CLIP: float = -0.5
## The navigation map's merge rasteriser scale: edges are cleaned as it joins them.
const MERGE_SCALE: float = 0.1
## A point on the Concord shelf; islands not connected to it are dropped.
const KEEP_POINT: Vector3 = Vector3(-80.0, 1.6, 85.0)

var _visuals: Node


func _initialize() -> void:
	var packed: PackedScene = load(VISUALS)
	_visuals = packed.instantiate()
	root.add_child(_visuals)


# The scene is only inside the tree once the first frame starts.
func _process(_delta: float) -> bool:
	var started: int = Time.get_ticks_msec()
	var baked: NavigationMesh = NavmeshTools.bake_from_colliders(_visuals, CLIP)
	var cleaned: NavigationMesh = NavmeshTools.remove_nonmanifold_edges(
		NavmeshTools.remove_nonmanifold_edges(baked), MERGE_SCALE
	)
	var kept: NavigationMesh = NavmeshTools.keep_island(cleaned, KEEP_POINT)
	print(
		(
			"bake (ground below %.2f m cut): %d polygons / %d vertices kept, %d ms"
			% [
				CLIP,
				kept.get_polygon_count(),
				kept.get_vertices().size(),
				Time.get_ticks_msec() - started
			]
		)
	)
	var error: Error = ResourceSaver.save(kept, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	_visuals.free()
	quit(0 if error == OK else 1)
	return true
