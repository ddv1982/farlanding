class_name CombatFixture
extends RefCounted
## A small battlefield for combat tests: the economy fixture's world (straight-line
## paths, no terrain) plus a damage table, weapon and unit definitions built in code.
## Time advances only through `tick()`.

var base: EconomyFixture
var world: SimWorld
var table: DamageTable
## Instant-hit rifle: 10 damage (light), range 10, one shot a second, turret.
var rifle: WeaponDef
## Shell: 40 heavy damage, splash 4 m, 20 m/s, range 20, every 3 s.
var cannon: WeaponDef
var soldier: UnitDef
var tank: UnitDef
var scout: UnitDef
var sentry: BuildingDef
var hq: BuildingDef


func _init(parent: Node) -> void:
	base = EconomyFixture.new(parent)
	world = base.world
	table = DamageTable.new()
	table.multipliers = {
		DamageTable.key(&"light", &"heavy"): 0.5,
		DamageTable.key(&"heavy", &"light"): 0.8,
	}
	world.combat.damage_table = table
	rifle = WeaponDef.new()
	rifle.id = &"rifle"
	rifle.damage = 10.0
	rifle.damage_type = &"light"
	rifle.max_range = 10.0
	rifle.cooldown = 1.0
	rifle.projectile_speed = 0.0
	rifle.turret = true
	rifle.turn_speed = 1440.0
	cannon = WeaponDef.new()
	cannon.id = &"cannon"
	cannon.damage = 40.0
	cannon.damage_type = &"heavy"
	cannon.splash_radius = 4.0
	cannon.max_range = 20.0
	cannon.cooldown = 3.0
	cannon.projectile_speed = 20.0
	cannon.turret = true
	cannon.turn_speed = 1440.0
	soldier = _unit(&"soldier", 100, &"light", rifle)
	tank = _unit(&"tank", 400, &"heavy", cannon)
	scout = _unit(&"scout", 50, &"light", null)
	scout.vision_range = 30.0
	sentry = BuildingDef.new()
	sentry.id = &"sentry"
	sentry.footprint = Rect2(-1, -1, 2, 2)
	sentry.max_health = 300
	sentry.power_use = 5
	sentry.weapon = rifle
	sentry.vision_range = 15.0
	hq = BuildingDef.new()
	hq.id = &"hq"
	hq.footprint = Rect2(-3, -3, 6, 6)
	hq.max_health = 500
	hq.power_output = 10


func dispose() -> void:
	base.dispose()


func tick(count: int = 1) -> void:
	base.tick(count)


func push(command: Command) -> void:
	base.push(command)


func spawn(def: UnitDef, faction: int, at: Vector3) -> Unit:
	return world.spawn_unit(def, faction, at)


func _unit(id: StringName, health: int, armour: StringName, weapon: WeaponDef) -> UnitDef:
	var def: UnitDef = UnitDef.new()
	def.id = id
	def.display_name = String(id)
	def.max_health = health
	def.armour_type = armour
	def.weapon = weapon
	def.move_speed = 5.0
	def.acceleration = 40.0
	def.turn_speed = 1440.0
	def.radius = 0.5
	def.vision_range = 20.0
	return def
