class_name WaveRules
extends Resource
## Data for WaveScript (ADR 0015): escalating enemy waves against a site, a planet
## climax at a set time, and the extraction that ends a Holdout. Reusable by any
## mission that names WaveScript.

## Mission seconds at which each wave arrives at its entry point.
@export var wave_seconds: PackedFloat32Array = PackedFloat32Array()
## Units in each wave (one entry per `wave_seconds` entry).
@export var wave_sizes: PackedInt32Array = PackedInt32Array()
## The units a wave is made of, taken in turn; a later wave starts where the last
## left off, so heavier types listed last appear more as waves grow.
@export var roster: Array[UnitDef] = []
## Where waves enter, taken in turn.
@export var entry_points: PackedVector3Array = PackedVector3Array()
## The Advisor says `wave_incoming` this long before a wave arrives.
@export_range(0.0, 120.0, 1.0, "suffix:s") var warning_seconds: float = 20.0
## Mission seconds at which the planet's climax begins (Emberfall: the caldera's
## surge); 0 = none.
@export_range(0.0, 7200.0, 1.0, "suffix:s") var climax_seconds: float = 0.0
## The survive objective whose countdown is the extraction.
@export var extraction_objective: StringName = &"await_extraction"
## The Advisor says `extraction_inbound` this long before the extraction arrives.
@export_range(0.0, 600.0, 1.0, "suffix:s") var inbound_seconds: float = 60.0


## Units of wave `index`.
func wave_size(index: int) -> int:
	return wave_sizes[index] if index >= 0 and index < wave_sizes.size() else 0


## Number of waves.
func wave_count() -> int:
	return mini(wave_seconds.size(), wave_sizes.size())
