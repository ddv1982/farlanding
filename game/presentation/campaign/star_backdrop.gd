extends Node3D
## The view behind the campaign screens: the Meridian holding orbit over a planet,
## deep space behind. The ship drifts and its habitat ring turns; the camera
## breathes a little so the picture is never still. Holds no game state.
## `show_planet(id)` recolours the planet for the route node under the cursor.

## Surface (two bands) and atmosphere colour per planet id.
const PLANET_LOOKS: Dictionary[StringName, Array] = {
	&"kessel_reach":
	[Color(0.55, 0.30, 0.18), Color(0.86, 0.64, 0.42), Color(1.0, 0.62, 0.36), 5.0],
	&"thalassa_low": [Color(0.06, 0.26, 0.34), Color(0.48, 0.74, 0.70), Color(0.5, 0.9, 1.0), 2.5],
	&"emberfall": [Color(0.10, 0.06, 0.06), Color(0.85, 0.28, 0.08), Color(1.0, 0.4, 0.2), 7.0],
	&"verdance": [Color(0.07, 0.24, 0.12), Color(0.50, 0.66, 0.30), Color(0.7, 1.0, 0.7), 3.5],
	&"hollow_meridian":
	[Color(0.14, 0.15, 0.20), Color(0.62, 0.60, 0.52), Color(0.8, 0.85, 1.0), 9.0],
}
const DEFAULT_PLANET: StringName = &"kessel_reach"
## Seconds for the habitat ring to turn once.
const RING_SECONDS: float = 36.0
const FADE_SECONDS: float = 0.8

@export var ship: Node3D
@export var planet: MeshInstance3D
@export var camera: Camera3D

var _time: float = 0.0
var _shown: StringName = &""
var _ring: Node3D
var _dish: Node3D
var _ship_home: Vector3
var _camera_home: Vector3
var _fade: Tween


func _ready() -> void:
	if ship != null:
		_ship_home = ship.position
		_ring = ship.find_child("ring", true, false) as Node3D
		_dish = ship.find_child("dish", true, false) as Node3D
	if camera != null:
		_camera_home = camera.position
	show_planet(DEFAULT_PLANET, true)


func _process(delta: float) -> void:
	_time += delta
	if _ring != null:
		_ring.rotate_object_local(Vector3.FORWARD, delta * TAU / RING_SECONDS)
	if _dish != null:
		_dish.rotation.y = sin(_time * 0.11) * 0.6
	if ship != null:
		ship.position = _ship_home + Vector3(0.0, sin(_time * 0.21) * 0.5, 0.0)
		ship.rotation.z = sin(_time * 0.13) * 0.015
	if camera != null:
		var sway := Vector3(sin(_time * 0.07) * 1.6, sin(_time * 0.05 + 1.0) * 0.8, 0.0)
		camera.position = _camera_home + sway


## Shows the planet `id` below the ship (unknown ids keep the current one).
func show_planet(id: StringName, at_once: bool = false) -> void:
	if planet == null or id == _shown or not PLANET_LOOKS.has(id):
		return
	_shown = id
	var look: Array = PLANET_LOOKS[id]
	var material: ShaderMaterial = planet.material_override as ShaderMaterial
	if material == null:
		return
	if _fade != null:
		_fade.kill()
	if at_once:
		material.set_shader_parameter(&"surface_a", look[0])
		material.set_shader_parameter(&"surface_b", look[1])
		material.set_shader_parameter(&"atmosphere", look[2])
		material.set_shader_parameter(&"bands", look[3])
		return
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(material, ^"shader_parameter/surface_a", look[0], FADE_SECONDS)
	_fade.tween_property(material, ^"shader_parameter/surface_b", look[1], FADE_SECONDS)
	_fade.tween_property(material, ^"shader_parameter/atmosphere", look[2], FADE_SECONDS)
	_fade.tween_property(material, ^"shader_parameter/bands", look[3], FADE_SECONDS)
