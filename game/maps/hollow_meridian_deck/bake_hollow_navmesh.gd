class_name BakeHollowNavmesh
extends SceneTree
## Rebuilds `hollow_meridian_deck_navmesh.res` from the terrain's colliders (ADR 0017):
## the plated deck, the dais and terraces with their ramps, the pylons. Run after the
## terrain changes:
##   godot --headless --path game -s res://maps/hollow_meridian_deck/bake_hollow_navmesh.gd
## One stage, no sea. The chasms have no bottom a unit could reach (their floor is at
## VOID, far below the deck at DECK): the cut at CLIP removes them, so ground units
## cross only on the bridges. Islands the bake leaves on top of pylons and the walls
## are dropped by `keep_island`. Flying units do not use this navmesh.

const VISUALS: String = "res://maps/hollow_meridian_deck/hollow_visuals.tscn"
const OUTPUT: String = "res://maps/hollow_meridian_deck/hollow_meridian_deck_navmesh.res"
## The deck (the terrain recipe's DECK) and the chasms' floor (VOID) ...
const DECK: float = 0.5
const VOID: float = -14.0
## ... and the cut, between them: nothing in a chasm is walkable.
const CLIP: float = -1.0
## The navigation map's merge rasteriser scale: edges are cleaned as it joins them.
const MERGE_SCALE: float = 0.1
## A point on the Concord deck; islands not connected to it are dropped.
const KEEP_POINT: Vector3 = Vector3(-80.0, 1.0, 85.0)

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
