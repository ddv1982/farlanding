class_name CursorIcons
extends RefCounted
## Mouse cursors that say what a click will do, drawn in code (no image files): each
## is a simple shape in one colour with a dark outline, 32 px with its hotspot in the
## centre. Built once and cached.

const SIZE: int = 32
const ATTACK: StringName = &"attack"
const MOVE: StringName = &"move"
const SCAN: StringName = &"scan"
const HARVEST: StringName = &"harvest"
const ASSIST: StringName = &"assist"
const RALLY: StringName = &"rally"
## Aiming a field option.
const TARGET: StringName = &"target"

const COLORS: Dictionary[StringName, Color] = {
	ATTACK: Color(1.0, 0.22, 0.15),
	MOVE: Color(0.45, 1.0, 0.55),
	SCAN: Color(0.35, 0.92, 1.0),
	HARVEST: Color(0.95, 0.80, 0.45),
	ASSIST: Color(1.0, 0.62, 0.2),
	RALLY: Color(0.45, 1.0, 0.55),
	TARGET: Color(0.75, 0.6, 1.0),
}
const OUTLINE: Color = Color(0.04, 0.03, 0.03, 0.9)

static var _cache: Dictionary[StringName, Texture2D] = {}


## The cursor for `kind` (one of the constants), or null for an unknown kind.
static func get_cursor(kind: StringName) -> Texture2D:
	if not COLORS.has(kind):
		return null
	if not _cache.has(kind):
		_cache[kind] = ImageTexture.create_from_image(build_image(kind))
	return _cache[kind]


## Hotspot of every cursor: its centre.
static func hotspot() -> Vector2:
	return Vector2(SIZE, SIZE) * 0.5


## The cursor image for `kind`: the dark outline first, the colour on top.
static func build_image(kind: StringName) -> Image:
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var centre: Vector2 = Vector2(SIZE, SIZE) * 0.5 - Vector2(0.5, 0.5)
	for pass_index: int in 2:
		var color: Color = OUTLINE if pass_index == 0 else COLORS[kind]
		var grow: float = 1.0 if pass_index == 0 else 0.0
		for y: int in SIZE:
			for x: int in SIZE:
				if _covers(kind, Vector2(x, y) - centre, grow):
					image.set_pixel(x, y, color)
	return image


static func _covers(kind: StringName, offset: Vector2, grow: float) -> bool:
	var r: float = offset.length()
	var on_axis: bool = absf(offset.x) <= 0.5 + grow or absf(offset.y) <= 0.5 + grow
	match kind:
		ATTACK:
			# A reticle: ring, four ticks pointing in, centre dot.
			var tick: bool = on_axis and r >= 5.0 - grow and r <= 15.0 + grow
			return absf(r - 10.0) <= 1.0 + grow or tick or r <= 1.5 + grow
		MOVE:
			# Four chevrons pointing at the centre.
			var along: float = maxf(absf(offset.x), absf(offset.y))
			var across: float = minf(absf(offset.x), absf(offset.y))
			return (
				along >= 6.0 - grow
				and along <= 12.0 + grow
				and absf(along - 6.0 - across) <= 1.0 + grow
			)
		SCAN:
			# A dashed ring around a dot.
			var dash: bool = fposmod(offset.angle(), PI / 4.0) < PI / 6.0
			return (absf(r - 10.0) <= 1.2 + grow and dash) or r <= 2.0 + grow
		HARVEST:
			# A diamond outline.
			var diamond: float = absf(offset.x) + absf(offset.y)
			return absf(diamond - 9.0) <= 1.2 + grow or r <= 1.5 + grow
		ASSIST:
			# A plus sign.
			var arm: bool = maxf(absf(offset.x), absf(offset.y)) <= 9.0 + grow
			return arm and minf(absf(offset.x), absf(offset.y)) <= 1.5 + grow
		RALLY:
			# A flag: a pole up from the hotspot and a pennant.
			var pole: bool = (
				absf(offset.x) <= 0.8 + grow and offset.y <= 0.5 + grow and offset.y >= -13.0 - grow
			)
			# Pennant: a triangle from the pole, tip 9 px out at y = -9.
			var spread: float = 1.0 - absf(offset.y + 9.0) / 4.0
			var pennant: bool = offset.x >= -grow and offset.x <= 9.0 * spread + grow
			return pole or pennant or r <= 1.5 + grow
		TARGET:
			# A ring with a cross reaching past it.
			var cross: bool = on_axis and r >= 3.0 - grow and r <= 15.0 + grow
			return absf(r - 7.0) <= 1.0 + grow or cross
	return false
