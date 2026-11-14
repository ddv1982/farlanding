class_name CommanderProfile
extends Resource
## What one enemy commander builds and how it weighs its goals (PLAN 3.5): its roster,
## its opening (a build order in data), its economy, defence, scouting and attack
## tunables, and its three difficulty levels. One `.tres` per faction personality.

@export var display_name: String = "Combine commander"
## Seed for the commander's random choices (unit mix, mistakes), so games repeat.
@export var random_seed: int = 7
@export_group("Roster")
## The headquarters: makes harvesters and builders, takes Alloy.
@export var hq: BuildingDef
## The unit factory.
@export var factory: BuildingDef
## The defence tower.
@export var defence: BuildingDef
@export var harvester: UnitDef
@export var builder: UnitDef
## Cheap, fast unit sent to explore.
@export var scout: UnitDef
## Armed units the factories make, with their relative weights.
@export var army: Array[UnitDef] = []
@export var army_weights: PackedFloat32Array = PackedFloat32Array()
## Unit whose weight grows with the share of heavy armour seen in the enemy army.
@export var anti_heavy: UnitDef
## Unit that shoots flying units (ADR 0016): its weight grows with the share of flyers
## seen in the enemy army, and it is made even when not in `army`.
@export var anti_air: UnitDef
## Building that adds power capacity (the Concord Reactor), or null when the HQ's
## power is enough (the Combine Hub). One is built whenever free power falls below
## `power_margin`.
@export var power_plant: BuildingDef
@export_range(0, 100, 1) var power_margin: int = 6
@export_group("Opening")
## Build order played first, step by step in this order: a unit is queued at a
## producer that makes it, a building is placed by a builder. A step waits until it is
## affordable; a step that cannot be done at all (nothing makes it) is skipped.
@export var opening: Array[EntityDef] = []
@export_group("Economy")
## Harvesters wanted per known deposit near home.
@export_range(0.0, 5.0, 0.5) var harvesters_per_deposit: float = 2.0
@export_range(0, 40, 1) var max_harvesters: int = 8
@export_range(0, 10, 1) var max_builders: int = 2
@export_range(0, 10, 1) var max_factories: int = 3
## A further factory is built once Alloy in the bank exceeds this.
@export_range(0, 10000, 10) var factory_bank: int = 350
## Below this much Alloy with too few harvesters the commander counts as poor.
@export_range(0, 10000, 10) var poor_alloy: int = 150
## Deposits within this distance of home feed the base.
@export_range(10.0, 300.0, 5.0, "suffix:m") var deposit_radius: float = 70.0
@export_group("Defence")
## Enemies within this distance of home count as an attack on the base.
@export_range(10.0, 200.0, 5.0, "suffix:m") var base_radius: float = 45.0
## Armed units kept at home when a wave leaves.
@export_range(0, 50, 1) var home_guard_size: int = 3
## Factories stop making army units (and the Alloy banks) once the free army reaches
## the home guard plus this many times the next wave's size; an attack on the base
## lifts the cap.
@export_range(0.5, 5.0, 0.05) var army_cap_waves: float = 1.25
@export_range(0, 20, 1) var max_defences: int = 4
## One more defence tower is wanted for every this many attacks on the base.
@export_range(1, 20, 1) var attacks_per_defence: int = 1
@export_group("Scouting")
## Side of the squares the map is split into for scouting, in metres.
@export_range(8.0, 100.0, 1.0, "suffix:m") var sector_size: float = 24.0
## An explored square is worth a fresh look after this long.
@export_range(10.0, 3600.0, 5.0, "suffix:s") var stale_seconds: float = 150.0
## Seconds between two scouts when the last one died.
@export_range(0.0, 3600.0, 5.0, "suffix:s") var scout_cooldown_seconds: float = 60.0
@export_group("Combat")
## Seen enemy units are forgotten this long after they were last seen.
@export_range(1.0, 600.0, 1.0, "suffix:s") var memory_seconds: float = 40.0
## A group fights enemies it sees within this distance of its centre.
@export_range(5.0, 100.0, 1.0, "suffix:m") var contact_radius: float = 30.0
## A group falls back when the enemy strength it sees is this many times its own.
@export_range(1.0, 10.0, 0.1) var retreat_ratio: float = 1.6
## A group also falls back once its strength drops below this share of its start.
@export_range(0.0, 1.0, 0.05) var retreat_losses: float = 0.3
## Members count as gathered within this distance of the staging point.
@export_range(2.0, 60.0, 1.0, "suffix:m") var gather_radius: float = 14.0
## A group stops to regroup when a member is this far from its centre.
@export_range(5.0, 200.0, 1.0, "suffix:m") var regroup_spread: float = 26.0
## Longest wait while gathering or regrouping.
@export_range(1.0, 300.0, 1.0, "suffix:s") var gather_timeout_seconds: float = 30.0
## Sim ticks between two looks of each unit behaviour (group, scout).
@export_range(1, 50, 1) var behaviour_interval_ticks: int = 5
@export_group("Goals")
## Weights multiplied onto each goal's score.
@export_range(0.0, 5.0, 0.05) var economy_weight: float = 1.0
@export_range(0.0, 5.0, 0.05) var defence_weight: float = 1.2
@export_range(0.0, 5.0, 0.05) var scout_weight: float = 0.7
@export_range(0.0, 5.0, 0.05) var attack_weight: float = 1.0
## Alloy kept back for economy steps before army units are bought.
@export_range(0, 5000, 10) var economy_reserve: int = 100
@export_group("Weather")
## What the commander does about a dust storm (public knowledge: everyone sees it
## coming). &"hold": no new waves while one blows or is about to, and a wave out in
## the open is called home when it hits. &"press": the next wave leaves as the storm
## arrives, even under strength, using the cover.
@export_enum("hold", "press") var storm_tactic: String = "hold"
@export_group("Tide")
## What the commander does about a tide (public knowledge, ADR 0014). &"causeway": a
## group crossing the deep channel while the shallows are unsafe walks through the
## map's dry crossing; &"wait": no new wave leaves until the sea is back at low water
## with `tide_safe_seconds` to spare (groups out still use the causeway).
@export_enum("causeway", "wait") var tide_tactic: String = "causeway"
## The shallows count as safe while they stay dry at least this long.
@export_range(0.0, 600.0, 5.0, "suffix:s") var tide_safe_seconds: float = 70.0
@export_group("Vents")
## Emberfall (ADR 0015). The building the commander puts on Flux vents (the Combine
## Siphon), or null for none; it keeps `extractors_wanted` of them on known vents near
## home that are not about to burst.
@export var extractor: BuildingDef
@export_range(0, 10, 1) var extractors_wanted: int = 0
## Its Taps vent on purpose from this pressure on (0 = never).
@export_range(0.0, 1.0, 0.05) var vent_at_pressure: float = 0.7
## Its units leave a vent's radius when it bursts within this many seconds.
@export_range(0.0, 120.0, 1.0, "suffix:s") var vent_flee_seconds: float = 20.0
@export_group("Machinery")
## Hollow Meridian (ADR 0017): Antecedent engines the commander tries to run (0 = it
## leaves them alone). It sends an idle builder to reactivate the nearest one it has
## explored, with an escort when it has seen Custodians guarding it.
@export_range(0, 16, 1) var machines_wanted: int = 0
## Armed units sent along with the builder when Custodians guard the engine or another
## faction runs it.
@export_range(0, 20, 1) var machine_escort: int = 3
## Also takes over engines the enemy runs (or claims ones it shut down).
@export var machine_takeover: bool = true
## Armed units sent to an engine of its own that is under attack or being taken over.
@export_range(0, 20, 1) var machine_defenders: int = 3
@export_group("Recovery")
## Sends a squad to take carriable props (artefacts) home (a Recovery mission's rival).
@export var retrieves_cargo: bool = false
## Armed units in the squad.
@export_range(1, 20, 1) var retrieve_squad_size: int = 3
## The squad sets out this long after the mission began.
@export_range(0.0, 1200.0, 5.0, "suffix:s") var retrieve_after_seconds: float = 90.0
@export_group("Survey")
## Unit that scans discovery sites for the faction's Intel (null = it never scans).
@export var surveyor: UnitDef
## How many units of `surveyor` are kept scanning (extra ones are made at the HQ).
@export_range(0, 10, 1) var surveyors_wanted: int = 0
## Scanning starts this long after the mission began.
@export_range(0.0, 1200.0, 5.0, "suffix:s") var survey_after_seconds: float = 45.0
@export_group("Difficulty")
@export var easy: CommanderDifficulty
@export var normal: CommanderDifficulty
@export var hard: CommanderDifficulty


## The difficulty called `difficulty_id` (&"easy", &"normal", &"hard"); normal when
## unknown or missing.
func difficulty(difficulty_id: StringName) -> CommanderDifficulty:
	var found: CommanderDifficulty = normal
	match difficulty_id:
		&"easy":
			found = easy
		&"hard":
			found = hard
	if found == null:
		found = normal if normal != null else CommanderDifficulty.new()
	return found


## Weight of `def` in the army mix (0 when not listed).
func weight_of(def: UnitDef) -> float:
	var index: int = army.find(def)
	if index < 0:
		return 0.0
	return army_weights[index] if index < army_weights.size() else 1.0
