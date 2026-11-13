class_name SurveyBehaviour
extends AiGroup
## The commander's own surveyors (the Combine's Riggers in the Survey race, ADR 0011):
## each idle member is sent to scan the nearest open discovery site (charted on the
## orbital scan, which everyone has, and unresolved) that no other member is working
## on. A surveyor that sees enemies close by drops the scan and runs home for a while,
## so the player can chase them off, and kill them: they are unarmed and must walk to
## every site. It never ends on its own; dead members are replaced by the commander.

## Enemies within this distance make a surveyor run.
const DANGER_RADIUS: float = 16.0
## A surveyor that ran waits this long before it is sent out again, in sim ticks.
const SHY_TICKS: int = 200

## Where a frightened surveyor runs to.
var home: Vector3 = Vector3.ZERO
## Sites scanned to the end so far (logs, tests).
var scans_started: int = 0

## Unit -> sim tick before which it is not sent out again.
var _shy_until: Dictionary[Unit, int] = {}
## Unit -> the site it was sent to.
var _assigned: Dictionary[Unit, Node3D] = {}


func _init(p_port: AiPort, p_profile: CommanderProfile, p_members: Array[Unit]) -> void:
	super(p_port, p_profile, p_members)


## Takes `unit` into the survey.
func add(unit: Unit) -> void:
	if unit != null and not members.has(unit):
		members.append(unit)


func tick(sim_tick: int) -> void:
	prune()
	for unit: Variant in _assigned.keys():
		if not members.has(unit):
			_assigned.erase(unit)
	for unit: Variant in _shy_until.keys():
		if not members.has(unit):
			_shy_until.erase(unit)
	var sites: Array[Node3D] = port.open_sites()
	for unit: Unit in members:
		_step(unit, sites, sim_tick)


func _step(unit: Unit, sites: Array[Node3D], sim_tick: int) -> void:
	var at: Vector3 = unit.sim_position()
	if not port.seen_enemies(at, DANGER_RADIUS).is_empty():
		if _shy_until.get(unit, -1) < sim_tick:
			_shy_until[unit] = sim_tick + SHY_TICKS
			_assigned.erase(unit)
			port.push(
				MoveCommand.new(
					MoveCommand.KIND_MOVE, faction_of_port(), [unit] as Array[Node3D], home
				)
			)
		return
	if _shy_until.get(unit, -1) >= sim_tick:
		return
	var current: Node3D = _assigned.get(unit, null)
	if current != null and sites.has(current) and unit.scanner != null:
		if unit.scanner.site == current:
			return
	var site: Node3D = _pick(unit, at, sites)
	if site == null:
		_assigned.erase(unit)
		return
	_assigned[unit] = site
	scans_started += 1
	port.push(ScanCommand.new(faction_of_port(), [unit] as Array[Node3D], site))


## The nearest open site no other member is on.
func _pick(unit: Unit, at: Vector3, sites: Array[Node3D]) -> Node3D:
	var taken: Array[Node3D] = []
	for other: Variant in _assigned.keys():
		if other != unit:
			var site: Node3D = _assigned[other]
			taken.append(site)
	var best: Node3D = null
	var best_distance: float = INF
	for site: Node3D in sites:
		if taken.has(site):
			continue
		var distance: float = AiGroup.flat_distance(site.position, at)
		if distance < best_distance:
			best = site
			best_distance = distance
	return best


func faction_of_port() -> int:
	return port.faction
