class_name AudioMix
extends RefCounted
## Pure mix rules: which player setting drives which bus, and how camera zoom
## reshapes the mix (close: unit and movement detail; far: music and ambience).

## Bus -> Settings property holding its linear volume. A setting the Settings
## autoload does not (yet) have counts as 1.0. Phase 9: the Advisor has its own
## slider (`voice_volume`, the Advisor bus; unit replies on Barks stay with the
## effects) and so has the planet ambience (`ambience_volume`, the Ambience bus;
## the weather, which warns, stays with the effects). The Voice bus itself has
## no setting, so the Advisor is not scaled by the effects slider as well.
const SETTING_FOR_BUS: Dictionary[StringName, StringName] = {
	&"Master": &"master_volume",
	&"Music": &"music_volume",
	&"Ambience": &"ambience_volume",
	&"SFX": &"sfx_volume",
	&"Discovery": &"sfx_volume",
	&"Stealth": &"sfx_volume",
	&"Barks": &"sfx_volume",
	&"Advisor": &"voice_volume",
	&"UI": &"ui_volume",
	&"Weather": &"sfx_volume",
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

## While the pause menu is open the game world steps back (dB); the interface,
## the Advisor and unit replies stay as they are.
const PAUSE_DB: Dictionary[StringName, float] = {
	&"Music": -6.0,
	&"Ambience": -8.0,
	&"Weather": -8.0,
	&"SFX": -10.0,
	&"Discovery": -6.0,
	&"Stealth": -6.0,
}
## Under the mission-select menu (its theme plays as a bed on Music) the world
## behind it is quieter.
const MENU_DB: Dictionary[StringName, float] = {
	&"Ambience": -10.0,
	&"Weather": -10.0,
}

## Aboard the Meridian (Phase 7, any campaign screen) nothing of a planet is
## heard: the world's buses are silenced (a guard: their sources also stop),
## and the mix uses the far-zoom balance (SHIP_ZOOM: music and ambience at
## full, no close-up detail).
const SHIP_DB: Dictionary[StringName, float] = {
	&"SFX": SILENT_DB,
	&"Weather": SILENT_DB,
	&"Stealth": SILENT_DB,
	&"Discovery": SILENT_DB,
}
const SHIP_ZOOM: float = 1.0

## Buses the storm muffles (low-pass + level), see StormCues.
const MUFFLED_BUSES: Array[StringName] = [&"SFX", &"Ambience"]
## Name of the low-pass effect on those buses in default_bus_layout.tres.
const MUFFLE_EFFECT: StringName = &"StormMuffle"


## Extra dB on `bus` from the overlays: pause, menu, storm muffle (0..1).
static func overlay_db(bus: StringName, paused: bool, menu: bool, muffle: float) -> float:
	var offset: float = 0.0
	if paused:
		offset += PAUSE_DB.get(bus, 0.0)
	if menu:
		offset += MENU_DB.get(bus, 0.0)
	offset += StormCues.muffle_db(bus, muffle)
	return offset


## Extra dB on `bus` aboard the ship.
static func ship_db(bus: StringName) -> float:
	var offset: float = SHIP_DB.get(bus, 0.0)
	return offset


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
