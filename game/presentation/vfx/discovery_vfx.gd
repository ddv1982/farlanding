class_name DiscoveryVfx
extends Node3D
## Draws exploration from the event bus: the burst when a site is resolved, the
## ground glow of a heal field, and the Survey Lab's field options landing. The
## simulation never calls this; add one instance to a map and it listens to
## `Events`.
##
## Ground marks are Decals, so they follow slopes instead of cutting through them.
## Reads `payoff`, `payoff_radius`, `payoff_seconds` and `color` from a
## DiscoveryDef and `effect` and `radius` from a FieldOptionDef, by name.

const SCAN_COLOR := Color(0.35, 0.92, 1.0)
const DROP_COLOR := Color(1.0, 0.55, 0.15)
const STRIKE_COLOR := Color(1.0, 0.93, 0.72)
## Decal box height: tall enough to wrap the map's steepest slope under a wide ring.
const DECAL_HEIGHT := 14.0
const RING_PIXELS := 256
const STRIKE_HEIGHT := 60.0

## Faction whose discoveries are drawn (the commander's are its own business).
@export var player_faction: int = 0

var _ring: Texture2D
var _disc: Texture2D


func _ready() -> void:
	_ring = _make_ring_texture(0.86, 0.06, 0.0)
	_disc = _make_ring_texture(0.9, 0.05, 0.4)
	Events.discovery_made.connect(_on_discovery_made)
	Events.field_option_used.connect(_on_field_option_used)


func _on_discovery_made(site: Node3D, discovery: Resource, faction: int) -> void:
	if faction != player_faction or not is_instance_valid(site) or discovery == null:
		return
	var color: Color = _color(discovery, &"color", SCAN_COLOR)
	var radius: float = _number(discovery, &"payoff_radius", 10.0)
	pulse(site.global_position, color, 9.0, 1.1)
	if _name(discovery, &"payoff") == &"heal_field":
		field(site.global_position, color, radius, _number(discovery, &"payoff_seconds", 30.0))


func _on_field_option_used(option: Resource, faction: int, at: Vector3) -> void:
	if faction != player_faction or option == null:
		return
	var radius: float = _number(option, &"radius", 12.0)
	match _name(option, &"effect"):
		&"reveal":
			pulse(at, SCAN_COLOR, radius, 1.6)
			pulse(at, SCAN_COLOR, radius * 0.6, 1.1)
		&"supply_drop":
			beam(at, DROP_COLOR, 0.5, 0.9)
			pulse(at, DROP_COLOR, 6.0, 0.9)
		&"strike":
			beam(at, STRIKE_COLOR, 1.6, 0.7)
			pulse(at, STRIKE_COLOR, radius, 0.8)
			field(at, STRIKE_COLOR, radius * 0.5, 1.4)


## A ring on the ground growing from nothing to `radius` and fading out.
func pulse(at: Vector3, color: Color, radius: float, seconds: float) -> void:
	var decal: Decal = _decal(_ring, at, color)
	decal.size = Vector3(0.5, DECAL_HEIGHT, 0.5)
	decal.emission_energy = 3.0
	var tween: Tween = decal.create_tween().set_parallel(true)
	tween.tween_property(decal, ^"size", Vector3(radius * 2.0, DECAL_HEIGHT, radius * 2.0), seconds)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(decal, ^"emission_energy", 0.0, seconds)
	tween.chain().tween_callback(decal.queue_free)


## A softly breathing disc of `radius` that stays for `seconds`, then fades.
func field(at: Vector3, color: Color, radius: float, seconds: float) -> void:
	var decal: Decal = _decal(_disc, at, color)
	decal.size = Vector3(radius * 2.0, DECAL_HEIGHT, radius * 2.0)
	decal.emission_energy = 0.0
	var fade: float = minf(1.5, seconds * 0.4)
	var breaths: int = maxi(int((seconds - fade * 2.0) / 2.4), 0)
	var tween: Tween = decal.create_tween()
	tween.tween_property(decal, ^"emission_energy", 1.3, fade)
	for i: int in breaths:
		tween.tween_property(decal, ^"emission_energy", 0.75, 1.2)
		tween.tween_property(decal, ^"emission_energy", 1.3, 1.2)
	tween.tween_property(decal, ^"emission_energy", 0.0, fade)
	tween.tween_callback(decal.queue_free)


## A column of light from the sky that thins away.
func beam(at: Vector3, color: Color, width: float, seconds: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2)
	var mesh := CylinderMesh.new()
	mesh.top_radius = width * 0.5
	mesh.bottom_radius = width * 0.5
	mesh.height = STRIKE_HEIGHT
	mesh.radial_segments = 8
	mesh.cap_top = false
	mesh.cap_bottom = false
	var column := MeshInstance3D.new()
	column.mesh = mesh
	column.material_override = material
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(column)
	column.global_position = at + Vector3.UP * (STRIKE_HEIGHT * 0.5)
	var tween: Tween = column.create_tween()
	tween.tween_property(column, ^"scale", Vector3(0.02, 1.0, 0.02), seconds)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(column.queue_free)


func _decal(texture: Texture2D, at: Vector3, color: Color) -> Decal:
	var decal := Decal.new()
	decal.texture_albedo = texture
	decal.texture_emission = texture
	decal.modulate = color
	decal.albedo_mix = 0.0
	decal.upper_fade = 0.01
	decal.lower_fade = 0.01
	add_child(decal)
	decal.global_position = at
	return decal


## White ring on transparent: a rim at `rim` of the radius, `width` wide, over a
## fill of `fill` alpha that thins toward the centre.
static func _make_ring_texture(rim: float, width: float, fill: float) -> Texture2D:
	var image: Image = Image.create(RING_PIXELS, RING_PIXELS, false, Image.FORMAT_RGBA8)
	var half: float = RING_PIXELS * 0.5
	for y: int in RING_PIXELS:
		for x: int in RING_PIXELS:
			var r: float = Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			var edge: float = 1.0 - smoothstep(0.0, width, absf(r - rim))
			var inside: float = fill * smoothstep(0.1, rim, r) * (1.0 if r < rim else 0.0)
			var alpha: float = clampf(edge + inside, 0.0, 1.0)
			image.set_pixel(x, y, Color(alpha, alpha, alpha, alpha))
	return ImageTexture.create_from_image(image)


static func _number(source: Resource, property: StringName, fallback: float) -> float:
	var value: Variant = source.get(property)
	if value is float or value is int:
		var number: float = value
		return number
	return fallback


static func _name(source: Resource, property: StringName) -> StringName:
	var value: Variant = source.get(property)
	if value is StringName:
		var text: StringName = value
		return text
	return &""


static func _color(source: Resource, property: StringName, fallback: Color) -> Color:
	var value: Variant = source.get(property)
	if value is Color:
		var color: Color = value
		return color
	return fallback
