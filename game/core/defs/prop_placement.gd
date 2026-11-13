class_name PropPlacement
extends Resource
## One prop on a map or in a mission: which, where, and how it is turned (in quarter
## turns, so its footprint stays an axis-aligned rectangle for the navmesh cut).

@export var def: PropDef
## World X/Z; Y is ignored (placed on the ground).
@export var position: Vector3 = Vector3.ZERO
## 0..3 quarter turns about +Y (1 = 90 degrees: width and depth swap).
@export_range(0, 3, 1) var quarter_turns: int = 0
