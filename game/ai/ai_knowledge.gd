class_name AiKnowledge
extends RefCounted
## What one AI faction knows about the map, built only from its own vision grid:
## enemy units and buildings it has seen (remembered for a while, buildings until
## their ground is seen empty) and, per scouting sector, when it last had eyes there.
## The commander feeds it with `observe()` (what its units and buildings see now) and
## `forget()` (drops what its grid now shows to be gone).

var faction: int = 1
## Seen enemy units are dropped this many ticks after they were last seen.
var memory_ticks: int = 400
## Instance id -> sighting.
var sightings: Dictionary[int, AiSighting] = {}
## Scouting sectors: centre points (walkable), the tick each was last visible (-1 =
## never), and until when a sector is skipped (a scout could not reach it).
var sector_points: PackedVector3Array = PackedVector3Array()
var sector_last_seen: PackedInt32Array = PackedInt32Array()
var sector_blocked_until: PackedInt32Array = PackedInt32Array()


func _init(p_faction: int = 1, p_memory_ticks: int = 400) -> void:
	faction = p_faction
	memory_ticks = p_memory_ticks


## Fighting value of an entity, in Alloy-equivalent: armed units by their cost
## (Flux counts double) scaled by health left, armed buildings at twice that (they
## hold ground cheaply), everything unarmed 0.
static func strength_of(entity: Node3D) -> float:
	if not Combat.is_armed(entity):
		return 0.0
	var health: Health = Combat.health_of(entity)
	var share: float = health.fraction() if health != null else 1.0
	var unit: Unit = entity as Unit
	if unit != null and unit.def != null:
		return (unit.def.cost_alloy + unit.def.cost_flux * 2.0) * share
	var building: Building = entity as Building
	if building != null and building.def != null:
		return (building.def.cost_alloy + building.def.cost_flux * 2.0) * 2.0 * share
	return 0.0


## Splits `area` into square sectors of `size` metres; `walkable` is
## `func(point: Vector3) -> bool`. Sectors with no walkable sample are left out.
func setup_sectors(area: Rect2, size: float, walkable: Callable) -> void:
	sector_points = PackedVector3Array()
	var columns: int = maxi(floori(area.size.x / size), 1)
	var rows: int = maxi(floori(area.size.y / size), 1)
	for row: int in rows:
		for column: int in columns:
			var centre: Vector3 = Vector3(
				area.position.x + (column + 0.5) * size, 0.0, area.position.y + (row + 0.5) * size
			)
			var point: Vector3 = _walkable_near(centre, size * 0.4, walkable)
			if point != Vector3.INF:
				sector_points.append(point)
	sector_last_seen = PackedInt32Array()
	sector_last_seen.resize(sector_points.size())
	sector_last_seen.fill(-1)
	sector_blocked_until = PackedInt32Array()
	sector_blocked_until.resize(sector_points.size())
	sector_blocked_until.fill(-1)


## Records what the faction sees now (`entities` from its own eyes) on tick `now`.
func observe(entities: Array[Node3D], now: int) -> void:
	for entity: Node3D in entities:
		var key: int = entity.get_instance_id()
		var sighting: AiSighting = sightings.get(key, null)
		if sighting == null:
			sighting = AiSighting.new()
			sightings[key] = sighting
		sighting.update(entity, now)


## Drops units not seen for `memory_ticks`, and buildings whose ground the faction
## sees now without seeing them (`area_visible` is `func(area: Rect2) -> bool`).
## Also stamps the sectors visible now (`point_visible` is `func(point) -> bool`).
func forget(now: int, area_visible: Callable, point_visible: Callable) -> void:
	for key: int in sightings.keys():
		var sighting: AiSighting = sightings[key]
		if sighting.last_seen_tick == now:
			continue
		if sighting.is_building:
			var gone: bool = area_visible.call(sighting.footprint)
			if gone:
				sightings.erase(key)
		elif sighting.age(now) > memory_ticks:
			sightings.erase(key)
	for i: int in sector_points.size():
		var seen: bool = point_visible.call(sector_points[i])
		if seen:
			sector_last_seen[i] = now


## Remembered enemy buildings.
func known_buildings() -> Array[AiSighting]:
	var result: Array[AiSighting] = []
	for sighting: AiSighting in sightings.values():
		if sighting.is_building:
			result.append(sighting)
	return result


## Enemy units seen within `within_ticks` of `now`.
func recent_units(now: int, within_ticks: int) -> Array[AiSighting]:
	var result: Array[AiSighting] = []
	for sighting: AiSighting in sightings.values():
		if not sighting.is_building and sighting.age(now) <= within_ticks:
			result.append(sighting)
	return result


## Total strength and strength-weighted centre of what was seen within `radius` of
## `center` in the last `within_ticks` (armed buildings count whenever remembered).
## Returns Vector4(x, y, z, strength); strength 0 means nothing.
func threat_near(center: Vector3, radius: float, now: int, within_ticks: int) -> Vector4:
	var total: float = 0.0
	var weighted: Vector3 = Vector3.ZERO
	for sighting: AiSighting in sightings.values():
		if sighting.strength <= 0.0:
			continue
		if not sighting.is_building and sighting.age(now) > within_ticks:
			continue
		if _flat_distance(sighting.position, center) > radius:
			continue
		total += sighting.strength
		weighted += sighting.position * sighting.strength
	if total <= 0.0:
		return Vector4.ZERO
	var at: Vector3 = weighted / total
	return Vector4(at.x, at.y, at.z, total)


## Share of heavy armour among enemy units remembered now, in [0, 1].
func heavy_share() -> float:
	var units: int = 0
	var heavy: int = 0
	for sighting: AiSighting in sightings.values():
		if sighting.is_building or not sighting.armed:
			continue
		units += 1
		if sighting.heavy:
			heavy += 1
	return float(heavy) / units if units > 0 else 0.0


## Where an attack from `home` should go: the remembered enemy building nearest home
## (the edge of their base), else the most recently seen armed enemy unit at least
## `min_unit_distance` from home (a scout passing by is no target). Only what was
## seen counts. Returns Vector3.INF when nothing is known.
func attack_target(home: Vector3, now: int, min_unit_distance: float = 0.0) -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_distance: float = INF
	for sighting: AiSighting in known_buildings():
		var distance: float = _flat_distance(sighting.position, home)
		if distance < best_distance:
			best = sighting.position
			best_distance = distance
	if best != Vector3.INF:
		return best
	var newest: int = -1
	for sighting: AiSighting in recent_units(now, memory_ticks):
		if _flat_distance(sighting.position, home) < min_unit_distance:
			continue
		if sighting.armed and sighting.last_seen_tick > newest:
			newest = sighting.last_seen_tick
			best = sighting.position
	return best


## The next place for a scout at `from` to look: the never-seen sector furthest from
## `home` (the enemy is likely there) and not too far from the scout, else the sector
## seen longest ago if older than `stale_ticks`. Vector3.INF if there is none.
func next_scout_point(from: Vector3, home: Vector3, now: int, stale_ticks: int) -> Vector3:
	var best: int = -1
	var best_score: float = -INF
	for i: int in sector_points.size():
		if sector_blocked_until[i] > now or sector_last_seen[i] >= 0:
			continue
		var point: Vector3 = sector_points[i]
		var score: float = _flat_distance(point, home) - 0.6 * _flat_distance(point, from)
		if score > best_score:
			best = i
			best_score = score
	if best < 0:
		var oldest: int = stale_ticks
		for i: int in sector_points.size():
			if sector_blocked_until[i] > now:
				continue
			var age: int = now - sector_last_seen[i]
			if age > oldest:
				oldest = age
				best = i
	return sector_points[best] if best >= 0 else Vector3.INF


## A scout could not get to `point`: skip its sector until `until_tick`.
func block_sector_at(point: Vector3, until_tick: int) -> void:
	var nearest: int = -1
	var nearest_distance: float = INF
	for i: int in sector_points.size():
		var distance: float = _flat_distance(sector_points[i], point)
		if distance < nearest_distance:
			nearest = i
			nearest_distance = distance
	if nearest >= 0:
		sector_blocked_until[nearest] = until_tick


## Share of sectors seen at least once, in [0, 1].
func explored_share() -> float:
	if sector_points.is_empty():
		return 1.0
	var seen: int = 0
	for tick: int in sector_last_seen:
		if tick >= 0:
			seen += 1
	return float(seen) / sector_points.size()


static func _walkable_near(centre: Vector3, reach: float, walkable: Callable) -> Vector3:
	if not walkable.is_valid():
		return centre
	var offsets: Array[Vector2] = [Vector2.ZERO]
	for ring: float in [0.5, 1.0]:
		for k: int in 8:
			offsets.append(Vector2.from_angle(TAU * k / 8.0) * reach * ring)
	for offset: Vector2 in offsets:
		var point: Vector3 = centre + Vector3(offset.x, 0.0, offset.y)
		var ok: bool = walkable.call(point)
		if ok:
			return point
	return Vector3.INF


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
