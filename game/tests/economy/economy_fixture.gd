class_name EconomyFixture
extends RefCounted
## A small mission for economy tests: a SimWorld on a straight-line PathService with
## no terrain, and definitions built in code (no scenes or models). Tick it with
## `tick()`; everything runs through the real CommandQueue and SimClock.

const DT: float = SimClock.TICK_DELTA

var context: MissionContext
var world: SimWorld
var rules: EconomyRules
var hauler: UnitDef
var fabricator: UnitDef
var ranger: UnitDef
var lander: BuildingDef
var refinery: BuildingDef
var reactor: BuildingDef
var barracks: BuildingDef
var tap: BuildingDef
var deposit: ResourceNodeDef
var vent: ResourceNodeDef


## Builds the fixture under `parent` (a GutTest, which frees it with autofree).
func _init(parent: Node) -> void:
	rules = EconomyRules.new()
	rules.start_alloy = 1000
	rules.start_flux = 100
	rules.low_power_rate = 0.5
	rules.deposit_search_radius = 60.0
	context = MissionContext.new()
	context.sim_clock.paused = true  # only tick() advances time
	parent.add_child(context)
	world = SimWorld.new()
	parent.add_child(world)
	world.setup(context, PathService.new(), null, rules, 0)
	hauler = _unit_def(&"hauler", 10.0, 1.0)
	hauler.carry_capacity = 50
	hauler.mine_time = 2.0
	hauler.unload_time = 1.0
	hauler.cost_alloy = 120
	hauler.build_time = 4.0
	fabricator = _unit_def(&"fabricator", 8.0, 0.8)
	fabricator.build_rate = 1.0
	fabricator.work_range = 3.0
	fabricator.cost_alloy = 100
	ranger = _unit_def(&"ranger", 6.0, 0.8)
	ranger.cost_alloy = 75
	ranger.build_time = 10.0
	# A weak gun: attacks hold for a long time, so tests can rely on busy units.
	ranger.weapon = WeaponDef.new()
	ranger.weapon.max_range = 12.0
	ranger.weapon.damage = 1.0
	ranger.weapon.cooldown = 1.0
	ranger.weapon.projectile_speed = 0.0
	refinery = _building_def(&"refinery", Rect2(-4, -4, 8, 8), 20.0)
	refinery.cost_alloy = 250
	refinery.power_use = 4
	refinery.accepts_alloy = true
	refinery.dropoff_priority = 1
	refinery.dock = Vector3(0, 0, -7)
	refinery.free_units = [hauler]
	lander = _building_def(&"lander", Rect2(-5, -5, 10, 10), 60.0)
	lander.power_output = 10
	lander.accepts_alloy = true
	lander.dropoff_priority = 0
	lander.dock = Vector3(8, 0, 0)
	lander.produces = [fabricator, hauler]
	reactor = _building_def(&"reactor", Rect2(-3, -3, 6, 6), 10.0)
	reactor.cost_alloy = 150
	reactor.power_output = 15
	barracks = _building_def(&"barracks", Rect2(-4, -4, 8, 8), 10.0)
	barracks.cost_alloy = 200
	barracks.power_use = 4
	barracks.produces = [ranger]
	barracks.door = Vector3(0, 0, -7)
	tap = _building_def(&"tap", Rect2(-2.5, -2.5, 5, 5), 10.0)
	tap.power_use = 3
	tap.requires_resource = &"flux"
	tap.flux_amount = 5
	tap.flux_interval = 4.0
	fabricator.builds = [reactor, refinery, barracks, tap]
	deposit = ResourceNodeDef.new()
	deposit.id = &"deposit"
	deposit.resource = &"alloy"
	deposit.amount = 200
	deposit.radius = 2.0
	vent = ResourceNodeDef.new()
	vent.id = &"vent"
	vent.resource = &"flux"
	vent.amount = 0
	vent.radius = 2.0
	vent.blocks_movement = false


## Frees the fixture's nodes (call from after_each).
func dispose() -> void:
	world.free()
	context.free()


func tick(count: int = 1) -> void:
	for i: int in count:
		context.sim_clock.paused = false
		context.sim_clock.advance(DT)
		context.sim_clock.paused = true


func pile() -> Stockpile:
	return world.economy.stockpile(0)


func push(command: Command) -> void:
	context.command_queue.push(command)


func _unit_def(id: StringName, speed: float, radius: float) -> UnitDef:
	var def: UnitDef = UnitDef.new()
	def.id = id
	def.display_name = String(id)
	def.move_speed = speed
	def.acceleration = 40.0
	def.turn_speed = 1440.0
	def.radius = radius
	return def


func _building_def(id: StringName, footprint: Rect2, build_time: float) -> BuildingDef:
	var def: BuildingDef = BuildingDef.new()
	def.id = id
	def.display_name = String(id)
	def.footprint = footprint
	def.build_time = build_time
	return def
