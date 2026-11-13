class_name PlanetRuleSystem
extends RefCounted
## Plays a planet's rule (a PlanetRule Resource) in one mission's world (ADR 0011).
## SimWorld ticks it first on every sim tick; it changes the world only through the
## shared WorldConditions (and `Events`), which vision, movement, stealth and combat
## read. Subclasses override the hooks. The HUD shows `indicator_*` for any rule.

var world: SimWorld = null
var rule: PlanetRule = null
var conditions: WorldConditions = null
## Wall-clock cost of the last tick, in microseconds.
var last_tick_usec: int = 0


## Starts `rule` in `world` (its `system` script plays it; the world ticks it first
## on every sim tick). Returns the running system, or null when the rule names none.
static func start(p_world: SimWorld, p_rule: PlanetRule) -> PlanetRuleSystem:
	if p_rule == null or p_rule.system == null:
		return null
	var source: GDScript = p_rule.system as GDScript
	var instance: Variant = source.new() if source != null else null
	var system: PlanetRuleSystem = instance if instance is PlanetRuleSystem else null
	if system == null:
		push_error("Planet rule %s names no PlanetRuleSystem script" % p_rule.id)
		return null
	system.setup(p_world, p_rule)
	p_world.planet = system
	return system


func setup(p_world: SimWorld, p_rule: PlanetRule) -> void:
	world = p_world
	rule = p_rule
	conditions = world.conditions
	_setup()


## One sim tick.
func tick(tick_number: int, dt: float) -> void:
	var started: int = Time.get_ticks_usec()
	_tick(tick_number, dt)
	last_tick_usec = Time.get_ticks_usec() - started


## The mission's climax arrives at sim tick `at_tick` and does not end (Kessel: the
## storm that buries the basin). Rules without one ignore it.
func schedule_climax(_at_tick: int) -> void:
	pass


## Short name for the HUD indicator ("DUST STORM"), or "" to hide it.
func indicator_title() -> String:
	return ""


## Status line for the HUD at `tick` ("CLEAR", "IN 0:35", "FULL").
func indicator_text(_tick_number: int) -> String:
	return ""


## Fill of the HUD bar, 0..1.
func indicator_level() -> float:
	return 0.0


## True when the indicator should draw attention (warning or worse).
func indicator_alarm() -> bool:
	return false


func to_dict() -> Dictionary:
	return {}


func from_dict(_data: Dictionary) -> void:
	pass


func _setup() -> void:
	pass


func _tick(_tick_number: int, _dt: float) -> void:
	pass
