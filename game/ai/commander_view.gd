class_name CommanderView
extends RefCounted
## A snapshot of what the commander's faction has and knows at one decision: its own
## stockpile, buildings and units (it may see all of its own), and the summary of its
## knowledge of the enemy (only what its vision grid has seen). The brain decides from
## this alone, so tests can fill one in by hand.

var tick: int = 0
var alloy: int = 0
var flux: int = 0
## Power capacity left (produced - used).
var power_free: int = 0
## Centre of the base (the HQ, or the first building left).
var home: Vector3 = Vector3.ZERO
## Where finished army units wait (in front of the base, towards the map).
var staging: Vector3 = Vector3.ZERO
## Operational own buildings that produce units.
var producers: Array[Building] = []
## Own buildings still under construction.
var sites: Array[Building] = []
## Own buildings per def id (operational and sites).
var building_counts: Dictionary[StringName, int] = {}
## Own units per def id, plus units queued at producers.
var unit_counts: Dictionary[StringName, int] = {}
var builders: Array[Unit] = []
var idle_builders: Array[Unit] = []
var idle_harvesters: Array[Unit] = []
## Armed units not in a group or scouting.
var guards: Array[Unit] = []
## All armed units.
var army: Array[Unit] = []
var army_strength: float = 0.0
var guard_strength: float = 0.0
## Known minable deposits within the profile's deposit radius of home.
var deposits_near_home: int = 0
## Enemy strength seen near home lately, and where.
var threat_strength: float = 0.0
var threat_position: Vector3 = Vector3.ZERO
## Where an attack would go (only from what was seen); valid when has_target.
var attack_target: Vector3 = Vector3.ZERO
var has_target: bool = false
var known_enemy_buildings: int = 0
var enemy_heavy_share: float = 0.0
## Share of the map seen at least once.
var explored_share: float = 0.0
var scout_active: bool = false
## The weather (public): storm intensity 0..1, seconds until an announced storm (INF
## if none), and whether it is the storm that never lifts.
var storm_intensity: float = 0.0
var storm_eta_seconds: float = INF
var storm_is_final: bool = false
## Own units of the profile's surveyor kind scanning for Intel, and all of that kind.
var surveying: int = 0
var surveyor_count: int = 0
## True once the profile's survey delay has passed.
var survey_open: bool = false
var attack_active: bool = false
var defence_active: bool = false


## Own count of `def` (buildings or units, including queued units).
func count_of(def: EntityDef) -> int:
	if def == null:
		return 0
	if def is BuildingDef:
		return building_counts.get(def.id, 0)
	return unit_counts.get(def.id, 0)


## True while the faction can still make units somewhere.
func has_production() -> bool:
	return not producers.is_empty()


## Operational producers that can make `def`, shortest queue first.
func producers_of(def: UnitDef) -> Array[Building]:
	var result: Array[Building] = []
	for building: Building in producers:
		if building.producer != null and building.producer.options.has(def):
			result.append(building)
	result.sort_custom(
		func(a: Building, b: Building) -> bool:
			return a.producer.queue.size() < b.producer.queue.size()
	)
	return result


## Builders that can build `def`, idle ones first.
func builders_of(def: BuildingDef) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in idle_builders:
		if unit.def.builds.has(def):
			result.append(unit)
	for unit: Unit in builders:
		if unit.def.builds.has(def) and not result.has(unit):
			result.append(unit)
	return result
