class_name FlightSystem
extends RefCounted
## Keeps flying units apart (ADR 0016). Flying units have no navmesh and no RVO agent
## (they never block ground units, and ground units never block them), so after the
## units moved each sim tick, two flyers closer than their bodies plus GAP are pushed
## apart, each by half the overlap times PUSH. Costs nothing without flyers.

## Air between two flying bodies, in metres.
const GAP: float = 1.5
## Share of the overlap removed per tick (a soft push, so formations settle).
const PUSH: float = 0.5
## Most a flyer is pushed in one tick, in metres.
const MAX_STEP: float = 0.8

## Enemy flyers the player has already been told about, by entity id.
var _sighted: Dictionary[int, bool] = {}
## The player's flyers alive at the last report, by entity id.
var _own: Dictionary[int, bool] = {}


## One sim tick over `units` (the world's list).
func tick(units: Array[Unit], _dt: float) -> void:
	var flyers: Array[Unit] = []
	for unit: Unit in units:
		if unit.flies and unit.locomotion != null and not unit.is_dead:
			flyers.append(unit)
	if flyers.size() < 2:
		return
	var pushes: Array[Vector3] = []
	pushes.resize(flyers.size())
	pushes.fill(Vector3.ZERO)
	for i: int in flyers.size():
		var a: Vector3 = flyers[i].locomotion.mover.position
		var a_radius: float = flyers[i].def.radius
		for j: int in range(i + 1, flyers.size()):
			var b: Vector3 = flyers[j].locomotion.mover.position
			var wanted: float = a_radius + flyers[j].def.radius + GAP
			var offset: Vector2 = Vector2(b.x - a.x, b.z - a.z)
			var distance: float = offset.length()
			if distance >= wanted:
				continue
			var away: Vector2 = (
				offset / distance if distance > 0.001 else _tie_break(flyers[i], flyers[j])
			)
			var step: float = minf((wanted - distance) * 0.5 * PUSH, MAX_STEP)
			pushes[i] -= Vector3(away.x, 0.0, away.y) * step
			pushes[j] += Vector3(away.x, 0.0, away.y) * step
	for i: int in flyers.size():
		if pushes[i] != Vector3.ZERO:
			var mover: Mover = flyers[i].locomotion.mover
			mover.position += pushes[i].limit_length(MAX_STEP)


## Tells the player (Advisor) when an enemy flyer first comes into view and when one
## of their own is lost. `vision` may be null (no fog: nothing is reported as sighted).
func report(units: Array[Unit], vision: VisionSystem, player_faction: int) -> void:
	var alive: Dictionary[int, bool] = {}
	for unit: Unit in units:
		if not unit.flies or unit.is_dead:
			continue
		if unit.faction == player_faction:
			alive[unit.entity_id] = true
		elif vision != null and not _sighted.has(unit.entity_id):
			if vision.can_see(player_faction, unit):
				_sighted[unit.entity_id] = true
				Events.advisor_alert.emit(&"air_contact")
	for id: int in _own:
		if not alive.has(id):
			Events.advisor_alert.emit(&"air_lost")
			break
	_own = alive


## A fixed direction for two flyers on the same spot, from their ids (repeatable).
static func _tie_break(a: Unit, b: Unit) -> Vector2:
	var angle: float = float((a.entity_id * 7919 + b.entity_id * 104729) % 360)
	return Vector2.from_angle(deg_to_rad(angle))
