class_name RtsCamera
extends Node3D
## RTS camera rig. The rig sits on the ground at the focus point; its Camera3D orbits
## it at a distance and pitch set by a smoothed zoom (0 = closest, 1 = furthest).
##
## Pan: arrows (always), WASD (only while `wasd_enabled`), screen edges, middle-mouse
## drag. Zoom: mouse wheel. Rotate: Q/E. The focus is clamped to `bounds`. Every frame
## it reports the focus and zoom to the Audio listener.

## Map area (world X/Z) the focus may move within.
@export var bounds: Rect2 = Rect2(-105.0, -105.0, 210.0, 210.0)
@export_range(4.0, 100.0, 0.5, "suffix:m") var min_distance: float = 16.0
@export_range(20.0, 300.0, 0.5, "suffix:m") var max_distance: float = 110.0
## Pitch below the horizon when fully zoomed in / out.
@export_range(10.0, 89.0, 0.5, "suffix:°") var close_pitch: float = 40.0
@export_range(10.0, 89.0, 0.5, "suffix:°") var far_pitch: float = 64.0
## Pan speed in screen heights per second, so it feels the same at every zoom.
@export var pan_speed: float = 1.1
@export_range(10.0, 360.0, 1.0, "suffix:°/s") var rotate_speed: float = 100.0
## Zoom change per wheel notch, in zoom units.
@export var zoom_step: float = 0.07
## How quickly zoom and focus height chase their targets (per second).
@export var smoothing: float = 10.0
@export var edge_scroll_enabled: bool = true
@export var edge_margin_px: float = 10.0
## Start zoom in [0, 1].
@export_range(0.0, 1.0, 0.01) var start_zoom: float = 0.45

## WASD pans only while true; the selection controller turns it off while units are
## selected so A and S can be order hotkeys.
var wasd_enabled: bool = true
## Ground heights for the focus point; flat at y = 0 when null.
var heights: HeightField = null

var camera: Camera3D
var _yaw: float = 0.0
var _zoom: float = 0.45
var _zoom_target: float = 0.45
var _focus: Vector3 = Vector3.ZERO
var _dragging: bool = false
var _mouse_inside: bool = false


func _ready() -> void:
	for child: Node in get_children():
		if child is Camera3D:
			camera = child
	if camera == null:
		camera = Camera3D.new()
		camera.name = &"Camera3D"
		camera.fov = 45.0
		add_child(camera)
	camera.current = true
	camera.far = 600.0
	_focus = global_position
	_yaw = rotation.y
	_zoom = start_zoom
	_zoom_target = start_zoom
	# Headless runs have no real mouse; never edge-scroll there.
	if DisplayServer.get_name() == "headless":
		edge_scroll_enabled = false
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_zoom_target = clampf(_zoom_target - zoom_step * button.factor, 0.0, 1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_zoom_target = clampf(_zoom_target + zoom_step * button.factor, 0.0, 1.0)
			MOUSE_BUTTON_MIDDLE:
				_dragging = button.pressed
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		# Grab the ground: the point under the cursor follows the cursor.
		var per_pixel: float = _metres_per_pixel()
		_focus -= (_right() * motion.relative.x + _forward() * -motion.relative.y) * per_pixel
		_clamp_focus()


func _process(delta: float) -> void:
	var pan: Vector2 = Input.get_vector(
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_back", &"camera_pan_forward"
	)
	if wasd_enabled:
		pan += (
			Input
			. get_vector(
				&"camera_pan_left_alt",
				&"camera_pan_right_alt",
				&"camera_pan_back_alt",
				&"camera_pan_forward_alt",
			)
		)
	pan += _edge_pan()
	pan = pan.limit_length(1.0)
	if pan != Vector2.ZERO:
		var screen_height_m: float = _metres_per_pixel() * get_viewport().get_visible_rect().size.y
		var step: float = pan_speed * screen_height_m * delta
		_focus += (_right() * pan.x + _forward() * pan.y) * step
		_clamp_focus()
	var turn: float = Input.get_axis(&"camera_rotate_right", &"camera_rotate_left")
	_yaw = wrapf(_yaw + deg_to_rad(rotate_speed) * turn * delta, -PI, PI)
	var blend: float = 1.0 - exp(-smoothing * delta)
	_zoom = lerpf(_zoom, _zoom_target, blend)
	if heights != null:
		_focus.y = lerpf(_focus.y, heights.sample(_focus.x, _focus.z), blend)
	_apply()
	Audio.set_listener_focus(_focus, _zoom)


## Moves the focus to `point` (instantly).
func center_on(point: Vector3) -> void:
	_focus = Vector3(point.x, point.y, point.z)
	if heights != null:
		_focus.y = heights.sample(point.x, point.z)
	_clamp_focus()
	_apply()


func get_focus() -> Vector3:
	return _focus


## Current smoothed zoom in [0, 1].
func get_zoom() -> float:
	return _zoom


## Point on the colliders under a screen position, or Vector3.INF if none.
func ground_point(screen_position: Vector2) -> Vector3:
	var from: Vector3 = camera.project_ray_origin(screen_position)
	var to: Vector3 = from + camera.project_ray_normal(screen_position) * 2000.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	var point: Vector3 = hit["position"]
	return point


func _apply() -> void:
	global_position = _focus
	rotation = Vector3(0.0, _yaw, 0.0)
	var distance: float = lerpf(min_distance, max_distance, _zoom)
	# Ease pitch so the view tilts up quickly near the ground and settles when far.
	var pitch: float = deg_to_rad(lerpf(close_pitch, far_pitch, ease(_zoom, 0.6)))
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _edge_pan() -> Vector2:
	if not edge_scroll_enabled or not _mouse_inside or _dragging:
		return Vector2.ZERO
	# An unfocused window (e.g. the game embedded in the editor while you work
	# elsewhere) must not scroll just because the cursor rests near its edge.
	if not get_window().has_focus():
		return Vector2.ZERO
	var rect: Rect2 = get_viewport().get_visible_rect()
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if not rect.has_point(mouse):
		return Vector2.ZERO
	var pan: Vector2 = Vector2.ZERO
	if mouse.x <= rect.position.x + edge_margin_px:
		pan.x -= 1.0
	elif mouse.x >= rect.end.x - edge_margin_px:
		pan.x += 1.0
	if mouse.y <= rect.position.y + edge_margin_px:
		pan.y += 1.0
	elif mouse.y >= rect.end.y - edge_margin_px:
		pan.y -= 1.0
	return pan


func _metres_per_pixel() -> float:
	var distance: float = lerpf(min_distance, max_distance, _zoom)
	var height_px: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	return 2.0 * distance * tan(deg_to_rad(camera.fov * 0.5)) / height_px


func _forward() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))


func _right() -> Vector3:
	return Vector3(cos(_yaw), 0.0, -sin(_yaw))


func _clamp_focus() -> void:
	_focus.x = clampf(_focus.x, bounds.position.x, bounds.end.x)
	_focus.z = clampf(_focus.z, bounds.position.y, bounds.end.y)
