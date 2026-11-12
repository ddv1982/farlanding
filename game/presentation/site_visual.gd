class_name SiteVisual
extends Node3D
## A discovery site in the world: something the orbital scan could not resolve.
## Unresolved it carries a floating "?"; while a Surveyor scans it a ring sweeps
## the ground and a column of light rises; resolved it keeps a steady glow in
## the colour of its discovery type. Holds no gameplay state.

const RING_SHADER: Shader = preload("res://presentation/shaders/scan_ring.gdshader")
const UNKNOWN_COLOR := Color(0.35, 0.92, 1.0)
const BOB_HEIGHT := 0.25
const BOB_SPEED := 1.6

@export var model_scene: PackedScene
## Radius of the scan ring in metres.
@export var radius: float = 6.0
## Height of the "?" above the ground.
@export var marker_height: float = 7.0

var _marker: Label3D
var _ring: MeshInstance3D
var _column: MeshInstance3D
var _glow: OmniLight3D
var _time: float = 0.0
var _color: Color = UNKNOWN_COLOR


func _ready() -> void:
	if model_scene != null:
		add_child(model_scene.instantiate())
	_marker = _build_marker()
	add_child(_marker)
	_ring = _build_ring()
	add_child(_ring)
	_column = _build_column()
	add_child(_column)
	_glow = OmniLight3D.new()
	_glow.position.y = 2.5
	_glow.omni_range = radius * 1.6
	_glow.light_energy = 0.0
	_glow.shadow_enabled = false
	add_child(_glow)
	set_scan_progress(0.0)


func _process(delta: float) -> void:
	_time += delta
	if _marker.visible:
		_marker.position.y = marker_height + sin(_time * BOB_SPEED) * BOB_HEIGHT


## Colour of the discovery type; used once the site is resolved and while scanning.
func set_discovery_color(color: Color) -> void:
	_color = color
	_ring.set_instance_shader_parameter(&"ring_color", color)


## 0 = not being scanned, up to 1 = scan complete.
func set_scan_progress(progress: float) -> void:
	var amount := clampf(progress, 0.0, 1.0)
	var scanning := amount > 0.0 and amount < 1.0
	_ring.visible = scanning
	_column.visible = scanning
	_ring.set_instance_shader_parameter(&"progress", amount)
	_column.scale = Vector3(1.0, maxf(amount, 0.02), 1.0)


## A resolved site drops its "?" and keeps a steady glow.
func set_resolved(resolved: bool) -> void:
	_marker.visible = not resolved
	_glow.light_color = _color
	_glow.light_energy = 2.2 if resolved else 0.0
	if resolved:
		set_scan_progress(0.0)


func _build_marker() -> Label3D:
	var marker := Label3D.new()
	marker.name = "Marker"
	marker.text = "?"
	marker.font_size = 220
	marker.pixel_size = 0.012
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.modulate = UNKNOWN_COLOR
	marker.outline_size = 40
	marker.outline_modulate = Color(0.02, 0.08, 0.10, 0.9)
	marker.position.y = marker_height
	return marker


func _build_ring() -> MeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	var material := ShaderMaterial.new()
	material.shader = RING_SHADER
	var ring := MeshInstance3D.new()
	ring.name = "ScanRing"
	ring.mesh = quad
	ring.material_override = material
	ring.position.y = 0.15
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


func _build_column() -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(UNKNOWN_COLOR, 0.16)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := CylinderMesh.new()
	beam.top_radius = 0.5
	beam.bottom_radius = 1.4
	beam.height = marker_height
	beam.radial_segments = 12
	var column := MeshInstance3D.new()
	column.name = "ScanColumn"
	column.mesh = beam
	column.material_override = material
	# The column is scaled from the ground up, so move the mesh's base to the origin.
	var lifted := ArrayMesh.new()
	var arrays: Array = beam.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index: int in vertices.size():
		vertices[index].y += marker_height * 0.5
	arrays[Mesh.ARRAY_VERTEX] = vertices
	lifted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	column.mesh = lifted
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return column
