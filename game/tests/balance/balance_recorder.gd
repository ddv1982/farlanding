class_name BalanceRecorder
extends RefCounted
## What one balance run measures (ADR 0018), read from the world and `Events` only:
## when the enemy first hurt the player, army strength of both sides over time,
## losses, Alloy and Flux income and how much sat unspent, Intel, objective timings,
## the waves each commander launched, and the result.

## Seconds between two samples of armies and stockpiles.
const SAMPLE_SECONDS: int = 60

var mission: Mission
var player: int = 0
var enemy: int = 1
## Game seconds of the first damage the enemy faction dealt to the player (-1 = none).
var first_hit_seconds: float = -1.0
## Game seconds when enemy units first came within the attack radius of a player
## building (-1 = never).
var first_attack_seconds: float = -1.0
## Per sample: [seconds, player army, enemy army, player alloy, player flux, engines the
## player runs, engines the enemy runs] (the engines only on a machinery planet).
var samples: Array[Array] = []
## Objective id -> [seconds, "done" | "failed"].
var objectives: Dictionary[String, Array] = {}
var alloy_income: int = 0
var flux_income: int = 0
var peak_player_army: float = 0.0
var peak_enemy_army: float = 0.0
## Sum of unspent Alloy over samples (for the mean float).
var alloy_floated: int = 0
## Damage the player's things took, by who dealt it: "enemy", "custodian" (any other
## faction) or "world" (no attacker: eruptions, the tide).
var damage_taken: Dictionary[String, int] = {"enemy": 0, "custodian": 0, "world": 0}
## Damage the enemy's things took from the player, from Custodians, from the world.
var enemy_damage_taken: Dictionary[String, int] = {"player": 0, "custodian": 0, "world": 0}
var eruptions: int = 0
## Unit type id -> how many died, per side.
var player_losses: Dictionary[String, int] = {}
var enemy_losses: Dictionary[String, int] = {}

var _last_alloy: int = 0
var _last_flux: int = 0
var _on_done: Callable
var _on_failed: Callable


func _init(p_mission: Mission) -> void:
	mission = p_mission
	player = mission.player_faction
	enemy = mission.def.hostile_faction
	var pile: Stockpile = mission.world.economy.stockpile(player)
	_last_alloy = pile.alloy
	_last_flux = pile.flux
	Events.entity_damaged.connect(_on_damaged)
	Events.eruption.connect(_on_eruption)
	Events.entity_died.connect(_on_died)
	Events.resources_changed.connect(_on_resources)
	_on_done = _on_objective.bind("done")
	_on_failed = _on_objective.bind("failed")
	Events.objective_completed.connect(_on_done)
	Events.objective_failed.connect(_on_failed)


func stop() -> void:
	Events.entity_damaged.disconnect(_on_damaged)
	Events.eruption.disconnect(_on_eruption)
	Events.entity_died.disconnect(_on_died)
	Events.resources_changed.disconnect(_on_resources)
	Events.objective_completed.disconnect(_on_done)
	Events.objective_failed.disconnect(_on_failed)


## Called every sim tick.
func on_tick(tick: int) -> void:
	var seconds: float = mission.elapsed_seconds()
	if first_attack_seconds < 0.0 and tick % 10 == 0:
		_check_attack(seconds)
	if tick % (SAMPLE_SECONDS * SimClock.TICK_RATE) != 0:
		return
	var pile: Stockpile = mission.world.economy.stockpile(player)
	var mine: float = army_strength(player)
	var theirs: float = army_strength(enemy)
	peak_player_army = maxf(peak_player_army, mine)
	peak_enemy_army = maxf(peak_enemy_army, theirs)
	alloy_floated += pile.alloy
	var sample: Array = [roundi(seconds), roundi(mine), roundi(theirs), pile.alloy, pile.flux]
	var machinery: MachinerySystem = mission.world.planet as MachinerySystem
	if machinery != null:
		sample.append(machinery.held_by(player).size())
		sample.append(machinery.held_by(enemy).size())
	samples.append(sample)


## Armed strength of `faction` (the AI's measure: cost × health share, armed only).
func army_strength(faction: int) -> float:
	var total: float = 0.0
	for unit: Unit in mission.world.units_of(faction):
		if not unit.is_dead:
			total += AiKnowledge.strength_of(unit)
	return total


## The run's numbers as one dictionary (printed as JSON by the runner).
func summary() -> Dictionary:
	var result: MissionResult = mission.result
	var mean_float: int = alloy_floated / maxi(samples.size(), 1)
	return {
		"won": result != null and result.won,
		"over": result != null,
		"seconds": roundi(mission.elapsed_seconds()),
		"first_hit": roundi(first_hit_seconds),
		"first_attack": roundi(first_attack_seconds),
		"units_lost": mission.units_lost,
		"buildings_lost": mission.buildings_lost,
		"enemies_destroyed": mission.enemies_destroyed,
		"intel": mission.intel_earned,
		"alloy_income": alloy_income,
		"flux_income": flux_income,
		"mean_alloy_float": mean_float,
		"peak_army": roundi(peak_player_army),
		"peak_enemy_army": roundi(peak_enemy_army),
		"enemy_waves": _waves(mission.commander),
		"damage_taken": damage_taken,
		"enemy_damage_taken": enemy_damage_taken,
		"eruptions": eruptions,
		"player_losses": player_losses,
		"enemy_losses": enemy_losses,
		"enemy_left": enemy_left() if result == null else PackedStringArray(),
		"objectives": objectives,
		"samples": samples,
	}


## What the enemy still has standing: "def_id@x,z" per building and unit (timeouts).
func enemy_left() -> PackedStringArray:
	var left: PackedStringArray = []
	for building: Building in mission.world.buildings_of(enemy):
		if not building.is_dead:
			left.append("%s@%d,%d" % [building.def.id, building.position.x, building.position.z])
	for unit: Unit in mission.world.units_of(enemy):
		if not unit.is_dead:
			var at: Vector3 = unit.sim_position()
			left.append("%s@%d,%d" % [unit.def.id, at.x, at.z])
	return left


static func _waves(commander: Commander) -> Array[int]:
	return commander.wave_sizes.duplicate() if commander != null else []


func _check_attack(seconds: float) -> void:
	for building: Building in mission.world.buildings_of(player):
		if building.is_dead:
			continue
		for unit: Unit in mission.world.units_of(enemy):
			if unit.is_dead or unit.weapon == null:
				continue
			if AiGroup.flat_distance(unit.sim_position(), building.position) < 30.0:
				first_attack_seconds = seconds
				return


func _on_damaged(entity: Node3D, amount: float, attacker: Node3D) -> void:
	var victim: int = Combat.faction_of(entity)
	if victim != player and victim != enemy:
		return
	var source: int = Combat.faction_of(attacker) if is_instance_valid(attacker) else -1
	var hit: int = roundi(amount)
	if victim == enemy:
		var key: String = "world"
		if source == player:
			key = "player"
		elif source >= 0:
			key = "custodian"
		enemy_damage_taken[key] += hit
		return
	if source == enemy:
		damage_taken["enemy"] += hit
		if first_hit_seconds < 0.0:
			first_hit_seconds = mission.elapsed_seconds()
	elif source >= 0:
		damage_taken["custodian"] += hit
	else:
		damage_taken["world"] += hit


func _on_died(entity: Node3D) -> void:
	var unit: Unit = entity as Unit
	if unit == null or unit.def == null:
		return
	var key: String = String(unit.def.id)
	if unit.faction == player:
		player_losses[key] = player_losses.get(key, 0) + 1
	elif unit.faction == enemy:
		enemy_losses[key] = enemy_losses.get(key, 0) + 1


func _on_eruption(_vent: Node3D, _radius: float) -> void:
	eruptions += 1


func _on_resources(faction: int, alloy: int, flux: int) -> void:
	if faction != player:
		return
	alloy_income += maxi(alloy - _last_alloy, 0)
	flux_income += maxi(flux - _last_flux, 0)
	_last_alloy = alloy
	_last_flux = flux


func _on_objective(objective: RefCounted, state: String) -> void:
	var found: Objective = objective as Objective
	if found != null and not objectives.has(String(found.id)):
		objectives[String(found.id)] = [roundi(mission.elapsed_seconds()), state]
