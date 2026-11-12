class_name CombatMixer
extends RefCounted
## Mass-combat discipline (PLAN §5.3: forty units firing must not be forty
## times louder). Pure logic; playback goes through a callable.
##
## Combat sounds are not played the moment they are raised. They are offered
## during a frame and arbitrated once per frame in `flush()`:
##
## - Out of range (beyond the event's max distance from the listener focus):
##   dropped before it can take a slot.
## - Ranked by `priority * PRIORITY_METRES - distance`: the event's priority
##   doubles as its weight, so a cannon 15 m away still beats a repeater at
##   your feet, and among equals the nearest wins.
## - Each category (fire, impact, blast) may start at most `LIMITS[category]`
##   sounds per rolling WINDOW; the rest of the frame's offers are dropped.
##   Per-event caps and cooldowns (in the SoundEvent) still apply on top, in
##   the AudioService's voice budget; a refused play does not use a slot.
## - Blasts (explosions, deaths) go first; while one has just started, light
##   weapon fire (priority below LIGHT_PRIORITY) plays DUCK_DB quieter.

const WINDOW: float = 0.5
const LIMITS: Dictionary[StringName, int] = {
	&"fire": 8,
	&"impact": 5,
	&"blast": 4,
}
const PRIORITY_METRES: float = 1.0
const LIGHT_PRIORITY: int = 50
const DUCK_SECONDS: float = 0.45
const DUCK_DB: float = -4.0
## Offers beyond this per frame are ignored (flush is called every frame).
const MAX_PENDING: int = 128
const CATEGORY_ORDER: Array[StringName] = [&"blast", &"fire", &"impact"]

var _pending: Array[Offer] = []
var _starts: Dictionary[StringName, PackedFloat64Array] = {}
var _duck_until: float = -INF


## Which budget an event belongs to, by its name.
static func category_of(event_id: StringName) -> StringName:
	var text: String = String(event_id)
	if text.begins_with("weapon_"):
		return &"fire"
	if text.begins_with("impact_"):
		return &"impact"
	return &"blast"


## Ranking score: heavier and nearer is higher.
static func score(priority: int, distance: float) -> float:
	return priority * PRIORITY_METRES - distance


## Offers a sound for this frame. `max_distance` <= 0 means unlimited.
func offer(event_id: StringName, position: Vector3, priority: int, max_distance: float) -> void:
	if event_id == &"" or not position.is_finite() or _pending.size() >= MAX_PENDING:
		return
	_pending.append(Offer.new(event_id, position, priority, max_distance))


func pending_count() -> int:
	return _pending.size()


## Decides what plays and plays it through
## `play(event_id: StringName, position: Vector3, volume_offset_db: float) -> bool`.
## Returns the ids started, in order.
func flush(now: float, focus: Vector3, play: Callable) -> Array[StringName]:
	var started: Array[StringName] = []
	if _pending.is_empty():
		return started
	var offers: Array[Offer] = _pending
	_pending = []
	for item: Offer in offers:
		item.distance = Vector2(item.at.x - focus.x, item.at.z - focus.z).length()
	for category: StringName in CATEGORY_ORDER:
		var ranked: Array[Offer] = []
		for item: Offer in offers:
			if item.category != category:
				continue
			if item.max_distance > 0.0 and item.distance > item.max_distance:
				continue
			ranked.append(item)
		ranked.sort_custom(func(a: Offer, b: Offer) -> bool: return a.score() > b.score())
		var limit: int = LIMITS.get(category, 4)
		for item: Offer in ranked:
			if recent_starts(category, now) >= limit:
				break
			var offset: float = 0.0
			if category == &"fire" and item.priority < LIGHT_PRIORITY and now < _duck_until:
				offset = DUCK_DB
			var played: bool = play.call(item.event_id, item.at, offset)
			if played:
				_record(category, now)
				started.append(item.event_id)
				if category == &"blast":
					_duck_until = now + DUCK_SECONDS
	return started


## Starts in `category` within the last WINDOW seconds.
func recent_starts(category: StringName, now: float) -> int:
	var times: PackedFloat64Array = _starts.get(category, PackedFloat64Array())
	var count: int = 0
	for t: float in times:
		if now - t < WINDOW:
			count += 1
	return count


func is_ducking(now: float) -> bool:
	return now < _duck_until


func _record(category: StringName, now: float) -> void:
	var times: PackedFloat64Array = _starts.get(category, PackedFloat64Array())
	var kept: PackedFloat64Array = []
	for t: float in times:
		if now - t < WINDOW:
			kept.append(t)
	kept.append(now)
	_starts[category] = kept


class Offer:
	extends RefCounted
	var event_id: StringName
	var category: StringName
	var at: Vector3
	var priority: int
	var max_distance: float
	var distance: float = 0.0

	func _init(id: StringName, position: Vector3, weight: int, max_range: float) -> void:
		event_id = id
		category = CombatMixer.category_of(id)
		at = position
		priority = weight
		max_distance = max_range

	func score() -> float:
		return CombatMixer.score(priority, distance)
