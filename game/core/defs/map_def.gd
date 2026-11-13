class_name MapDef
extends Resource
## A landing map's layout as data (ADR 0014): its terrain area, landing zone and build
## bounds, its baked navmesh (and, on a tidal map, one navmesh per flood stage), the
## resource nodes, discovery sites, dormant Custodians and natural cover it places on
## every mission, and the always-dry crossings the enemy AI may route through. The map
## scene (`maps/landing_map.tscn` inherited, plus the map's visuals) names one; the
## LandingMap script reads it. A new map is a visuals scene, a baked navmesh and one of
## these, not new code.

@export var id: StringName = &""
@export var display_name: String = ""
## The minimap's ground colours: low ground and high ground (hill-shaded between).
@export var minimap_low: Color = Color(0.42, 0.33, 0.25)
@export var minimap_high: Color = Color(0.78, 0.66, 0.52)
## The terrain's extent (world X/Z); heights, the walk grid and vision cover it.
@export var terrain_area: Rect2 = Rect2(-120.0, -120.0, 240.0, 240.0)
## Height field sample spacing, in metres.
@export_range(0.25, 4.0, 0.25, "suffix:m") var height_spacing: float = 1.0
## Vision grid cell size, in metres.
@export_range(0.5, 8.0, 0.5, "suffix:m") var vision_cell: float = 2.0
## The usual landing site (the conquest Lander's place; the camera without a mission).
@export var landing_zone: Vector3 = Vector3.ZERO
## Buildings may only be placed inside this area (world X/Z).
@export var build_bounds: Rect2 = Rect2(-104.0, -104.0, 208.0, 208.0)
## Played when nothing set the map's `mission` (a path: the mission names the map).
@export_file("*.tres") var default_mission_path: String = ""
@export_group("Navigation")
## The navmesh baked from the terrain (the lowest flood stage on a tidal map).
@export var navmesh: NavigationMesh
## Further flood stages of a tidal map, lowest first: the terrain baked again with the
## ground a rising sea closes cut away (`bake_thalassa_navmesh.gd`). Empty = no sea.
@export var flood_navmeshes: Array[NavigationMesh] = []
## Per stage, `navmesh` first: the sea level (metres) from which the stage applies.
@export var flood_levels: PackedFloat32Array = PackedFloat32Array()
## Per stage, `navmesh` first: ground lower than this was cut from the stage's navmesh
## (the top of the stage's sea levels minus the wading depth).
@export var flood_clips: PackedFloat32Array = PackedFloat32Array()
## Crossings that stay dry at any tide (a causeway): the enemy routes a wave through
## the nearest one when the shallows will flood before it is across.
@export var dry_crossings: PackedVector3Array = PackedVector3Array()
@export_group("Canopy")
## Tree crowns (Verdance, ADR 0016): ellipses on the ground, one Vector4 each as
## (centre x, centre z, radius x, radius z). Ground units standing inside are under
## canopy; a CanopyRule hides them from the air and from far away.
@export var canopy_zones: PackedVector4Array = PackedVector4Array()
@export_group("Resources")
@export var deposit: ResourceNodeDef
@export var deposit_positions: PackedVector3Array = PackedVector3Array()
@export var rich_deposit: ResourceNodeDef
@export var rich_deposit_positions: PackedVector3Array = PackedVector3Array()
@export var vent: ResourceNodeDef
@export var vent_positions: PackedVector3Array = PackedVector3Array()
## Rich vents (Emberfall's erupting ones), a second kind of vent.
@export var rich_vent: ResourceNodeDef
@export var rich_vent_positions: PackedVector3Array = PackedVector3Array()
@export_group("Discovery")
## Discovery sites, one position per entry of `discovery_positions`.
@export var discoveries: Array[DiscoveryDef] = []
@export var discovery_positions: PackedVector3Array = PackedVector3Array()
## Dormant Custodians, one position per entry of `custodian_positions`.
@export var custodian_roster: Array[UnitDef] = []
@export var custodian_positions: PackedVector3Array = PackedVector3Array()
@export_group("Props")
## Natural cover every mission on this map has; the mission adds its own.
@export var prop_layout: PropLayout


## True when the map has more than one flood stage (a tidal sea).
func has_flood_stages() -> bool:
	return not flood_navmeshes.is_empty()


## Every stage's navmesh, the base one first.
func stage_navmeshes() -> Array[NavigationMesh]:
	var stages: Array[NavigationMesh] = [navmesh]
	stages.append_array(flood_navmeshes)
	return stages
