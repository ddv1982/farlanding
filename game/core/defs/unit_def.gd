class_name UnitDef
extends EntityDef
## Data definition for a mobile unit. Distances in metres, speeds per second.

@export_range(1, 100000, 1) var max_health: int = 100
@export_range(0.0, 100.0, 0.1, "suffix:m/s") var move_speed: float = 5.0
@export_range(0.0, 1440.0, 1.0, "suffix:°/s") var turn_speed: float = 360.0
@export_range(0.0, 200.0, 0.5, "suffix:m") var vision_range: float = 20.0
@export_range(0.1, 20.0, 0.1, "suffix:m") var radius: float = 0.5
