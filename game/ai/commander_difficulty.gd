class_name CommanderDifficulty
extends Resource
## One difficulty level of the enemy commander (PLAN 3.5). It changes how often the
## commander thinks, when and with how many units it attacks, and how often it makes a
## mistake. It never changes costs, build times, income or what the commander can see.

@export var id: StringName = &"normal"
@export var display_name: String = "Normal"
## Sim ticks (10 per second) between two decisions.
@export_range(1, 200, 1) var decision_interval_ticks: int = 20
@export_group("Attack")
## No attack is launched before this much game time.
@export_range(0.0, 3600.0, 5.0, "suffix:s") var first_attack_seconds: float = 300.0
## Shortest time between two attack launches.
@export_range(0.0, 3600.0, 5.0, "suffix:s") var attack_interval_seconds: float = 100.0
## Armed units in the first attack wave.
@export_range(1, 100, 1) var first_wave_size: int = 8
## Units added to each later wave.
@export_range(0, 50, 1) var wave_growth: int = 3
## Largest wave.
@export_range(1, 200, 1) var max_wave_size: int = 24
@export_group("Mistakes")
## Chance per attack wave that it goes too early with too few units, and per decision
## that it forgets to answer an attack on its base or leaves its factories idle.
@export_range(0.0, 1.0, 0.01) var mistake_chance: float = 0.1
## A premature wave leaves with this share of the planned size.
@export_range(0.1, 1.0, 0.05) var early_wave_share: float = 0.6
@export_group("Scouting")
## The first scout leaves after this much game time.
@export_range(0.0, 3600.0, 5.0, "suffix:s") var first_scout_seconds: float = 45.0


## Size of attack wave number `wave` (0 = the first).
func wave_size(wave: int) -> int:
	return mini(first_wave_size + wave_growth * maxi(wave, 0), max_wave_size)


## Sim ticks of game time for `seconds`.
static func ticks(seconds: float) -> int:
	return roundi(seconds * SimClock.TICK_RATE)
