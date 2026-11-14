class_name ExtractionVfx
extends Node3D
## The extraction ship of a Holdout mission (ADR 0015). When the Advisor announces it
## inbound, a dropship flies in over the map and holds above the player's Lander; when
## it arrives (the mission is won) it sets down beside it. Presentation only: it
## follows `Events.advisor_alert` and never touches the simulation.

const SHIP: PackedScene = preload("res://assets/models/concord/concord_ship_dropship.glb")
const INBOUND: StringName = &"extraction_inbound"
const ARRIVED: StringName = &"extraction_arrived"
## Seconds the approach takes (the Advisor calls it about a minute out).
const APPROACH_SECONDS: float = 45.0
const LANDING_SECONDS: float = 3.0
## Where it comes from, relative to the landing spot.
const APPROACH_FROM := Vector3(-150.0, 55.0, -70.0)
const HOVER_HEIGHT: float = 16.0
## The landing spot, relative to the Lander.
const BESIDE := Vector3(14.0, 0.0, 4.0)
const FAN_SPEED: float = 26.0

var _ship: Node3D = null
var _fans: Array[Node3D] = []
var _flight: Tween = null


func _ready() -> void:
	Events.advisor_alert.connect(_on_alert)


func _process(delta: float) -> void:
	for fan: Node3D in _fans:
		fan.rotate_y(FAN_SPEED * delta)


## The ship, once it has been called in (null before), for tests.
func ship() -> Node3D:
	return _ship


func _on_alert(kind: StringName) -> void:
	if kind == INBOUND:
		_approach()
	elif kind == ARRIVED:
		_land()


func _approach() -> void:
	var spot: Vector3 = _landing_spot()
	_make_ship(spot + APPROACH_FROM)
	_ship.look_at(spot + Vector3.UP * APPROACH_FROM.y, Vector3.UP, true)
	_fly_to(spot + Vector3.UP * HOVER_HEIGHT, APPROACH_SECONDS, Tween.EASE_OUT)


func _land() -> void:
	var spot: Vector3 = _landing_spot()
	if _ship == null:
		# No approach was seen (a restored mission): it is already overhead.
		_make_ship(spot + Vector3.UP * HOVER_HEIGHT)
	_fly_to(spot, LANDING_SECONDS, Tween.EASE_IN_OUT)


func _make_ship(at: Vector3) -> void:
	if _ship != null:
		return
	_ship = SHIP.instantiate() as Node3D
	_ship.name = &"Dropship"
	add_child(_ship)
	_ship.global_position = at
	_fans.clear()
	for part: Node in _ship.find_children("fan_*", "Node3D", true, false):
		_fans.append(part as Node3D)


func _fly_to(to: Vector3, seconds: float, ease_type: Tween.EaseType) -> void:
	if _flight != null:
		_flight.kill()
	_flight = create_tween()
	_flight.set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	_flight.tween_property(_ship, ^"global_position", to, seconds)


## Beside the player's Lander, or the map's centre without one.
func _landing_spot() -> Vector3:
	for node: Node in get_tree().get_nodes_in_group(Building.GROUP):
		var building: Building = node as Building
		if building == null or building.is_dead or building.def == null:
			continue
		if building.def.id == &"concord_lander":
			return building.global_position + BESIDE
	return Vector3.ZERO
