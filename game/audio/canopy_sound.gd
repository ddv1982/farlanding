class_name CanopySound
extends Node
## Verdance's canopy (Phase 8c, the planet rule) -> sound. Listens to
## `Events.canopy_cover_changed` and `mission_started`; the rules live in
## CanopyCues. It depends on nothing of gameplay but that signal, node
## positions and two duck-typed reads:
##
## - The player's own units (faction `player_faction`, read like every router
##   does with AudioEventRouter.faction_of) going under a crown or out, within
##   CanopyCues.VIEW_RADIUS of the camera's focus, play a rustle at the unit
##   (`play_at`), one per gesture however many units move together. Other
##   factions' units are never heard here: a rustle must not give away an
##   ambush the player cannot see.
## - Shade: while the camera's focus is under a crown, `set_shade` is given
##   0..1 (gliding), and the AudioService closes the Ambience bus's high band
##   a little. Under a crown is asked of the first node in group CANOPY_GROUP
##   with `is_under_canopy(point: Vector3) -> bool` (the sim's CanopySystem);
##   without one, the focus counts as shaded when a covered unit the player can
##   know about (its own, or one whose `is_visible_to_player` is not false) is
##   within CanopyCues.SHADE_RADIUS of it.
## - mission_started (and going aboard the ship): everything resets.

const CANOPY_GROUP: StringName = &"canopy"
const PROBE_METHOD: StringName = &"is_under_canopy"

## Plays a positional event: `func(id: StringName, at: Vector3) -> bool`.
var play_at: Callable = func(_id: StringName, _at: Vector3) -> bool: return false
## Shade for the ambience: `func(amount: float) -> void` (0 open .. 1 under a crown).
var set_shade: Callable = func(_amount: float) -> void: pass
## Listener focus on the ground; set by the AudioService.
var focus: Vector3 = Vector3.ZERO
## Whose units rustle.
var player_faction: int = 0
## Rustles started so far (tests count them).
var rustles: int = 0

var cues: CanopyCues = CanopyCues.new()
## Instance id -> (a weak reference to) every unit reported under a crown now.
var _covered: Dictionary[int, WeakRef] = {}
var _shade: float = 0.0
var _applied_shade: float = -1.0
var _clock: float = 0.0


func _ready() -> void:
	Events.canopy_cover_changed.connect(handle_cover_changed)
	Events.mission_started.connect(handle_mission_started)
	_apply_shade()


func _process(delta: float) -> void:
	advance(delta)


## Advances by `delta` seconds (tests call this directly): the shade glides
## toward whether the focus is under a crown now.
func advance(delta: float) -> void:
	_clock += maxf(delta, 0.0)
	var target: float = 1.0 if is_focus_shaded() else 0.0
	_shade = move_toward(_shade, target, maxf(delta, 0.0) * CanopyCues.SHADE_RATE)
	_apply_shade()


## `unit` went under a crown (`covered`) or came out. Returns true if a rustle
## started.
func handle_cover_changed(unit: Node3D, covered: bool) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	var id: int = unit.get_instance_id()
	if covered:
		_covered[id] = weakref(unit)
	else:
		_covered.erase(id)
	if AudioEventRouter.faction_of(unit) != player_faction:
		return false
	var at: Vector3 = _position_of(unit)
	if not CanopyCues.in_view(at, focus):
		return false
	if not cues.offer(covered, _clock):
		return false
	if play_at.call(CanopyCues.event_for(covered), at):
		rustles += 1
		return true
	return false


func handle_mission_started() -> void:
	_covered.clear()
	cues.reset()
	_shade = 0.0
	_apply_shade()


## True if the focus is under a crown (see the class notes).
func is_focus_shaded() -> bool:
	if is_inside_tree():
		var map: Node = get_tree().get_first_node_in_group(CANOPY_GROUP)
		if map != null and map.has_method(PROBE_METHOD):
			var under: Variant = map.call(PROBE_METHOD, focus)
			if under is bool:
				var shaded: bool = under
				return shaded
	for id: int in _covered.keys():
		var ref: Object = _covered[id].get_ref()
		var unit: Node3D = ref as Node3D
		if unit == null or not is_instance_valid(unit):
			_covered.erase(id)
			continue
		var own: bool = AudioEventRouter.faction_of(unit) == player_faction
		if not own and CombatCues.is_hidden(unit):
			continue
		var at: Vector3 = _position_of(unit)
		if Vector2(at.x - focus.x, at.z - focus.z).length() <= CanopyCues.SHADE_RADIUS:
			return true
	return false


## 0 open .. 1 under a crown, as heard now.
func shade() -> float:
	return _shade


func covered_count() -> int:
	return _covered.size()


func _apply_shade() -> void:
	if is_equal_approx(_shade, _applied_shade):
		return
	_applied_shade = _shade
	set_shade.call(_shade)


static func _position_of(unit: Node3D) -> Vector3:
	return unit.global_position if unit.is_inside_tree() else unit.position
