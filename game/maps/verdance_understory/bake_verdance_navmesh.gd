class_name BakeVerdanceNavmesh
extends SceneTree
## Rebuilds `verdance_understory_navmesh.res` from the terrain's colliders (ADR 0016):
## the ground, the giant trunks and the root ridges. Run after the terrain changes:
##   godot --headless --path game -s res://maps/verdance_understory/bake_verdance_navmesh.gd
## One stage, no sea. The stream is shallow and wadeable everywhere (its bed is at
## STREAM_BED), so the cut sits below it and removes nothing that is ground: only
## islands the bake leaves on top of trunks and ridges, which `keep_island` drops.
## The crowns are not colliders: units walk under them. Flying units do not use this
## navmesh at all.

const VISUALS: String = "res://maps/verdance_understory/verdance_visuals.tscn"
const OUTPUT: String = "res://maps/verdance_understory/verdance_understory_navmesh.res"
## The stream's bed (the terrain recipe's STREAM_BED) ...
const STREAM_BED: float = -0.3
## ... and the cut, well below it: the stream stays walkable.
const CLIP: float = -1.0
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
