class_name AiFixture
extends RefCounted
## A small world for the enemy-AI tests: the combat fixture (straight-line paths, no
## terrain) plus a Combine-like roster built in code — a hub that makes harvesters and
## builders, a forge that makes soldiers and tanks, a tower — and a commander profile
## and difficulty over it. Time advances only through `tick()`.

const AI: int = 1
const ENEMY: int = 0

var combat: CombatFixture
var world: SimWorld
var hub: BuildingDef
var forge: BuildingDef
var tower: BuildingDef
var harvester: UnitDef
var builder: UnitDef
var soldier: UnitDef
var tank: UnitDef
var scout: UnitDef
var profile: CommanderProfile
var difficulty: CommanderDifficulty


func _init(parent: Node) -> void:
	combat = CombatFixture.new(parent)
	world = combat.world
	soldier = combat.soldier
	soldier.cost_alloy = 50
	tank = combat.tank
	tank.cost_alloy = 200
	scout = combat.scout
	scout.cost_alloy = 40
	harvester = UnitDef.new()
	harvester.id = &"harvester"
	harvester.carry_capacity = 20
	harvester.cost_alloy = 90
	harvester.move_speed = 5.0
	harvester.acceleration = 40.0
	builder = UnitDef.new()
	builder.id = &"builder"
	builder.build_rate = 1.0
	builder.cost_alloy = 80
	builder.move_speed = 5.0
	builder.acceleration = 40.0
	tower = BuildingDef.new()
	tower.id = &"tower"
	tower.footprint = Rect2(-1, -1, 2, 2)
	tower.weapon = combat.rifle
	tower.cost_alloy = 130
	tower.power_use = 3
	forge = BuildingDef.new()
	forge.id = &"forge"
	forge.footprint = Rect2(-3, -3, 6, 6)
	forge.produces = [soldier, tank, scout]
	forge.cost_alloy = 220
	forge.power_use = 5
	hub = BuildingDef.new()
	hub.id = &"hub"
	hub.footprint = Rect2(-4, -4, 8, 8)
	hub.produces = [harvester, builder]
	hub.accepts_alloy = true
	hub.power_output = 30
	hub.placeable = false
	builder.builds = [forge, tower]
	difficulty = CommanderDifficulty.new()
	difficulty.decision_interval_ticks = 10
	difficulty.first_attack_seconds = 60.0
	difficulty.attack_interval_seconds = 30.0
	difficulty.first_wave_size = 4
	difficulty.wave_growth = 2
	difficulty.max_wave_size = 10
	difficulty.mistake_chance = 0.0
	difficulty.first_scout_seconds = 10.0
	profile = CommanderProfile.new()
	profile.hq = hub
	profile.factory = forge
	profile.defence = tower
	profile.harvester = harvester
	profile.builder = builder
	profile.scout = scout
	profile.army = [soldier, tank]
	profile.army_weights = PackedFloat32Array([0.7, 0.3])
	profile.anti_heavy = tank
	profile.home_guard_size = 2
	profile.normal = difficulty


func dispose() -> void:
	combat.dispose()


func tick(count: int = 1) -> void:
	combat.tick(count)


## A finished building of `def` for the AI faction.
func building(def: BuildingDef, at: Vector3, faction: int = AI) -> Building:
	return world.spawn_building(def, faction, at, true)


func unit(def: UnitDef, at: Vector3, faction: int = AI) -> Unit:
	return world.spawn_unit(def, faction, at)


## `count` soldiers of `faction` in a row from `at`.
func soldiers(count: int, at: Vector3, faction: int = AI) -> Array[Unit]:
	var spawned: Array[Unit] = []
	for i: int in count:
		spawned.append(unit(soldier, at + Vector3(i * 1.5, 0, 0), faction))
	return spawned


## A view of a small standing base: a hub and a forge, `alloy` in the bank, plenty
## of power, and everything else empty.
func base_view(alloy: int, hub_building: Building, forge_building: Building) -> CommanderView:
	var view: CommanderView = CommanderView.new()
	view.tick = 10
	view.alloy = alloy
	view.power_free = 20
	view.producers = [hub_building, forge_building]
	view.building_counts = {hub.id: 1, forge.id: 1, tower.id: 1}
	view.unit_counts = {}
	return view


## A brain over this fixture's profile with a fixed random seed.
func brain(memory: CommanderMemory = null) -> CommanderBrain:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	return CommanderBrain.new(profile, difficulty, memory, rng)


## An AiPort that records commands and reports `enemies` as seen, for behaviour tests.
class FakePort:
	extends AiPort

	var tick: int = 0
	var enemies: Array[Node3D] = []
	var pushed: Array[Command] = []

	func _init(p_faction: int = 1) -> void:
		faction = p_faction

	func now() -> int:
		return tick

	func push(command: Command) -> void:
		commands_pushed += 1
		pushed.append(command)

	func seen_enemies(_center: Vector3, _radius: float) -> Array[Node3D]:
		var alive: Array[Node3D] = []
		for enemy: Node3D in enemies:
			if Combat.is_alive(enemy):
				alive.append(enemy)
		return alive

	func last_kind() -> StringName:
		return pushed[pushed.size() - 1].kind if not pushed.is_empty() else &""
