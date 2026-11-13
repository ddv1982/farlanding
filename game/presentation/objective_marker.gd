class_name ObjectiveMarker
extends Node3D
## Marks a place the mission cares about: a pulsing ring on the ground and a thin
## column of light that can be found from across the map. Place it where the
## objective is and tell it how the objective is doing.

const PRIMARY := Color(1.0, 0.82, 0.35)
const SECONDARY := Color(0.4, 0.9, 1.0)
const DONE := Color(0.45, 1.0, 0.55)
const FAILED := Color(1.0, 0.25, 0.2)
const DECAL_HEIGHT := 14.0
const COLUMN_HEIGHT := 26.0
const PIXELS := 256

static var _ring: Texture2D

## Radius of the ring on the ground, in metres (the area to reach or hold).
@export var radius: float = 6.0:
	set(value):
		radius = value
		_resize()
## &"primary", &"secondary" or &"hidden" (hidden objectives show as secondary once known).
@export var kind: StringName = &"primary":
	set(value):
		kind = value
		_recolor()

var _state: StringName = &"active"
var _decal: Decal
var _column: MeshInstance3D
var _material: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	if _ring == null:
		_ring = _make_ring_texture()
	_decal = Decal.new()
	_decal.texture_albedo = _ring
	_decal.texture_emission = _ring
	_decal.albedo_mix = 0.0
	_decal.upper_fade = 0.01
	_decal.lower_fade = 0.01
	add_child(_decal)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.32
	mesh.height = COLUMN_HEIGHT
	mesh.radial_segments = 8
	mesh.cap_top = false
	mesh.cap_bottom = false
	_column = MeshInstance3D.new()
	_column.mesh = mesh
	_column.material_override = _material
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.position = Vector3(0.0, COLUMN_HEIGHT * 0.5, 0.0)
	add_child(_column)
	_resize()
	_recolor()


func _process(delta: float) -> void:
	if _state != &"active":
		return
	_time += delta
	_decal.emission_energy = 1.6 + 0.7 * sin(_time * 2.6)


## &"active", &"done" or &"failed". A finished marker flashes its verdict and fades.
func set_state(state: StringName) -> void:
	if state == _state:
		return
	_state = state
	_recolor()
	if state == &"active":
		return
	_decal.emission_energy = 4.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_decal, ^"emission_energy", 0.0, 1.8)
	tween.tween_property(_column, ^"scale", Vector3(0.01, 1.0, 0.01), 1.8)
	tween.chain().tween_callback(hide)


func _color() -> Color:
	match _state:
		&"done":
			return DONE
		&"failed":
			return FAILED
	return PRIMARY if kind == &"primary" else SECONDARY


func _recolor() -> void:
	if _decal == null:
		return
	var color: Color = _color()
	_decal.modulate = color
	_material.albedo_color = Color(color.r * 0.9, color.g * 0.9, color.b * 0.9)


func _resize() -> void:
	if _decal != null:
		_decal.size = Vector3(radius * 2.0, DECAL_HEIGHT, radius * 2.0)


## A double ring with four tick marks pointing inward.
static func _make_ring_texture() -> Texture2D:
	var image: Image = Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	var half: float = PIXELS * 0.5
	for y: int in PIXELS:
		for x: int in PIXELS:
			var offset := Vector2(x + 0.5 - half, y + 0.5 - half) / half
			var r: float = offset.length()
			var outer: float = 1.0 - smoothstep(0.0, 0.035, absf(r - 0.93))
			var inner: float = (1.0 - smoothstep(0.0, 0.02, absf(r - 0.8))) * 0.5
			var axis: float = minf(absf(offset.x), absf(offset.y))
			var tick: float = (
				(1.0 - smoothstep(0.0, 0.03, axis)) * (1.0 if r > 0.62 and r < 0.8 else 0.0)
			)
			var fill: float = 0.07 * (1.0 if r < 0.93 else 0.0)
			var alpha: float = clampf(outer + inner + tick + fill, 0.0, 1.0)
			image.set_pixel(x, y, Color(alpha, alpha, alpha, alpha))
	return ImageTexture.create_from_image(image)
