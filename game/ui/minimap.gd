class_name Minimap
extends PanelContainer
## Bottom-right map of the whole mission area: terrain (hill-shaded, impassable ground
## dark) under the fog of war, resource nodes the player has explored, the player's
## units and buildings in team colour, enemies the player sees in red (enemy buildings
## seen before but not in sight now stay, dimmed, where they were last seen),
## discovery signals the orbital scan charted (a "?" even under fog; a dot in the
## discovery's colour once resolved), and the camera's view. Left click or drag moves
## the camera there; right click orders the selected units to move there (Shift
## queues). Built from HudStyle.

const SIZE: float = 212.0
## Terrain image pixels per side.
const TERRAIN_PIXELS: int = 120
const ENEMY_COLOR: Color = Color(1.0, 0.25, 0.18)
## Enemy buildings remembered from an earlier sighting.
const REMEMBERED_COLOR: Color = Color(0.62, 0.22, 0.18, 0.75)
const NODE_COLOR: Color = Color(0.72, 0.84, 0.95)
const VENT_COLOR: Color = Color(0.45, 0.85, 1.0)
const VIEW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const SIGNAL_COLOR: Color = Color(0.35, 0.92, 1.0)

const FOG_SHADER: String = """
shader_type canvas_item;
#include "res://presentation/shaders/fog.gdshaderinc"

uniform vec4 area = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec4 ground = texture(TEXTURE, UV);
	vec3 world = vec3(area.x + UV.x * area.z, 0.0, area.y + UV.y * area.w);
	COLOR = vec4(fog_color(ground.rgb, fog_at(world)), 1.0);
}
"""

var world: SimWorld = null
var camera: RtsCamera = null
var controller: SelectionController = null
var faction: int = 0
## World X/Z area the map shows.
var area: Rect2 = Rect2(-120.0, -120.0, 240.0, 240.0)

## Known active objectives with an area, drawn as rings (from the objective events).
var _objectives: Array[Objective] = []
var _terrain: TextureRect = null
var _overlay: Control = null
var _dragging: bool = false


func setup(
	p_world: SimWorld,
	p_camera: RtsCamera,
	p_controller: SelectionController,
	p_faction: int,
	p_area: Rect2,
) -> void:
	world = p_world
	camera = p_camera
	controller = p_controller
	faction = p_faction
	area = p_area
	add_theme_stylebox_override(&"panel", _panel_style())
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_END
	_terrain = TextureRect.new()
	_terrain.custom_minimum_size = Vector2(SIZE, SIZE)
	_terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_terrain.stretch_mode = TextureRect.STRETCH_SCALE
	_terrain.texture = ImageTexture.create_from_image(_terrain_image())
	_terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = FOG_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(
		&"area", Vector4(area.position.x, area.position.y, area.size.x, area.size.y)
	)
	_terrain.material = material
	add_child(_terrain)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_terrain.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Events.objective_added.connect(track_objective)
	Events.objective_updated.connect(track_objective)
	Events.objective_completed.connect(track_objective)
	Events.objective_failed.connect(track_objective)


func _process(_delta: float) -> void:
	if _overlay != null:
		_overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			if button.pressed:
				_look_at(button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			if controller != null:
				controller.move_selection_to(to_world(button.position), button.shift_pressed)
			accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		_look_at(motion.position)
		accept_event()


## World point (on the ground) under a position in this control.
func to_world(local: Vector2) -> Vector3:
	var uv: Vector2 = ((local - _terrain.position) / _terrain.size).clamp(Vector2.ZERO, Vector2.ONE)
	var point: Vector3 = Vector3(
		area.position.x + uv.x * area.size.x, 0.0, area.position.y + uv.y * area.size.y
	)
	if world != null and world.heights != null:
		point.y = world.heights.sample(point.x, point.z)
	return point


## Map position (in the terrain picture) of a world point.
func to_map(point: Vector3) -> Vector2:
	var size: Vector2 = _terrain.size
	return Vector2(
		(point.x - area.position.x) / area.size.x * size.x,
		(point.z - area.position.y) / area.size.y * size.y
	)


func _look_at(local: Vector2) -> void:
	if camera != null:
		camera.center_on(to_world(local))


func _draw_overlay() -> void:
	if world == null:
		return
	var scale: float = _terrain.size.x / area.size.x
	for node: ResourceNode in world.resource_nodes:
		if node.visible and node.def != null:
			var color: Color = VENT_COLOR if node.resource() == &"flux" else NODE_COLOR
			_overlay.draw_circle(to_map(node.position), maxf(node.def.radius * scale, 1.5), color)
	_draw_sites(scale)
	for building: Building in world.buildings:
		if not building.visible or building.is_dead:
			continue
		var rect: Rect2 = building.footprint()
		var corner: Vector2 = to_map(Vector3(rect.position.x, 0.0, rect.position.y))
		var box: Rect2 = Rect2(corner, (rect.size * scale).max(Vector2(3.0, 3.0)))
		var color: Color = _color_for(building.faction)
		if building.faction != faction and not building.is_visible_to_player:
			color = REMEMBERED_COLOR
		_overlay.draw_rect(box, color)
		_overlay.draw_rect(box, Color(0, 0, 0, 0.6), false, 1.0)
	for unit: Unit in world.units:
		if not unit.visible or unit.is_dead:
			continue
		var at: Vector2 = to_map(unit.global_position)
		var half: float = maxf(unit.def.radius * scale, 1.5) if unit.def != null else 1.5
		_overlay.draw_rect(
			Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), _color_for(unit.faction)
		)
	_draw_objectives(scale)
	_draw_view()


## Active objective areas: a pulsing ring in the objective's colour.
func _draw_objectives(scale: float) -> void:
	var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 250.0)
	for objective: Objective in _objectives:
		var color: Color = (
			ObjectivesPanel.PRIMARY_COLOR
			if objective.kind == Objective.KIND_PRIMARY
			else ObjectivesPanel.SECONDARY_COLOR
		)
		color.a = pulse
		var at: Vector2 = to_map(objective.area_center)
		var radius: float = maxf(objective.area_radius * scale, 4.0)
		_overlay.draw_arc(at, radius, 0.0, TAU, 24, Color(0, 0, 0, 0.6), 3.0)
		_overlay.draw_arc(at, radius, 0.0, TAU, 24, color, 1.5)


## Shows `objective`'s area while it is known and active (also fed by the objective
## events).
func track_objective(objective: RefCounted) -> void:
	var changed: Objective = objective as Objective
	if changed == null:
		return
	var shown: bool = changed.is_known and changed.has_area and changed.is_active()
	if shown and not _objectives.has(changed):
		_objectives.append(changed)
	elif not shown:
		_objectives.erase(changed)


## Charted sites: an unresolved signal is a "?" in a ring, a resolved one a dot.
func _draw_sites(scale: float) -> void:
	if world.discovery == null:
		return
	var font: Font = get_theme_default_font()
	for site: DiscoverySite in world.discovery.sites:
		if not site.is_signal_known_to_player or site.def == null:
			continue
		var at: Vector2 = to_map(site.position)
		if site.is_resolved:
			_overlay.draw_circle(at, maxf(site.def.radius * scale, 2.5), site.def.color)
			continue
		_overlay.draw_circle(at, 6.0, Color(0, 0, 0, 0.55))
		_overlay.draw_arc(at, 6.0, 0.0, TAU, 16, SIGNAL_COLOR, 1.5)
		_overlay.draw_string(
			font, at + Vector2(-3.0, 4.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SIGNAL_COLOR
		)


## The ground the camera sees, as the outline of its four screen corners.
func _draw_view() -> void:
	if camera == null or camera.camera == null:
		return
	var screen: Rect2 = camera.get_viewport().get_visible_rect()
	var corners: Array[Vector2] = [
		screen.position,
		Vector2(screen.end.x, screen.position.y),
		screen.end,
		Vector2(screen.position.x, screen.end.y),
	]
	var ground_y: float = camera.get_focus().y
	var points: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(to_map(_ground_under(corner, ground_y)))
	points.append(points[0])
	var bounds: Rect2 = Rect2(Vector2.ZERO, _terrain.size)
	for i: int in points.size():
		points[i] = points[i].clamp(bounds.position, bounds.end)
	_overlay.draw_polyline(points, VIEW_COLOR, 1.5)


func _ground_under(screen_point: Vector2, ground_y: float) -> Vector3:
	var origin: Vector3 = camera.camera.project_ray_origin(screen_point)
	var direction: Vector3 = camera.camera.project_ray_normal(screen_point)
	if direction.y > -0.05:
		# Above the horizon: cut the ray off far away instead.
		direction.y = -0.05
		direction = direction.normalized()
	var distance: float = (ground_y - origin.y) / direction.y
	return origin + direction * distance


func _color_for(owner_faction: int) -> Color:
	return TeamColors.for_faction(owner_faction) if owner_faction == faction else ENEMY_COLOR


## Hill-shaded terrain: lit by a low light from the north-west, impassable ground
## darker so routes stand out.
func _terrain_image() -> Image:
	var image: Image = Image.create_empty(TERRAIN_PIXELS, TERRAIN_PIXELS, false, Image.FORMAT_RGB8)
	var step: Vector2 = area.size / TERRAIN_PIXELS
	var low: Color = Color(0.42, 0.33, 0.25)
	var high: Color = Color(0.78, 0.66, 0.52)
	for y: int in TERRAIN_PIXELS:
		for x: int in TERRAIN_PIXELS:
			var point: Vector3 = Vector3(
				area.position.x + (x + 0.5) * step.x, 0.0, area.position.y + (y + 0.5) * step.y
			)
			var height: float = _height(point.x, point.z)
			var slope_x: float = _height(point.x + step.x, point.z) - height
			var slope_z: float = _height(point.x, point.z + step.y) - height
			var shade: float = clampf(0.75 - (slope_x + slope_z) * 0.12, 0.35, 1.15)
			var color: Color = low.lerp(high, clampf(height / 14.0 + 0.4, 0.0, 1.0)) * shade
			if world != null and not world.paths.is_terrain_walkable(point):
				color = color.darkened(0.45)
			color.a = 1.0
			image.set_pixel(x, y, color)
	return image


func _height(x: float, z: float) -> float:
	return world.heights.sample(x, z) if world != null and world.heights != null else 0.0


static func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HudStyle.PANEL_COLOR
	style.border_color = HudStyle.ACCENT_COLOR
	style.border_width_top = 2
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style
