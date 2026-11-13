class_name BakeThalassaNavmesh
extends SceneTree
## Rebuilds Thalassa Tidewater's flood-stage navmeshes from the terrain collider (ADR
## 0014). Run after the terrain or the tide's numbers change:
##   godot --headless --path game -s res://maps/thalassa_tidewater/bake_thalassa_navmesh.gd
## Stage k is used while the sea stands from LEVELS[k] up to the next stage's level;
## its ground lower than CLIPS[k] (that next level minus the wading depth, the top
## stage up to high water) is cut away, so a route closes before the water on it gets
## deeper than a unit can wade. Stage 0 is baked from the terrain with that ground cut
## from the source geometry; the higher stages are stage 0 with its polygons clipped
## where the terrain crosses their height (NavmeshTools.clip_navmesh), so every stage
## has the same polygons on dry ground and a unit's route changes only at the water.
## The numbers must match `data/maps/thalassa_tidewater_map.tres` (a test checks).

const VISUALS: String = "res://maps/thalassa_tidewater/thalassa_visuals.tscn"
const OUTPUTS: PackedStringArray = [
	"res://maps/thalassa_tidewater/thalassa_navmesh_stage0.res",
	"res://maps/thalassa_tidewater/thalassa_navmesh_stage1.res",
	"res://maps/thalassa_tidewater/thalassa_navmesh_stage2.res",
	"res://maps/thalassa_tidewater/thalassa_navmesh_stage3.res",
]
## The sea level each stage applies from (low water first): stage 0 holds the low
## water, when the fords are open; stage 1 closes their necks (about -0.7 to -1.1 m),
## stage 2 the fords' bars and the tidal pans (-0.55 m), stage 3 holds the high water.
const LEVELS: PackedFloat32Array = [-1.3, -0.95, -0.45, -0.15]
## Ground below this is cut from each stage's navmesh: the next stage's level minus
## the wading depth (0.25 m), the top stage up to high water (0.15 m).
const CLIPS: PackedFloat32Array = [-1.2, -0.7, -0.4, -0.1]
## The terrain's extent (the map's MapDef), sampled to clip the higher stages.
const TERRAIN_AREA: Rect2 = Rect2(-120.0, -120.0, 240.0, 240.0)
## The navigation map's merge rasteriser scale: edges are cleaned as it joins them.
const MERGE_SCALE: float = 0.1
## A point on the Concord base's shoal; islands not connected to it are dropped.
const KEEP_POINT: Vector3 = Vector3(-80.0, 2.2, 85.0)

var _visuals: Node


func _initialize() -> void:
	var packed: PackedScene = load(VISUALS)
	_visuals = packed.instantiate()
	root.add_child(_visuals)


# The scene is only inside the tree once the first frame starts.
func _process(_delta: float) -> bool:
	var failed: bool = false
	var lowest: NavigationMesh = null
	var ground: HeightField = HeightField.from_physics(
		_visuals.get_viewport().world_3d.direct_space_state, TERRAIN_AREA, 1.0
	)
	for stage: int in OUTPUTS.size():
		var started: int = Time.get_ticks_msec()
		var kept: NavigationMesh = null
		if stage == 0:
			var baked: NavigationMesh = NavmeshTools.bake_from_colliders(_visuals, CLIPS[0])
			var cleaned: NavigationMesh = NavmeshTools.remove_nonmanifold_edges(
				NavmeshTools.remove_nonmanifold_edges(baked), MERGE_SCALE
			)
			lowest = NavmeshTools.keep_island(cleaned, KEEP_POINT)
			kept = lowest
		else:
			kept = NavmeshTools.remove_nonmanifold_edges(
				NavmeshTools.clip_navmesh(lowest, CLIPS[stage], ground), MERGE_SCALE
			)
		print(
			(
				"bake stage %d (ground below %.2f m cut): %d polygons / %d vertices, %d ms"
				% [
					stage,
					CLIPS[stage],
					kept.get_polygon_count(),
					kept.get_vertices().size(),
					Time.get_ticks_msec() - started,
				]
			)
		)
		var error: Error = ResourceSaver.save(kept, OUTPUTS[stage], ResourceSaver.FLAG_COMPRESS)
		failed = failed or error != OK
	_visuals.free()
	quit(1 if failed else 0)
	return true
