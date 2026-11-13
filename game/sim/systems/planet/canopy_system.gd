class_name CanopySystem
extends PlanetRuleSystem
## Plays Verdance's CanopyRule (ADR 0016): canopy hides ground units from the air and
## from long-range sight. The crowns are the world's `canopy_zones` (from the MapDef),
## stamped once into a 1 m cover map. Every sim tick it notes which ground units (and
## buildings, when the rule says so) stand under a crown, emits
## `Events.canopy_cover_changed` when a unit goes under or comes out, and works out per
## covered entity which factions have a ground observer (unit or building) within
## close sight of it.
##
## It is the world's sight cover (`VisionSystem.cover`, `StealthSystem.cover`): a
## covered entity is hidden from a faction (`hides()`) unless one of that faction's
## ground observers is close, or it fired in the last `fire_reveal_seconds`. Flying
## units never see under a crown (`hides_from_air()`): they cannot target what stands
## there unless it gave itself away by firing. Because fog of war, targeting, the AI's
## perception, stealth watchers and the minimap all ask VisionSystem, hidden means the
## same everywhere. A covered unit itself sees out as usual.

const SAVE_VERSION: int = 1
## Cell of the cover map, in metres.
const CELL: float = 1.0

var _canopy: CanopyRule = null
var _bounds: Rect2 = Rect2()
var _columns: int = 0
var _rows: int = 0
## 1 where the ground is under a crown, one byte per cell.
var _cells: PackedByteArray = PackedByteArray()
var _now: int = 0
var _reveal_ticks: int = 0
## Entities under a crown now: ground units, and buildings when the rule hides them.
## (Untyped keys: a unit freed between two ticks may still be listed.)
var _covered: Dictionary = {}
## Covered entity -> factions (int -> true) with a ground observer close enough.
var _seen_by: Dictionary[Node3D, Dictionary] = {}
## Entity -> last sim tick it is seen by everyone because it fired.
var _revealed: Dictionary = {}
## The widest close sight of any observer (perks can widen it), for the grid query.
var _reach: float = 0.0


## True if the ground at `point` lies under a crown.
func is_under_canopy(point: Vector3) -> bool:
	if _columns == 0 or not _bounds.has_point(Vector2(point.x, point.z)):
		return false
	var column: int = clampi(floori((point.x - _bounds.position.x) / CELL), 0, _columns - 1)
	var row: int = clampi(floori((point.z - _bounds.position.y) / CELL), 0, _rows - 1)
	return _cells[row * _columns + column] != 0


## True if `entity` (a ground unit, or a building when the rule hides buildings) stands
## under a crown now.
func is_covered(entity: Node3D) -> bool:
	return _covered.has(entity)


## True while `entity` is seen by everyone because it fired from under a crown.
func is_revealed(entity: Node3D) -> bool:
	var until: int = _revealed.get(entity, -1)
	return until >= _now


## Living units of `faction` under a crown now.
func covered_units(faction: int) -> Array[Unit]:
	var found: Array[Unit] = []
	for key: Variant in _covered:
		if not is_instance_valid(key) or not key is Unit:
			continue
		var unit: Unit = key
		if unit.faction == faction:
			found.append(unit)
	return found


func hides(faction: int, entity: Node3D) -> bool:
	if not _covered.has(entity) or faction < 0:
		return false
	if Combat.faction_of(entity) == faction or is_revealed(entity):
		return false
	var seen: Dictionary = _seen_by.get(entity, {})
	return not seen.has(faction)


func hides_from_air(entity: Node3D) -> bool:
	return _covered.has(entity) and not is_revealed(entity)


func indicator_title() -> String:
	return "CANOPY"


func indicator_text(_tick_number: int) -> String:
	var count: int = covered_units(world.player_faction).size()
	if count == 0:
		return "IN THE OPEN"
	return "%d UNDER COVER" % count


func indicator_level() -> float:
	var own: int = 0
	for unit: Unit in world.units_of(world.player_faction):
		if not unit.is_dead and not unit.flies:
			own += 1
	return float(covered_units(world.player_faction).size()) / own if own > 0 else 0.0


func to_dict() -> Dictionary:
	var revealed: Dictionary = {}
	for key: Variant in _revealed:
		if not is_instance_valid(key):
			continue
		var entity: Node3D = key
		var id: int = Order.entity_id_of(entity)
		var until: int = _revealed[entity]
		if id >= 0 and until >= _now:
			revealed[str(id)] = until - _now
	var covered: Array[int] = []
	for key: Variant in _covered:
		if not is_instance_valid(key):
			continue
		var entity: Node3D = key
		var id: int = Order.entity_id_of(entity)
		if id >= 0:
			covered.append(id)
	return {"version": SAVE_VERSION, "tick": _now, "revealed": revealed, "covered": covered}


## Restores the fire reveals and who is under a crown (quietly: no cover events for
## units that were already there). Call after the entities exist.
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported CanopySystem save version")
	_now = data.get("tick", _now)
	_revealed.clear()
	var revealed: Dictionary = data.get("revealed", {})
	for key: Variant in revealed:
		var entity: Node3D = world.entity(int(str(key)))
		var left: int = revealed[key]
		if entity != null:
			_revealed[entity] = _now + left
	_covered.clear()
	var covered: Array = data.get("covered", [])
	for entry: Variant in covered:
		var id: int = entry
		var entity: Node3D = world.entity(id)
		if entity != null:
			_covered[entity] = true


func _setup() -> void:
	_canopy = rule as CanopyRule
	if _canopy == null:
		_canopy = CanopyRule.new()
	_reveal_ticks = ceili(_canopy.fire_reveal_seconds * SimClock.TICK_RATE)
	_stamp(world.canopy_zones)
	if world.vision != null:
		world.vision.cover = self
	if world.stealth != null:
		world.stealth.cover = self
	Events.weapon_fired.connect(_on_weapon_fired)


func _tick(tick_number: int, _dt: float) -> void:
	_now = tick_number
	_reach = _widest_sight()
	_update_cover()
	_update_observers()
	if tick_number % 50 == 0:
		_forget_reveals()


## Fills the cover map from the crowns (x, z, radius x, radius z).
func _stamp(zones: PackedVector4Array) -> void:
	if zones.is_empty():
		return
	var bounds: Rect2 = Rect2()
	for k: int in zones.size():
		var zone: Vector4 = zones[k]
		var rect: Rect2 = Rect2(zone.x - zone.z, zone.y - zone.w, zone.z * 2.0, zone.w * 2.0)
		bounds = rect if k == 0 else bounds.merge(rect)
	_bounds = bounds
	_columns = maxi(ceili(bounds.size.x / CELL), 1)
	_rows = maxi(ceili(bounds.size.y / CELL), 1)
	_cells.resize(_columns * _rows)
	_cells.fill(0)
	for zone: Vector4 in zones:
		if zone.z <= 0.0 or zone.w <= 0.0:
			continue
		var first: int = clampi(floori((zone.x - zone.z - bounds.position.x) / CELL), 0, _columns)
		var last: int = clampi(ceili((zone.x + zone.z - bounds.position.x) / CELL), 0, _columns)
		var top: int = clampi(floori((zone.y - zone.w - bounds.position.y) / CELL), 0, _rows)
		var bottom: int = clampi(ceili((zone.y + zone.w - bounds.position.y) / CELL), 0, _rows)
		for row: int in range(top, bottom):
			var z: float = bounds.position.y + (row + 0.5) * CELL
			var dz: float = (z - zone.y) / zone.w
			for column: int in range(first, last):
				var x: float = bounds.position.x + (column + 0.5) * CELL
				var dx: float = (x - zone.x) / zone.z
				if dx * dx + dz * dz <= 1.0:
					_cells[row * _columns + column] = 1


## Who stands under a crown now; announces units that went under or came out.
func _update_cover() -> void:
	var now: Dictionary = {}
	for unit: Unit in world.units:
		if not unit.is_dead and not unit.flies and is_under_canopy(unit.sim_position()):
			now[unit] = true
	if _canopy.hides_buildings:
		for building: Building in world.buildings:
			if not building.is_dead and is_under_canopy(building.position):
				now[building] = true
	for key: Variant in now:
		if not _covered.has(key) and key is Unit:
			var unit: Unit = key
			Events.canopy_cover_changed.emit(unit, true)
	for key: Variant in _covered:
		if not is_instance_valid(key) or not key is Unit or now.has(key):
			continue
		var unit: Unit = key
		if not unit.is_dead and unit.is_inside_tree():
			Events.canopy_cover_changed.emit(unit, false)
	_covered = now


## For every covered entity: the factions with a ground observer within close sight.
func _update_observers() -> void:
	var before: Dictionary[Node3D, Dictionary] = _seen_by
	_seen_by = {}
	if world.combat == null:
		return
	for key: Variant in _covered:
		var entity: Node3D = key
		var at: Vector3 = AttackCommand.position_of(entity)
		var body: float = AttackCommand.body_radius(entity)
		var own: int = Combat.faction_of(entity)
		var seen: Dictionary = {}
		for observer: Node3D in world.combat.entities_near(at, _reach + body):
			var faction: int = Combat.faction_of(observer)
			if faction < 0 or faction == own or seen.has(faction) or not _observes(observer):
				continue
			var from: Vector3 = AttackCommand.position_of(observer)
			var distance: float = Vector2(from.x - at.x, from.z - at.z).length()
			distance -= body + AttackCommand.body_radius(observer)
			if distance <= _close_sight(observer):
				seen[faction] = true
		if not seen.is_empty():
			_seen_by[entity] = seen
			# The player hears it when one of their hidden units is found.
			if own == world.player_faction and not before.has(entity):
				Events.advisor_alert.emit(&"canopy_contact")


## True for a living ground unit or building that can look (flyers never see under a
## crown; dormant Custodians do not look).
static func _observes(observer: Node3D) -> bool:
	if not Combat.is_alive(observer) or Combat.is_dormant(observer):
		return false
	var unit: Unit = observer as Unit
	return unit == null or not unit.flies


## How close `observer` sees under a crown: the rule's close sight, widened by its
## faction's `canopy_sight` perk.
func _close_sight(observer: Node3D) -> float:
	var faction: int = Combat.faction_of(observer)
	var id: StringName = &""
	if observer is Unit and (observer as Unit).def != null:
		id = (observer as Unit).def.id
	elif observer is Building and (observer as Building).def != null:
		id = (observer as Building).def.id
	var perks: FactionPerks = FactionPerks.of(world.perks, faction)
	return perks.apply(id, FactionPerks.CANOPY_SIGHT, _canopy.close_sight)


## The rule's close sight times the largest `canopy_sight` scale any faction has.
func _widest_sight() -> float:
	var widest: float = 1.0
	for faction: int in world.perks:
		var perks: FactionPerks = world.perks[faction]
		var general: float = perks.scales.get(FactionPerks.CANOPY_SIGHT, 1.0)
		var best: float = general
		for key: StringName in perks.scales:
			if String(key).ends_with("/" + String(FactionPerks.CANOPY_SIGHT)):
				best = maxf(best, general * perks.scales[key])
		widest = maxf(widest, best)
	return _canopy.close_sight * widest


func _on_weapon_fired(shooter: Node3D, _weapon: WeaponDef, _muzzle: Vector3, _at: Vector3) -> void:
	if shooter == null or not is_instance_valid(shooter):
		return
	if _covered.has(shooter) or is_under_canopy(AttackCommand.position_of(shooter)):
		_revealed[shooter] = _now + _reveal_ticks


func _forget_reveals() -> void:
	for key: Variant in _revealed.keys():
		if not is_instance_valid(key):
			_revealed.erase(key)
			continue
		var until: int = _revealed[key]
		if until < _now:
			_revealed.erase(key)
