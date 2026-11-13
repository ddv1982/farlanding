class_name MissionFixture
extends RefCounted
## A small mission for objective, stealth and mission-rule tests: the discovery
## fixture's world with fog of war (straight-line paths, no terrain), a Wisp (cloaks,
## sabotages, unarmed), an unarmed guard with a 90° sight cone, and a MissionDef
## built in code that a real Mission runs. Time advances only through `tick()`.

const AREA: Rect2 = DiscoveryFixture.AREA

var parent: Node
var discovery: DiscoveryFixture
var combat: CombatFixture
var base: EconomyFixture
var world: SimWorld
var def: MissionDef
var mission: Mission = null
var wisp: UnitDef
var guard: UnitDef
var target: BuildingDef


func _init(p_parent: Node) -> void:
	parent = p_parent
	discovery = DiscoveryFixture.new(parent, true)
	combat = discovery.combat
	base = discovery.base
	world = discovery.world
	wisp = UnitDef.new()
	wisp.id = &"wisp"
	wisp.display_name = "Wisp"
	wisp.max_health = 90
	wisp.move_speed = 7.0
	wisp.acceleration = 40.0
	wisp.turn_speed = 1440.0
	wisp.radius = 0.6
	wisp.vision_range = 20.0
	wisp.signature = 0.5
	wisp.can_cloak = true
	wisp.cloak_signature = 0.2
	wisp.cloak_max_speed = 2.0
	wisp.cloak_delay = 1.0
	wisp.sabotage_time = 3.0
	wisp.sabotage_range = 2.0
	guard = UnitDef.new()
	guard.id = &"guard"
	guard.display_name = "Guard"
	guard.max_health = 100
	guard.move_speed = 5.0
	guard.acceleration = 40.0
	guard.turn_speed = 1440.0
	guard.radius = 0.5
	guard.vision_range = 20.0
	guard.sight_angle = 90.0
	guard.sensor = 1.0
	target = BuildingDef.new()
	target.id = &"uplink"
	target.footprint = Rect2(-3, -3, 6, 6)
	target.max_health = 800
	target.vision_range = 10.0
	def = MissionDef.new()
	def.id = &"fixture"
	def.title = "Fixture"
	def.player_faction = 0
	def.hostile_faction = 1


func dispose() -> void:
	if mission != null and is_instance_valid(mission):
		mission.free()
	discovery.dispose()


func tick(count: int = 1) -> void:
	base.tick(count)


## The current sim tick.
func mission_tick() -> int:
	return base.context.sim_clock.get_tick()


func push(command: Command) -> void:
	base.push(command)


func spawn(unit_def: UnitDef, faction: int, at: Vector3, yaw: float = 0.0) -> Unit:
	return world.spawn_unit(unit_def, faction, at, yaw)


## An objective definition of `type`; `props` sets any other ObjectiveDef field.
static func objective(
	id: StringName, type: StringName, kind: StringName = &"primary", props: Dictionary = {}
) -> ObjectiveDef:
	var objective_def: ObjectiveDef = ObjectiveDef.new()
	objective_def.id = id
	objective_def.title = String(id)
	objective_def.type = type
	objective_def.kind = kind
	for key: Variant in props:
		objective_def.set(StringName(str(key)), props[key])
	return objective_def


## Runs a Mission over the fixture world with `objectives`. Forces are spawned by
## the test itself; `spawn_units` also places the def's rosters and patrols first.
func start(
	objectives: Array[ObjectiveDef], alert_meter: bool = false, spawn_units: bool = false
) -> Mission:
	def.objectives = objectives
	def.enemy_alert_meter = alert_meter
	mission = Mission.new()
	mission.name = &"Mission"
	parent.add_child(mission)
	mission.setup(def, base.context, world, AREA)
	if spawn_units:
		mission.spawn_units()
	mission.start()
	return mission
