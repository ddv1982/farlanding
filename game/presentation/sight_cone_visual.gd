class_name SightConeVisual
extends Node3D
## What a guard can see, drawn on the ground in front of it, and what it thinks:
## the cone turns from calm to amber to red as suspicion rises, with a "?" or "!"
## over the guard. Add it as a child of the watcher (it faces the parent's -Z)
## and feed it from the stealth component; it draws nothing by itself until
## `set_cone` is called.
##
## The cone is a Decal, so it lies on slopes instead of cutting through them.

const CALM := Color(0.55, 0.9, 1.0)
const SUSPICIOUS := Color(1.0, 0.72, 0.15)
const ALERTED := Color(1.0, 0.16, 0.1)
const DECAL_HEIGHT := 10.0
const PIXELS := 256
## Suspicion above which the "?" shows.
const QUESTION_AT := 0.2

static var _textures: Dictionary[int, Texture2D] = {}

## Height of the "?" / "!" above the watcher's origin, in metres.
@export var icon_height: float = 3.4

var _decal: Decal
var _icon: Label3D
var _suspicion: float = 0.0
var _alerted: bool = false


func _ready() -> void:
	_decal = Decal.new()
	_decal.albedo_mix = 0.0
	_decal.upper_fade = 0.01
	_decal.lower_fade = 0.01
	_decal.visible = false
	add_child(_decal)
	_icon = Label3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.fixed_size = true
	_icon.pixel_size = 0.0016
	_icon.font_size = 56
	_icon.outline_size = 14
	_icon.outline_modulate = Color(0.04, 0.03, 0.03, 0.9)
	_icon.position = Vector3(0.0, icon_height, 0.0)
	_icon.visible = false
	add_child(_icon)
	_refresh()


## The watcher's sight: how far it sees and the full width of its cone in degrees.
func set_cone(range_m: float, angle_degrees: float) -> void:
	var angle: int = clampi(roundi(angle_degrees / 5.0) * 5, 10, 360)
	_decal.texture_albedo = _texture(angle)
	_decal.texture_emission = _decal.texture_albedo
	_decal.size = Vector3(range_m * 2.0, DECAL_HEIGHT, range_m * 2.0)
	_decal.visible = range_m > 0.0


## 0 = sees nothing of interest, 1 = about to raise the alarm.
func set_suspicion(value: float) -> void:
	_suspicion = clampf(value, 0.0, 1.0)
	_refresh()


## True once the watcher is sure and has raised the alarm.
func set_alerted(alerted: bool) -> void:
	_alerted = alerted
	_refresh()


func _refresh() -> void:
	if _decal == null:
		return
	var color: Color = CALM.lerp(SUSPICIOUS, smoothstep(0.0, 0.6, _suspicion))
	color = color.lerp(ALERTED, smoothstep(0.6, 1.0, _suspicion))
	if _alerted:
		color = ALERTED
	_decal.modulate = color
	_decal.emission_energy = 0.55 + _suspicion * 0.9 + (0.6 if _alerted else 0.0)
	_icon.visible = _alerted or _suspicion >= QUESTION_AT
	_icon.text = "!" if _alerted else "?"
	_icon.modulate = ALERTED if _alerted else SUSPICIOUS


static func _texture(angle_degrees: int) -> Texture2D:
	if not _textures.has(angle_degrees):
		_textures[angle_degrees] = _make_cone_texture(angle_degrees)
	return _textures[angle_degrees]


## A wedge opening toward -Z (up in the image): faint fill, brighter rim and edges.
static func _make_cone_texture(angle_degrees: int) -> Texture2D:
	var image: Image = Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	var half: float = PIXELS * 0.5
	var half_angle: float = deg_to_rad(angle_degrees) * 0.5
	for y: int in PIXELS:
		for x: int in PIXELS:
			var offset := Vector2(x + 0.5 - half, y + 0.5 - half) / half
			var r: float = offset.length()
			var off_axis: float = absf(atan2(offset.x, -offset.y))
			var alpha: float = 0.0
			if r <= 1.0 and off_axis <= half_angle:
				var fill: float = 0.16 + 0.1 * (1.0 - r)
				var rim: float = smoothstep(0.94, 0.985, r) * 0.6
				var side: float = (1.0 - smoothstep(0.0, 0.035, (half_angle - off_axis) * r)) * 0.5
				var sweep: float = (
					(1.0 - smoothstep(0.0, 0.5, absf(fposmod(r * 4.0, 1.0) - 0.5))) * 0.05
				)
				alpha = clampf(fill + rim + side + sweep, 0.0, 1.0)
			image.set_pixel(x, y, Color(alpha, alpha, alpha, alpha))
	return ImageTexture.create_from_image(image)
