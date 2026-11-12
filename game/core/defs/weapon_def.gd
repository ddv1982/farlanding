class_name WeaponDef
extends Resource
## Data definition for one weapon. Distances in metres, times in seconds, angles in
## degrees. Presentation (projectile look, impact) and audio (sound set) read the
## fields in their groups; the simulation never does.

@export var id: StringName = &""
@export var display_name: String = ""
@export_group("Damage")
## Damage per projectile (or per instant hit) before the armour multiplier.
@export_range(0.0, 10000.0, 0.5) var damage: float = 10.0
## Row of the DamageTable: &"light", &"heavy" or &"pierce".
@export var damage_type: StringName = &"light"
## Splash radius at the impact point; 0 = only the target is hit. Splash damage falls
## off to half at the edge and never hurts the shooter's own faction.
@export_range(0.0, 30.0, 0.1, "suffix:m") var splash_radius: float = 0.0
@export_group("Firing")
## Reach from the shooter to the target's body edge.
@export_range(1.0, 200.0, 0.5, "suffix:m") var max_range: float = 15.0
## Seconds between shots.
@export_range(0.05, 60.0, 0.05, "suffix:s") var cooldown: float = 1.0
## Projectiles per shot (a twin gun fires 2), side by side `salvo_spacing` apart.
@export_range(1, 8, 1) var salvo: int = 1
@export_range(0.0, 5.0, 0.05, "suffix:m") var salvo_spacing: float = 0.5
## Metres per second; 0 = instant hit (lances, beams).
@export_range(0.0, 500.0, 1.0, "suffix:m/s") var projectile_speed: float = 60.0
## Apex of a lobbed shot at full range (shells); 0 = straight.
@export_range(0.0, 30.0, 0.1, "suffix:m") var arc_height: float = 0.0
## True if the weapon may fire while its carrier is moving.
@export var fire_while_moving: bool = false
## True if the weapon sits on a turret that turns on its own; false = it fires along
## the body, which turns to face the target.
@export var turret: bool = true
## Turret turn speed.
@export_range(1.0, 1440.0, 1.0, "suffix:°/s") var turn_speed: float = 240.0
## The weapon fires when its aim is within this angle of the target.
@export_range(1.0, 180.0, 1.0, "suffix:°") var fire_arc: float = 10.0
## Muzzle in the carrier's local space (-Z forward, origin on the ground).
@export var muzzle: Vector3 = Vector3(0.0, 1.2, -1.0)
@export_group("Presentation")
## &"bolt", &"shell" or &"lance".
@export var projectile_style: StringName = &"bolt"
## 0 = sparks only; larger = explosion radius in metres.
@export_range(0.0, 20.0, 0.1, "suffix:m") var impact_size: float = 0.0
@export var sound_set: StringName = &""


## Seconds a projectile needs for `distance`; 0 for instant weapons.
func travel_time(distance: float) -> float:
	return distance / projectile_speed if projectile_speed > 0.0 else 0.0
