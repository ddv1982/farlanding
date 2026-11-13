class_name DiscoveryFixture
extends RefCounted
## A small mission for discovery tests: the combat fixture's world (straight-line
## paths, no terrain), optionally with fog of war, plus a Surveyor, discovery
## definitions of each type, a dormant Warden and a Survey Lab with three field
## options, all built in code. Time advances only through `tick()`.

const AREA: Rect2 = Rect2(-100.0, -100.0, 200.0, 200.0)

var combat: CombatFixture
var base: EconomyFixture
var world: SimWorld
var surveyor: UnitDef
var warden: UnitDef
var lab: BuildingDef
var rich: ResourceNodeDef
var orbital_scan: FieldOptionDef
var supply_drop: FieldOptionDef
var lance: FieldOptionDef


## `with_vision` turns fog of war on (before anything spawns).
func _init(parent: Node, with_vision: bool = false) -> void:
	combat = CombatFixture.new(parent)
	base = combat.base
	world = combat.world
	if with_vision:
		world.enable_vision(AREA, 2.0)
	surveyor = UnitDef.new()
	surveyor.id = &"surveyor"
	surveyor.display_name = "Surveyor"
	surveyor.move_speed = 10.0
	surveyor.acceleration = 40.0
	surveyor.turn_speed = 1440.0
	surveyor.radius = 1.0
	surveyor.vision_range = 20.0
	surveyor.max_health = 100
	surveyor.scan_rate = 1.0
	surveyor.scan_range = 4.0
	warden = UnitDef.new()
	warden.id = &"warden"
	warden.display_name = "Warden"
	warden.max_health = 400
	warden.armour_type = &"heavy"
	warden.weapon = combat.rifle
	warden.move_speed = 3.0
	warden.acceleration = 40.0
	warden.turn_speed = 1440.0
	warden.radius = 1.0
	warden.vision_range = 20.0
	warden.starts_dormant = true
	warden.wake_radius = 6.0
	warden.guard_radius = 25.0
	rich = ResourceNodeDef.new()
	rich.id = &"rich"
	rich.resource = &"alloy"
	rich.amount = 3000
	rich.radius = 2.0
	orbital_scan = _option(&"orbital_scan", FieldOptionDef.EFFECT_REVEAL, 40, 60.0)
	orbital_scan.radius = 20.0
	orbital_scan.seconds = 10.0
	supply_drop = _option(&"supply_drop", FieldOptionDef.EFFECT_SUPPLY_DROP, 60, 90.0)
	supply_drop.flux = 75
	supply_drop.node = rich
	lance = _option(&"antecedent_power", FieldOptionDef.EFFECT_STRIKE, 80, 120.0)
	lance.requires_unlock = true
	lance.radius = 8.0
	lance.damage = 150.0
	lance.damage_type = &"heavy"
	lab = BuildingDef.new()
	lab.id = &"survey_lab"
	lab.footprint = Rect2(-3, -3, 6, 6)
	lab.max_health = 500
	lab.field_options = [orbital_scan, supply_drop, lance]


func dispose() -> void:
	combat.dispose()


func tick(count: int = 1) -> void:
	base.tick(count)


func push(command: Command) -> void:
	base.push(command)


func pile(faction: int = 0) -> Stockpile:
	return world.economy.stockpile(faction)


## A discovery of `type` paying out `payoff`, with a 2 s scan.
func discovery(
	id: StringName, type: StringName = DiscoveryDef.GEOLOGICAL, payoff: StringName = &"none"
) -> DiscoveryDef:
	var def: DiscoveryDef = DiscoveryDef.new()
	def.id = id
	def.display_name = String(id)
	def.discovery_type = type
	def.payoff = payoff
	def.intel_reward = 50
	def.scan_time = 2.0
	def.radius = 2.0
	def.blocks_movement = false
	def.codex_title = "Entry %s" % id
	def.codex_text = "Text of %s." % id
	return def


func site(def: DiscoveryDef, at: Vector3, charted: bool = true) -> DiscoverySite:
	return world.spawn_site(def, at, charted)


func spawn(def: UnitDef, faction: int, at: Vector3) -> Unit:
	return world.spawn_unit(def, faction, at)


## Orders `scanner` to scan `target` and runs `ticks` sim ticks.
func scan(scanner: Unit, target: DiscoverySite, ticks: int = 0) -> void:
	push(ScanCommand.new(scanner.faction, [scanner] as Array[Node3D], target))
	tick(ticks)


func _option(id: StringName, effect: StringName, cost: int, cooldown: float) -> FieldOptionDef:
	var option: FieldOptionDef = FieldOptionDef.new()
	option.id = id
	option.display_name = String(id)
	option.effect = effect
	option.intel_cost = cost
	option.cooldown = cooldown
	return option
