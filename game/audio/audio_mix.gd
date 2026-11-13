class_name AudioMix
extends RefCounted
## Pure mix rules: which player setting drives which bus, and how camera zoom
## reshapes the mix (close: unit and movement detail; far: music and ambience).

## Bus -> Settings property holding its linear volume.
const SETTING_FOR_BUS: Dictionary[StringName, StringName] = {
	&"Master": &"master_volume",
	&"Music": &"music_volume",
	&"Ambience": &"sfx_volume",
	&"SFX": &"sfx_volume",
	&"Discovery": &"sfx_volume",
	&"Voice": &"sfx_volume",
	&"UI": &"ui_volume",
}

## Bus -> [offset dB when fully zoomed in, offset dB when fully zoomed out].
const ZOOM_OFFSETS_DB: Dictionary[StringName, Vector2] = {
	&"Units": Vector2(1.5, -7.0),
	&"Buildings": Vector2(0.0, -4.0),
	&"Weapons": Vector2(0.0, -2.0),
	&"Music": Vector2(-3.0, 0.0),
	&"Ambience": Vector2(-4.0, 0.0),
}

## Listener height above the ground focus point, closest .. furthest zoom (m).
const LISTENER_HEIGHT: Vector2 = Vector2(6.0, 30.0)

const SILENT_DB: float = -80.0


static func linear_to_db_safe(linear: float) -> float:
	if linear <= 0.0001:
		return SILENT_DB
	return linear_to_db(linear)


static func zoom_offset_db(bus: StringName, zoom: float) -> float:
	if not ZOOM_OFFSETS_DB.has(bus):
		return 0.0
	var range_db: Vector2 = ZOOM_OFFSETS_DB[bus]
	return lerpf(range_db.x, range_db.y, clampf(zoom, 0.0, 1.0))


## Final bus volume: player setting (linear) plus the zoom offset.
static func bus_volume_db(bus: StringName, setting_linear: float, zoom: float) -> float:
	var base: float = linear_to_db_safe(setting_linear)
	if base <= SILENT_DB:
		return SILENT_DB
	return base + zoom_offset_db(bus, zoom)


static func listener_height(zoom: float) -> float:
	return lerpf(LISTENER_HEIGHT.x, LISTENER_HEIGHT.y, clampf(zoom, 0.0, 1.0))
